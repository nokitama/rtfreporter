# Internal utility: inches to twips.
.in_to_twips <- function(x) {
  as.integer(round(x * 1440))
}

# NULL-coalescing operator.
`%||%` <- function(a, b) if (!is.null(a)) a else b

.load_rtf_commands <- local({
  cache <- NULL
  function() {
    if (!is.null(cache)) {
      return(cache)
    }

    resource_candidates <- c(
      file.path(getwd(), "inst", "resources", "rtf_commands.R"),
      file.path(getwd(), "r", "rtfreporter", "inst", "resources", "rtf_commands.R")
    )
    pkg_resource_dir <- system.file("resources", package = "rtfreporter")
    if (nzchar(pkg_resource_dir)) {
      resource_candidates <- c(file.path(pkg_resource_dir, "rtf_commands.R"), resource_candidates)
    }

    resource_path <- resource_candidates[file.exists(resource_candidates)][1]
    if (is.na(resource_path)) {
      stop("RTF command resource file not found.", call. = FALSE)
    }

    env <- new.env(parent = baseenv())
    sys.source(resource_path, envir = env)
    if (!exists("rtf_commands", envir = env, inherits = FALSE)) {
      stop("`rtf_commands` not defined in resource file.", call. = FALSE)
    }
    cache <<- get("rtf_commands", envir = env, inherits = FALSE)
    cache
  }
})

.cmd_fmt <- function(template, values = list()) {
  out <- template
  if (length(values) == 0L) {
    return(out)
  }
  for (nm in names(values)) {
    out <- gsub(paste0("{", nm, "}"), as.character(values[[nm]]), out, fixed = TRUE)
  }
  out
}

# ── Text processing ────────────────────────────────────────────────────────────

# Character-level RTF escape + Unicode conversion.
# Handles: \, {, }, newline → \line , non-ASCII → \uN?
# Does NOT handle markup tokens (^{}, _{}); those are handled by .format_cell_text().
.rtf_escape_unicode_raw <- function(x) {
  if (!nzchar(x)) return(x)
  chars <- strsplit(x, "", fixed = TRUE)[[1]]
  out <- vapply(chars, function(ch) {
    cp <- utf8ToInt(ch)
    if      (ch == "\\") return("\\\\")
    if      (ch == "{")  return("\\{")
    if      (ch == "}")  return("\\}")
    if      (ch == "\n") return("\\line ")
    if (cp > 127L)       return(sprintf("\\u%d?", cp))
    ch
  }, character(1L))
  paste0(out, collapse = "")
}

# Process a segment of text that may contain ^{} / _{} markup recursively,
# escaping plain-text parts along the way.
.process_markup <- function(x) {
  if (!nzchar(x)) return(x)
  n <- nchar(x)

  # Find the first ^{ or _{ occurrence.
  m_super <- regexpr("\\^\\{", x, perl = TRUE)
  m_sub   <- regexpr("_\\{",   x, perl = TRUE)

  # Pick the earliest match.
  pos  <- Inf
  kind <- ""
  if (m_super[1] > 0L && m_super[1] < pos) { pos <- m_super[1]; kind <- "super" }
  if (m_sub[1]   > 0L && m_sub[1]   < pos) { pos <- m_sub[1];   kind <- "sub"   }

  if (kind == "") {
    # No markup found – escape the whole segment.
    return(.rtf_escape_unicode_raw(x))
  }

  prefix_len <- 2L  # both ^{ and _{ are 2 chars
  before  <- substr(x, 1L, pos - 1L)
  rest    <- substr(x, pos + prefix_len, n)

  # Find the matching closing brace.
  depth     <- 1L
  end_pos   <- 0L
  rest_chars <- strsplit(rest, "", fixed = TRUE)[[1]]
  for (i in seq_along(rest_chars)) {
    ch <- rest_chars[i]
    if (ch == "{") depth <- depth + 1L
    if (ch == "}") { depth <- depth - 1L; if (depth == 0L) { end_pos <- i; break } }
  }

  if (end_pos == 0L) {
    # Unmatched brace – treat the whole thing as plain text.
    return(.rtf_escape_unicode_raw(x))
  }

  inner <- substr(rest, 1L, end_pos - 1L)
  after <- substr(rest, end_pos + 1L, nchar(rest))
  cmd   <- if (kind == "super") "\\super " else "\\sub "

  paste0(
    .process_markup(before),
    "{", cmd, .process_markup(inner), "}",
    .process_markup(after)
  )
}

# Full cell-text processing pipeline:
#   ^{} / _{} markup, \n, >=, <=, RTF escape, Unicode.
.format_cell_text <- function(x) {
  if (is.null(x) || is.na(x)) return("")
  x <- as.character(x)

  # Simple substitutions on raw string (before markup parsing):
  x <- gsub("\n",  "\n",  x, fixed = TRUE)  # keep actual newline for .process_markup
  x <- gsub(">=", "\x01GE\x01", x, fixed = TRUE)
  x <- gsub("<=", "\x01LE\x01", x, fixed = TRUE)

  # Process markup + escape.
  result <- .process_markup(x)

  # Replace placeholders with RTF Unicode sequences.
  result <- gsub("\x01GE\x01", "\\u8805?", result, fixed = TRUE)
  result <- gsub("\x01LE\x01", "\\u8804?", result, fixed = TRUE)

  result
}

# RTF-safe escape for header/footer text (no markup processing, supports tokens).
.rtf_escape <- function(x) {
  if (length(x) == 0L || is.na(x)) return("")
  .rtf_escape_unicode_raw(as.character(x))
}

# Replace page tokens, then RTF-escape.
# {PAGE} is replaced with the RTF dynamic field \chpgn (updated per page by the RTF reader).
# {TOTAL_PAGES} is replaced with a static count known at render time.
# NOTE: current_page is retained for signature compatibility but is no longer used.
.render_tokens <- function(x, current_page = NULL, total_pages = NULL) {
  if (is.null(x)) return("")
  # Escape first; after escaping, { becomes \{ and } becomes \}, so
  # the token {PAGE} appears as \{PAGE\} and can be substituted safely.
  out <- .rtf_escape(x)
  out <- gsub("\\{PAGE\\}",         "\\chpgn ",              out, fixed = TRUE)
  if (!is.null(total_pages))
    out <- gsub("\\{TOTAL_PAGES\\}", as.character(total_pages), out, fixed = TRUE)
  out
}

# ── Border helpers ─────────────────────────────────────────────────────────────

# Build RTF border commands for all four sides of a single cell.
# border_spec: list with keys top/bottom/left/right (type string or "none"/NULL)
#              and optional width (integer twips, default 15).
# Returns "" when border_spec is NULL (no borders).
.build_border_commands <- function(border_spec) {
  if (is.null(border_spec)) return("")
  width <- as.integer(border_spec$width %||% 15L)
  cmds  <- .load_rtf_commands()
  prefixes <- cmds$border$side_prefix
  styles   <- cmds$border$style

  .side <- function(side) {
    type <- border_spec[[side]]
    if (is.null(type) || type %in% c("none", "")) return("")
    s <- styles[[type]]
    if (is.null(s)) stop(sprintf("Unknown border type: '%s'", type), call. = FALSE)
    paste0(prefixes[[side]], s, "\\brdrw", width)
  }
  paste0(.side("top"), .side("bottom"), .side("left"), .side("right"))
}

# Merge first_row / last_row overrides into a base body border spec.
.effective_row_border <- function(base_border, override) {
  if (is.null(base_border)) return(NULL)
  if (length(override) == 0L) return(base_border)
  .merge_list(base_border, override)
}

# ── Column width computation ───────────────────────────────────────────────────

# Compute cumulative cellx positions for a table.
# Priority: column_widths_twips > col_rel_width > equal distribution.
.compute_cellx <- function(ncols, writable_width_twips, tbl) {
  if (!is.null(tbl$column_widths_twips)) {
    widths <- as.integer(tbl$column_widths_twips)
    if (length(widths) != ncols) {
      stop(sprintf("`column_widths_twips` length (%d) must match ncol (%d).",
                   length(widths), ncols), call. = FALSE)
    }
    return(cumsum(widths))
  }

  # Determine total table width.
  total_w <- if (!is.null(tbl$table_width_twips)) {
    as.integer(tbl$table_width_twips)
  } else if (!is.null(tbl$table_width_pct_of_writable)) {
    as.integer(round(writable_width_twips * as.numeric(tbl$table_width_pct_of_writable)))
  } else {
    as.integer(writable_width_twips)
  }

  if (!is.null(tbl$col_rel_width)) {
    rel <- as.numeric(tbl$col_rel_width)
    if (length(rel) != ncols) {
      stop(sprintf("`col_rel_width` length (%d) must match ncol (%d).",
                   length(rel), ncols), call. = FALSE)
    }
    if (any(rel <= 0)) stop("`col_rel_width` values must be positive.", call. = FALSE)
    widths <- as.integer(round(total_w * rel / sum(rel)))
    widths[ncols] <- total_w - sum(widths[-ncols])  # absorb rounding drift
    return(cumsum(widths))
  }

  # Equal distribution.
  cell_w <- max(1L, floor(total_w / ncols))
  widths  <- rep(cell_w, ncols)
  widths[ncols] <- total_w - sum(widths[-ncols])
  cumsum(widths)
}

# ── Cell content builder ───────────────────────────────────────────────────────

# Build the content string for one table cell (no \trowd / \cellx, just text+\cell).
# align: "left"|"right"|"center"
# All decoration flags are logical scalars.
.build_cell_content <- function(text, align = "left", bold = FALSE, italic = FALSE,
                                 underline = FALSE, indent_twips = 0L,
                                 pad_l = 72L, pad_r = 72L) {
  align_cmd <- switch(align, left = "\\ql", right = "\\qr", center = "\\qc", "\\ql")
  li <- as.integer(pad_l) + as.integer(indent_twips)
  ri <- as.integer(pad_r)

  # Apply decorations inside-out (outermost last so they wrap correctly).
  if (underline) text <- paste0("\\ul ", text, "\\ulnone ")
  if (italic)    text <- paste0("\\i ",  text, "\\i0 ")
  if (bold)      text <- paste0("\\b ",  text, "\\b0 ")

  paste0(align_cmd, "\\li", li, "\\ri", ri, " ", text, "\\cell")
}

# ── Row renderers ──────────────────────────────────────────────────────────────

# Build one complete RTF table row string.
# cell_defs:    character vector – one border+valign+\cellx string per column.
# cell_contents: character vector – one \q..\li..\ri.. text\cell string per column.
# row_height_twips: integer or NULL.
.build_row <- function(cell_defs, cell_contents, row_height_twips = NULL) {
  rh <- if (!is.null(row_height_twips) && as.integer(row_height_twips) != 0L)
    paste0("\\trrh", as.integer(row_height_twips)) else ""
  paste0("\\trowd", rh, paste(cell_defs, collapse = ""), paste(cell_contents, collapse = ""), "\\row")
}

# Build cell definition strings (border + valign + \cellx) for all columns.
.build_cell_defs <- function(cellx, border_spec, valign_cmd) {
  border_cmds <- .build_border_commands(border_spec)
  vapply(cellx, function(cx) paste0(border_cmds, valign_cmd, "\\cellx", cx), character(1L))
}

# Render spanning-header row(s).
# spanning_header: list of list(from, to, label, underline).
.render_spanning_rows <- function(spanning_header, cellx, border_spec,
                                   row_height_twips, pad_l, pad_r, valign_cmd) {
  if (is.null(spanning_header) || length(spanning_header) == 0L) return(character())
  ncols <- length(cellx)

  # Determine span coverage per column (0 = not spanned, k = span group index).
  coverage <- integer(ncols)
  for (k in seq_along(spanning_header)) {
    sp <- spanning_header[[k]]
    for (j in as.integer(sp$from):as.integer(sp$to)) {
      coverage[j] <- k
    }
  }

  # Build cell definitions: spanned columns use merged width.
  cell_defs <- character()
  border_cmds <- .build_border_commands(border_spec)
  j <- 1L
  while (j <= ncols) {
    k <- coverage[j]
    if (k > 0L) {
      to_idx <- as.integer(spanning_header[[k]]$to)
      cell_defs <- c(cell_defs, paste0(border_cmds, valign_cmd, "\\cellx", cellx[to_idx]))
      j <- to_idx + 1L
    } else {
      cell_defs <- c(cell_defs, paste0(border_cmds, valign_cmd, "\\cellx", cellx[j]))
      j <- j + 1L
    }
  }

  # Build cell contents.
  cell_contents <- character()
  j <- 1L
  while (j <= ncols) {
    k <- coverage[j]
    if (k > 0L) {
      sp    <- spanning_header[[k]]
      label <- .format_cell_text(sp$label %||% "")
      if (isTRUE(sp$underline)) label <- paste0("\\ul ", label, "\\ulnone ")
      label <- paste0("\\b ", label, "\\b0 ")
      cell_contents <- c(cell_contents,
        paste0("\\qc\\li", pad_l, "\\ri", pad_r, " ", label, "\\cell"))
      j <- as.integer(sp$to) + 1L
    } else {
      cell_contents <- c(cell_contents,
        paste0("\\ql\\li", pad_l, "\\ri", pad_r, " \\cell"))
      j <- j + 1L
    }
  }

  .build_row(cell_defs, cell_contents, row_height_twips)
}

# Render one column-header row.
.render_header_row <- function(hdr_labels, cellx, border_spec, row_height_twips,
                                pad_l, pad_r, valign_cmd, col_spec) {
  ncols <- length(cellx)
  cell_defs     <- .build_cell_defs(cellx, border_spec, valign_cmd)
  cell_contents <- vapply(seq_len(ncols), function(j) {
    spec  <- col_spec[[j]]
    text  <- .format_cell_text(if (j <= length(hdr_labels)) hdr_labels[[j]] else "")
    bold  <- isTRUE(spec$header_bold)
    itl   <- isTRUE(spec$header_italic)
    align <- spec$header_align %||% "center"
    .build_cell_content(text, align, bold, itl, FALSE, 0L, pad_l, pad_r)
  }, character(1L))
  .build_row(cell_defs, cell_contents, row_height_twips)
}

# Render one data row.
.render_data_row <- function(vals, cellx, border_spec, row_height_twips,
                              pad_l, pad_r, valign_cmd, col_spec) {
  ncols <- length(cellx)
  cell_defs     <- .build_cell_defs(cellx, border_spec, valign_cmd)
  cell_contents <- vapply(seq_len(ncols), function(j) {
    spec        <- col_spec[[j]]
    raw_val     <- if (j <= length(vals)) vals[[j]] else NA
    text        <- .format_cell_text(if (is.na(raw_val)) "" else as.character(raw_val))
    align       <- spec$align       %||% "left"
    bold        <- isTRUE(spec$bold)
    itl         <- isTRUE(spec$italic)
    ul          <- isTRUE(spec$underline)
    indent      <- as.integer(spec$indent_twips %||% 0L)
    .build_cell_content(text, align, bold, itl, ul, indent, pad_l, pad_r)
  }, character(1L))
  .build_row(cell_defs, cell_contents, row_height_twips)
}

# ── rtftable renderer ──────────────────────────────────────────────────────────

# Convert a data.frame + old-style metadata list to an rtftable.
# Used for backward compatibility when add_table() receives a plain data.frame.
.df_to_rtftable <- function(df, metadata = NULL) {
  meta <- if (is.list(metadata)) metadata else list()
  rtftable$new(
    data                       = df,
    border                     = "tfl",
    col_rel_width              = meta$col_rel_width,
    column_widths_twips        = meta$column_widths_twips,
    table_width_twips          = meta$table_width_twips,
    table_width_pct_of_writable = meta$table_width_pct_of_writable,
    row_height_twips           = as.integer(meta$row_height_twips %||% 0L)
  )
}

# Render an rtftable object to a character vector of RTF row strings.
.render_rtftable <- function(tbl, writable_width_twips) {
  df      <- tbl$data
  ncols   <- ncol(df)
  nrows   <- nrow(df)
  border  <- tbl$border
  col_spec <- tbl$col_spec  # already normalized list of length ncols
  pad_l   <- tbl$cell_padding_left_twips
  pad_r   <- tbl$cell_padding_right_twips

  cmds       <- .load_rtf_commands()
  valign_cmd <- cmds$cell_valign[[tbl$cell_valign]] %||% "\\clvertalb"

  if (ncols == 0L) return(cmds$paragraph$empty_table)

  cellx      <- .compute_cellx(ncols, writable_width_twips, tbl)

  # Apply row_height_exact flag: negate to signal \trrh exact height.
  .apply_exact <- function(h) {
    if (isTRUE(tbl$row_height_exact) && !is.null(h) && as.integer(h) > 0L)
      -as.integer(h)
    else
      h
  }
  hdr_h  <- .apply_exact(tbl$header_row_height_twips %||% tbl$row_height_twips)
  data_h <- .apply_exact(tbl$row_height_twips)

  lines <- character()

  # 1. Spanning-header rows.
  if (!is.null(tbl$spanning_header)) {
    lines <- c(lines, .render_spanning_rows(
      tbl$spanning_header, cellx,
      border$spanning, hdr_h, pad_l, pad_r, valign_cmd
    ))
  }

  # 2. Column-header rows.
  col_headers <- tbl$col_header %||% list(names(df))
  hdr_border  <- border$header
  for (hdr_row in col_headers) {
    lines <- c(lines, .render_header_row(
      hdr_row, cellx, hdr_border, hdr_h, pad_l, pad_r, valign_cmd, col_spec
    ))
  }

  # Blank separator row RTF builder. Default height = data row height.
  blank_h <- .apply_exact(tbl$blank_row_height_twips %||% tbl$row_height_twips)
  .blank_row_rtf <- function() {
    total_w <- cellx[ncols]
    paste0("\\trowd\\trgaph0\\trleft0\\trrh", blank_h,
           "\\clvertalb\\cellx", total_w,
           " \\cell\\row")
  }

  blank_set <- if (!is.null(tbl$blank_rows)) tbl$blank_rows else integer(0)

  # 3. Data rows, with blank separator rows spliced in.
  if (0L %in% blank_set) lines <- c(lines, .blank_row_rtf())

  for (i in seq_len(nrows)) {
    row_border <- .effective_row_border(
      border$body,
      if (i == 1L) border$first_row else if (i == nrows) border$last_row else list()
    )
    lines <- c(lines, .render_data_row(
      as.list(df[i, , drop = FALSE]),
      cellx, row_border, data_h, pad_l, pad_r, valign_cmd, col_spec
    ))
    if (i %in% blank_set) lines <- c(lines, .blank_row_rtf())
  }

  lines
}

# ── rtfplot renderer ───────────────────────────────────────────────────────────

.render_rtfplot <- function(plot_obj, writable_width_twips) {
  cmds <- .load_rtf_commands()

  # Display dimensions.
  disp_w <- plot_obj$width_twips %||% min(writable_width_twips, .in_to_twips(9))
  disp_h <- if (!is.null(plot_obj$height_twips)) {
    plot_obj$height_twips
  } else {
    as.integer(round(disp_w * plot_obj$img_height / plot_obj$img_width))
  }

  # Read file and convert to uppercase hex.
  raw  <- readBin(plot_obj$path, "raw", n = file.info(plot_obj$path)$size)
  # Split into 126-char lines for readability (standard RTF practice).
  hex_chars <- toupper(paste(format(as.hexmode(as.integer(raw)), width = 2L), collapse = ""))
  hex_lines <- character()
  start <- 1L
  while (start <= nchar(hex_chars)) {
    hex_lines <- c(hex_lines, substr(hex_chars, start, start + 125L))
    start <- start + 126L
  }
  hex_block <- paste(hex_lines, collapse = "\n")

  align_cmd <- switch(plot_obj$align %||% "center",
    left   = "\\ql",
    right  = "\\qr",
    center = "\\qc",
    "\\qc"
  )

  template <- if (plot_obj$img_type == "png") cmds$picture$png_template else cmds$picture$jpeg_template
  .cmd_fmt(template, list(
    align    = align_cmd,
    picw     = plot_obj$img_width,
    pich     = plot_obj$img_height,
    picwgoal = disp_w,
    pichgoal = disp_h,
    hex      = hex_block
  ))
}

# ── Header / footer renderer (unchanged from original) ────────────────────────

.render_header_footer <- function(hf, writable_width_twips, is_footer = FALSE,
                                   total_pages = NULL) {
  if (is.null(hf) || length(hf$rows) == 0L) {
    return(character())
  }

  rows       <- hf$rows
  top_border <- isTRUE(hf$top_border)
  width      <- if (!is.null(hf$width_twips)) hf$width_twips else writable_width_twips
  cmds <- .load_rtf_commands()
  table_cmd <- cmds$table
  align_cmd <- cmds$alignment

  out_rows <- character()
  for (row_idx in seq_along(rows)) {
    row_def  <- rows[[row_idx]]
    # Accept plain vector c(l=..., r=...) directly, or legacy list(columns=c(...)).
    cols_vec <- if (is.list(row_def) && !is.null(row_def$columns)) row_def$columns else row_def
    if (is.null(cols_vec) || length(cols_vec) == 0L) {
      cols_vec <- c("")
    }

    col_names <- names(cols_vec)
    if (is.null(col_names)) col_names <- rep("", length(cols_vec))

    has_l <- "l" %in% col_names
    has_r <- "r" %in% col_names
    has_c <- "c" %in% col_names

    if (has_c) {
      n_cols <- 1L; aligns <- "center"
      cols_display <- c(cols_vec[col_names == "c"])
    } else if (has_l && has_r) {
      n_cols <- 2L; aligns <- c("left", "right")
      cols_display <- c(cols_vec[col_names == "l"], cols_vec[col_names == "r"])
    } else if (has_l) {
      n_cols <- 1L; aligns <- "left"
      cols_display <- c(cols_vec[col_names == "l"])
    } else if (has_r) {
      n_cols <- 1L; aligns <- "right"
      cols_display <- c(cols_vec[col_names == "r"])
    } else {
      n_cols <- length(cols_vec)
      if (n_cols > 3L) stop("Header/footer supports up to 3 columns per row.", call. = FALSE)
      aligns <- if (n_cols == 1L) {
        if (is_footer) "left" else "center"
      } else if (n_cols == 2L) c("left", "right") else c("left", "center", "right")
      cols_display <- cols_vec
    }

    cell_w <- floor(width / n_cols)
    cellx  <- cumsum(rep(cell_w, n_cols))
    apply_border <- top_border && row_idx == 1L

    row <- table_cmd$row_start
    for (cx in cellx) {
      if (apply_border) {
        row <- paste0(row, .cmd_fmt(table_cmd$cell_boundary_top_border_template, list(cx = cx)))
      } else {
        row <- paste0(row, .cmd_fmt(table_cmd$cell_boundary_template, list(cx = cx)))
      }
    }
    for (i in seq_len(n_cols)) {
      at <- switch(aligns[i], left = align_cmd$left, right = align_cmd$right,
                   center = align_cmd$center, align_cmd$default)
      txt <- .render_tokens(cols_display[i], total_pages = total_pages)
      row <- paste0(row, .cmd_fmt(table_cmd$cell_text_aligned_template, list(align = at, text = txt)))
    }
    row <- paste0(row, table_cmd$row_end)
    out_rows <- c(out_rows, row)
  }

  out_rows
}

# ── Metadata resolver (kept for backward compat) ──────────────────────────────

.resolve_block_metadata <- function(default_format, page_options = NULL, block = NULL) {
  out <- list()
  if (!is.null(default_format$table_cell_height_twips)) {
    out$row_height_twips <- as.integer(default_format$table_cell_height_twips)
  }
  if (is.list(page_options) && is.list(page_options$table_metadata_defaults)) {
    out <- .merge_list(out, page_options$table_metadata_defaults)
  }
  if (is.list(block) && is.list(block$metadata)) {
    out <- .merge_list(out, block$metadata)
  }
  out
}

# ── Public API ─────────────────────────────────────────────────────────────────

#' Generate an RTF file from an rtfreport object
#'
#' @param report An `rtfreport` object.
#' @param file_path Output RTF file path.
#' @param overwrite Logical; whether to overwrite an existing file.
#'
#' @return Invisibly returns `file_path`.
#' @export
generate_rtfreport <- function(report, file_path, overwrite = FALSE) {
  if (!inherits(report, "rtfreport")) {
    stop("`report` must be an rtfreport object.", call. = FALSE)
  }
  if (file.exists(file_path) && !isTRUE(overwrite)) {
    stop("`file_path` already exists. Set overwrite = TRUE.", call. = FALSE)
  }

  report$validate()

  doc            <- report$document
  page_defaults  <- doc$default_page
  primary_font   <- doc$font_table[[1]]$name %||% "Courier"
  writable_width <- page_defaults$width_twips -
                    page_defaults$margin_left_twips -
                    page_defaults$margin_right_twips
  cmds     <- .load_rtf_commands()
  doc_cmd  <- cmds$document
  para_cmd <- cmds$paragraph

  # Count total pages.
  total_pages <- sum(vapply(report$sections, function(s) length(s$pages), integer(1L)))

  lines <- c(
    doc_cmd$rtf_header_open,
    .cmd_fmt(doc_cmd$font_table_template, list(font_name = .rtf_escape(primary_font))),
    doc_cmd$color_table_default,
    .cmd_fmt(doc_cmd$page_settings_template, list(
      width_twips           = page_defaults$width_twips,
      height_twips          = page_defaults$height_twips,
      margin_left_twips     = page_defaults$margin_left_twips,
      margin_right_twips    = page_defaults$margin_right_twips,
      margin_top_twips      = page_defaults$margin_top_twips,
      margin_bottom_twips   = page_defaults$margin_bottom_twips,
      font_size_half_points = doc$default_format$font_size_half_points
    ))
  )

  global_page_num <- 1L

  for (s_idx in seq_along(report$sections)) {
    sec <- report$sections[[s_idx]]

    # Combine document-wide and section-specific header rows.
    # When sec$header is present, automatically insert an empty spacer row
    # above it so the section title is visually separated from the common rows.
    sec_header_extra <- if (!is.null(sec$header)) {
      list(c(l = ""), sec$header)
    } else {
      list()
    }
    header_rows <- c(
      if (!is.null(doc$default_header$rows)) doc$default_header$rows else list(),
      sec_header_extra
    )
    header_hf <- list(rows = header_rows, width_twips = doc$default_header$width_twips)

    footer_rows <- c(
      if (!is.null(doc$default_footer$rows)) doc$default_footer$rows else list(),
      if (!is.null(sec$footer)) list(sec$footer) else list()
    )
    footer_hf <- list(
      rows       = footer_rows,
      width_twips = doc$default_footer$width_twips,
      top_border  = isTRUE(doc$default_footer$top_border)
    )

    lines <- c(lines, doc_cmd$section_defaults)

    # Emit {\header} and {\footer} ONCE per section (RTF spec: header/footer
    # applies to all pages in the section; re-emitting per page is incorrect).
    header_rtf <- .render_header_footer(header_hf, writable_width, is_footer = FALSE,
                                        total_pages = total_pages)
    footer_rtf <- .render_header_footer(footer_hf, writable_width, is_footer = TRUE,
                                        total_pages = total_pages)

    if (length(header_rtf) > 0L) {
      lines <- c(lines, .cmd_fmt(doc_cmd$header_wrapper, list(content = paste(header_rtf, collapse = ""))))
    }
    if (length(footer_rtf) > 0L) {
      lines <- c(lines, .cmd_fmt(doc_cmd$footer_wrapper, list(content = paste(footer_rtf, collapse = ""))))
    }

    for (p_idx in seq_along(sec$pages)) {
      page <- sec$pages[[p_idx]]

      if (!is.null(page$title) && nzchar(page$title)) {
        lines <- c(lines, .cmd_fmt(para_cmd$center_bold_template, list(text = .rtf_escape(page$title))))
      }

      for (block in page$content) {
        if (block$type %in% c("table", "listing")) {
          if (inherits(block$data, "rtftable")) {
            tbl <- block$data
          } else {
            block_meta <- .resolve_block_metadata(
              default_format = doc$default_format,
              page_options   = page$page_options,
              block          = block
            )
            tbl <- .df_to_rtftable(block$data, block_meta)
          }
          lines <- c(lines, .render_rtftable(tbl, writable_width))
          if (!is.null(block$footer) && nzchar(block$footer)) {
            lines <- c(lines, .cmd_fmt(para_cmd$left_template, list(text = .rtf_escape(block$footer))))
          }

        } else if (block$type == "figure") {
          if (inherits(block$data, "rtfplot")) {
            lines <- c(lines, .render_rtfplot(block$data, writable_width))
          } else {
            # Legacy path: file-path placeholder.
            fig_path <- block$path
            if (!is.null(fig_path) && !file.exists(fig_path)) {
              stop(sprintf("Figure file not found: %s", fig_path), call. = FALSE)
            }
            lines <- c(lines, .cmd_fmt(
              para_cmd$figure_placeholder_center_template,
              list(filename = .rtf_escape(basename(fig_path)))
            ))
          }
          if (!is.null(block$footer) && nzchar(block$footer)) {
            lines <- c(lines, .cmd_fmt(para_cmd$left_template, list(text = .rtf_escape(block$footer))))
          }
        }
      }

      if (!is.null(page$footer_notes) && nzchar(page$footer_notes)) {
        lines <- c(lines, .cmd_fmt(para_cmd$left_template, list(text = .rtf_escape(page$footer_notes))))
      }

      if (p_idx < length(sec$pages) || s_idx < length(report$sections)) {
        lines <- c(lines, doc_cmd$page_break)
      }

      global_page_num <- global_page_num + 1L
    }

    if (s_idx < length(report$sections)) {
      lines <- c(lines, doc_cmd$section_break)
    }
  }

  lines <- c(lines, doc_cmd$document_close)
  writeLines(lines, con = file_path, useBytes = TRUE)
  invisible(file_path)
}
