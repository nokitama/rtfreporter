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
      # Append installed-package path AFTER local paths so that source-tree runs
      # always pick up the local (possibly newer) resource file first.
      resource_candidates <- c(resource_candidates, file.path(pkg_resource_dir, "rtf_commands.R"))
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

.load_rtfreporter_defaults <- local({
  cache <- NULL
  function() {
    if (!is.null(cache)) {
      return(cache)
    }

    resource_candidates <- c(
      file.path(getwd(), "inst", "resources", "rtfreporter_defaults.R"),
      file.path(getwd(), "r", "rtfreporter", "inst", "resources", "rtfreporter_defaults.R")
    )
    pkg_resource_dir <- system.file("resources", package = "rtfreporter")
    if (nzchar(pkg_resource_dir)) {
      resource_candidates <- c(file.path(pkg_resource_dir, "rtfreporter_defaults.R"), resource_candidates)
    }

    resource_path <- resource_candidates[file.exists(resource_candidates)][1]
    if (is.na(resource_path)) {
      cache <<- list(header_footer_row_height_twips = 360L)
      return(cache)
    }

    env <- new.env(parent = baseenv())
    sys.source(resource_path, envir = env)
    if (!exists("rtfreporter_defaults", envir = env, inherits = FALSE)) {
      stop("`rtfreporter_defaults` not defined in resource file.", call. = FALSE)
    }
    cache <<- get("rtfreporter_defaults", envir = env, inherits = FALSE)
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
# Token reference:
#   {AUTO_PAGE}        -> RTF \chpgn field (dynamic, updated per page by the viewer)
#   {AUTO_TOTAL_PAGES} -> RTF NUMPAGES field (dynamic total, with static fallback)
#   {PAGE}             -> static first-page number of the section (integer)
#   {TOTAL_PAGES}      -> static total page count of the document (integer)
.replace_token <- function(x, token, replacement) {
  # Append a rare sentinel so strsplit never drops a trailing empty string
  # (R's strsplit silently drops trailing "" when the match is at end-of-string).
  sentinel <- "\x01RTFTOK_END\x01"
  parts <- strsplit(paste0(x, sentinel), token, fixed = TRUE)[[1L]]
  # Remove the sentinel from the last element.
  parts[length(parts)] <- sub(sentinel, "", parts[length(parts)], fixed = TRUE)
  paste(parts, collapse = replacement)
}

# Replace page tokens, then RTF-escape.
#
# Token reference (after escaping, braces appear as \{ and \}):
#   \{PAGE\} / \{AUTO_PAGE\}         → \chpgn  (RTF dynamic per-page number)
#   \{AUTO_TOTAL_PAGES\}             → RTF NUMPAGES field  (dynamic, viewer-rendered)
#   \{SECTION_PAGES\}                → RTF SECTIONPAGES field (dynamic, viewer-rendered)
#   \{TOTAL_PAGES\}                  → static integer at render time (total pages in doc)
#
# NOTE: current_page is retained for signature compatibility but is no longer used.
.render_tokens <- function(x, current_page = NULL, total_pages = NULL) {
  if (is.null(x)) return("")
  # Escape first; after escaping, { becomes \{ and } becomes \}, so
  # the token {PAGE} appears as \{PAGE\} and can be substituted safely.
  out <- .rtf_escape(x)

  # Dynamic tokens — rendered per-page by the RTF viewer.
  out <- gsub("\\{PAGE\\}",      "\\chpgn ", out, fixed = TRUE)
  out <- gsub("\\{AUTO_PAGE\\}", "\\chpgn ", out, fixed = TRUE)

  # Dynamic total-pages: RTF NUMPAGES field with static fallback count.
  fallback <- if (!is.null(total_pages)) as.character(total_pages) else "?"
  cmds <- .load_rtf_commands()
  numpages_rtf <- .cmd_fmt(cmds$fields$auto_total_pages, list(total_pages = fallback))
  out <- gsub("\\{AUTO_TOTAL_PAGES\\}", numpages_rtf, out, fixed = TRUE)

  # Dynamic section-pages: RTF SECTIONPAGES field.
  out <- gsub("\\{SECTION_PAGES\\}", cmds$fields$section_pages, out, fixed = TRUE)

  # Static total-pages: integer resolved at render time.
  if (!is.null(total_pages)) {
    out <- gsub("\\{TOTAL_PAGES\\}", as.character(total_pages), out, fixed = TRUE)
  }

  out
}

# ── Border helpers ─────────────────────────────────────────────────────────────

# Build RTF border commands for all four sides of a single cell.
# border_spec: rtf_border object (new style), OR
#              plain list with keys top/bottom/left/right (type string or "none"/NULL)
#              and optional width (integer twips, default 15) (old style).
# color_index_map: named list mapping "#RRGGBB" -> integer color-table index.
# Returns "" when border_spec is NULL (no borders).
.build_border_commands <- function(border_spec, color_index_map = NULL) {
  if (is.null(border_spec)) return("")
  cmds     <- .load_rtf_commands()
  prefixes <- cmds$border$side_prefix
  styles   <- cmds$border$style

  if (inherits(border_spec, "rtf_border")) {
    # New-style: rtf_border with rtf_border_side elements.
    .side <- function(side) {
      b <- border_spec[[side]]
      if (is.null(b)) return("")
      s <- styles[[b$style]]
      if (is.null(s)) stop(sprintf("Unknown border style: '%s'", b$style), call. = FALSE)
      color_cmd <- ""
      if (!is.null(b$color) && !is.null(color_index_map)) {
        idx <- color_index_map[[b$color]]
        if (!is.null(idx)) color_cmd <- paste0("\\brdrcf", idx)
      }
      paste0(prefixes[[side]], s, "\\brdrw", b$width, color_cmd)
    }
  } else {
    # Old-style: plain list with top/bottom/left/right as strings + width.
    width <- as.integer(border_spec$width %||% 15L)
    .side <- function(side) {
      type <- border_spec[[side]]
      if (is.null(type) || type %in% c("none", "")) return("")
      s <- styles[[type]]
      if (is.null(s)) stop(sprintf("Unknown border type: '%s'", type), call. = FALSE)
      paste0(prefixes[[side]], s, "\\brdrw", width)
    }
  }
  paste0(.side("top"), .side("bottom"), .side("left"), .side("right"))
}

# Merge first_row / last_row overrides into a base body border spec.
# Handles both rtf_border objects (new style) and plain lists (old style).
.effective_row_border <- function(base_border, override) {
  if (is.null(base_border)) return(NULL)
  if (is.null(override) || length(override) == 0L) return(base_border)
  if (inherits(base_border, "rtf_border")) {
    return(.merge_rtf_border(base_border, override))
  }
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
.build_row <- function(cell_defs, cell_contents, row_height_twips = NULL, table_align = "left") {
  rh <- if (!is.null(row_height_twips) && as.integer(row_height_twips) != 0L)
    paste0("\\trrh", as.integer(row_height_twips)) else ""
  align_cmd <- switch(table_align, center = "\\trqc", right = "\\trqr", "")
  paste0("\\trowd", rh, align_cmd, paste(cell_defs, collapse = ""), paste(cell_contents, collapse = ""), "\\row")
}

# Build cell definition strings (border + valign + \cellx) for all columns.
.build_cell_defs <- function(cellx, border_spec, valign_cmd) {
  border_cmds <- .build_border_commands(border_spec)
  vapply(cellx, function(cx) paste0(border_cmds, valign_cmd, "\\cellx", cx), character(1L))
}

# Render spanning-header row(s).
# spanning_header: list of list(from, to, label, underline).
.render_spanning_rows <- function(spanning_header, cellx, border_spec,
                                   row_height_twips, pad_l, pad_r, valign_cmd,
                                   table_align = "left") {
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

  .build_row(cell_defs, cell_contents, row_height_twips, table_align)
}

# Render one column-header row.
.render_header_row <- function(hdr_labels, cellx, border_spec, row_height_twips,
                                pad_l, pad_r, valign_cmd, col_spec,
                                table_align = "left") {
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
  .build_row(cell_defs, cell_contents, row_height_twips, table_align)
}

# Render one data row.
.render_data_row <- function(vals, cellx, border_spec, row_height_twips,
                              pad_l, pad_r, valign_cmd, col_spec,
                              table_align = "left") {
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
  .build_row(cell_defs, cell_contents, row_height_twips, table_align)
}

# ── rtftable renderer ──────────────────────────────────────────────────────────

# Convert a data.frame + old-style metadata list to an rtftable.
# Used for backward compatibility when add_table() receives a plain data.frame.
.df_to_rtftable <- function(df, metadata = NULL) {
  meta <- if (is.list(metadata)) metadata else list()
  rtftable_r6$new(
    data                       = df,
    border                     = "tfl",
    col_rel_width              = meta$col_rel_width,
    column_widths_twips        = meta$column_widths_twips,
    table_width_twips          = meta$table_width_twips,
    table_width_pct_of_writable = meta$table_width_pct_of_writable,
    row_height_twips           = as.integer(meta$row_height_twips %||% 0L)
  )
}

# Render one data.frame section of an rtftable (headers + data rows).
# Used by both single-DF and multi-DF render paths.
.render_rtftable_section <- function(
    df, col_headers, cellx, border, col_spec,
    hdr_h, data_h, blank_h, blank_set,
    pad_l, pad_r, valign_cmd,
    spanning_header, table_align = "left") {

  ncols <- length(cellx)
  nrows <- nrow(df)
  lines <- character()

  # Spanning-header rows (repeated per DF in multi-DF mode).
  if (!is.null(spanning_header)) {
    lines <- c(lines, .render_spanning_rows(
      spanning_header, cellx,
      border$spanning, hdr_h, pad_l, pad_r, valign_cmd, table_align
    ))
  }

  # Column-header rows.
  hdr_border <- border$header
  for (hdr_row in col_headers) {
    lines <- c(lines, .render_header_row(
      hdr_row, cellx, hdr_border, hdr_h, pad_l, pad_r, valign_cmd, col_spec, table_align
    ))
  }

  align_cmd <- switch(table_align, center = "\\trqc", right = "\\trqr", "")
  .blank_row_rtf <- function() {
    total_w <- cellx[ncols]
    paste0("\\trowd\\trgaph0\\trleft0\\trrh", blank_h,
           align_cmd, "\\clvertalb\\cellx", total_w,
           " \\cell\\row")
  }

  # Data rows, with blank separator rows spliced in.
  if (0L %in% blank_set) lines <- c(lines, .blank_row_rtf())

  for (i in seq_len(nrows)) {
    row_border <- .effective_row_border(
      border$body,
      if (i == 1L) border$first_row else if (i == nrows) border$last_row else NULL
    )
    lines <- c(lines, .render_data_row(
      as.list(df[i, , drop = FALSE]),
      cellx, row_border, data_h, pad_l, pad_r, valign_cmd, col_spec, table_align
    ))
    if (i %in% blank_set) lines <- c(lines, .blank_row_rtf())
  }

  lines
}

# Render an rtftable object to a character vector of RTF row strings.
# Handles both single-DF and multi-DF modes transparently.
.render_rtftable <- function(tbl, writable_width_twips) {
  border   <- tbl$border
  col_spec <- tbl$col_spec
  pad_l    <- tbl$cell_padding_left_twips
  pad_r    <- tbl$cell_padding_right_twips

  cmds       <- .load_rtf_commands()
  valign_cmd <- cmds$cell_valign[[tbl$cell_valign]] %||% "\\clvertalb"

  # Determine column count from whichever mode is active.
  ref_df <- if (!is.null(tbl$data_list)) tbl$data_list[[1L]] else tbl$data
  ncols  <- ncol(ref_df)

  if (ncols == 0L) return(cmds$paragraph$empty_table)

  cellx <- .compute_cellx(ncols, writable_width_twips, tbl)

  # Apply row_height_exact flag: negate twips value to signal \trrh exact height.
  .apply_exact <- function(h) {
    if (isTRUE(tbl$row_height_exact) && !is.null(h) && as.integer(h) > 0L)
      -as.integer(h)
    else
      h
  }
  hdr_h   <- .apply_exact(tbl$header_row_height_twips %||% tbl$row_height_twips)
  data_h  <- .apply_exact(tbl$row_height_twips)
  blank_h <- .apply_exact(tbl$blank_row_height_twips %||% tbl$row_height_twips)

  blank_set <- if (!is.null(tbl$blank_rows)) tbl$blank_rows else integer(0)

  table_align <- tbl$table_align %||% "left"

  if (!is.null(tbl$data_list)) {
    # ── Multi-DF mode ──────────────────────────────────────────────────────────
    lines <- character()
    for (df_i in seq_along(tbl$data_list)) {
      df      <- tbl$data_list[[df_i]]
      # Per-DF header (NULL → use column names of this DF).
      hdr_spec    <- tbl$col_header_list[[df_i]]
      col_headers <- hdr_spec %||% list(names(df))

      lines <- c(lines, .render_rtftable_section(
        df          = df,
        col_headers = col_headers,
        cellx       = cellx,
        border      = border,
        col_spec    = col_spec,
        hdr_h       = hdr_h,
        data_h      = data_h,
        blank_h     = blank_h,
        blank_set   = blank_set,
        pad_l       = pad_l,
        pad_r       = pad_r,
        valign_cmd  = valign_cmd,
        spanning_header = tbl$spanning_header,
        table_align     = table_align
      ))
    }
    return(lines)
  }

  # ── Single-DF mode (existing behaviour) ────────────────────────────────────
  df          <- tbl$data
  col_headers <- tbl$col_header %||% list(names(df))

  .render_rtftable_section(
    df          = df,
    col_headers = col_headers,
    cellx       = cellx,
    border      = border,
    col_spec    = col_spec,
    hdr_h       = hdr_h,
    data_h      = data_h,
    blank_h     = blank_h,
    blank_set   = blank_set,
    pad_l       = pad_l,
    pad_r       = pad_r,
    valign_cmd  = valign_cmd,
    spanning_header = tbl$spanning_header,
    table_align     = table_align
  )
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

# Normalize a section header/footer value to list(rows=list(...), width_twips=NULL).
# Accepts: NULL | plain named vector (single row) | list(rows=list(...)) | list(columns=c(...)) (legacy).
.normalize_hf <- function(hf) {
  if (is.null(hf)) return(NULL)
  # Already multi-row form
  if (is.list(hf) && !is.null(hf$rows)) return(hf)
  # Legacy single-row list(columns = c(...))
  if (is.list(hf) && !is.null(hf$columns)) return(list(rows = list(hf), width_twips = NULL))
  # Plain named vector — single row
  list(rows = list(hf), width_twips = NULL)
}

.render_header_footer <- function(hf, writable_width_twips, is_footer = FALSE,
                                   current_page = NULL, total_pages = NULL,
                                   color_index_map = NULL) {
  if (is.null(hf) || length(hf$rows) == 0L) {
    return(character())
  }

  rows        <- hf$rows
  hf_border   <- hf$border   # rtf_border or NULL
  width       <- if (!is.null(hf$width_twips)) hf$width_twips else writable_width_twips
  cmds <- .load_rtf_commands()
  table_cmd <- cmds$table
  align_cmd <- cmds$alignment

  defaults <- .load_rtfreporter_defaults()
  rh_value <- hf$row_height_twips %||% defaults$header_footer_row_height_twips
  rh_str   <- .cmd_fmt(table_cmd$row_height_template,
                        list(row_height_twips = rh_value))

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

    # Column count rules:
    # - c present with l or r -> 3 columns (fill missing with "")
    # - l + r (no c)          -> 2 columns
    # - single key only       -> 1 column
    # - unnamed               -> count-based defaults
    if (has_c && (has_l || has_r)) {
      n_cols <- 3L
      aligns <- c("left", "center", "right")
      cols_display <- c(
        if (has_l) cols_vec[col_names == "l"][[1L]] else "",
        cols_vec[col_names == "c"][[1L]],
        if (has_r) cols_vec[col_names == "r"][[1L]] else ""
      )
    } else if (has_l && has_r) {
      n_cols <- 2L; aligns <- c("left", "right")
      cols_display <- c(cols_vec[col_names == "l"][[1L]], cols_vec[col_names == "r"][[1L]])
    } else if (has_c) {
      n_cols <- 1L; aligns <- "center"
      cols_display <- c(cols_vec[col_names == "c"][[1L]])
    } else if (has_l) {
      n_cols <- 1L; aligns <- "left"
      cols_display <- c(cols_vec[col_names == "l"][[1L]])
    } else if (has_r) {
      n_cols <- 1L; aligns <- "right"
      cols_display <- c(cols_vec[col_names == "r"][[1L]])
    } else {
      n_cols <- length(cols_vec)
      if (n_cols > 3L) stop("Header/footer supports up to 3 columns per row.", call. = FALSE)
      aligns <- if (n_cols == 1L) {
        "center"
      } else if (n_cols == 2L) c("left", "right") else c("left", "center", "right")
      cols_display <- cols_vec
    }

    cell_w <- floor(width / n_cols)
    cellx  <- cumsum(rep(cell_w, n_cols))
    # Border applies only to the first row of the header/footer block.
    row_border_cmds <- if (row_idx == 1L) .build_border_commands(hf_border, color_index_map) else ""

    row <- table_cmd$row_start
    row <- paste0(row, rh_str)
    for (cx in cellx) {
      if (nzchar(row_border_cmds)) {
        row <- paste0(row, row_border_cmds, "\\cellx", cx)
      } else {
        row <- paste0(row, .cmd_fmt(table_cmd$cell_boundary_template, list(cx = cx)))
      }
    }
    for (i in seq_len(n_cols)) {
      at <- switch(aligns[i], left = align_cmd$left, right = align_cmd$right,
                   center = align_cmd$center, align_cmd$default)
      txt <- .render_tokens(cols_display[i], current_page = current_page, total_pages = total_pages)
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

# ── Color table helpers ────────────────────────────────────────────────────────

# Collect all unique hex color strings used in border specs across the report.
# Returns a character vector of unique "#RRGGBB" strings (may be empty).
.collect_report_colors <- function(report) {
  cols <- character(0)

  .hf_colors <- function(hf) {
    if (is.null(hf)) return(character(0))
    b <- hf$border
    if (is.null(b) || !inherits(b, "rtf_border")) return(character(0))
    .collect_border_colors(b)
  }

  .tbl_colors <- function(tbl) {
    if (!inherits(tbl, "rtftable")) return(character(0))
    tb <- tbl$border
    if (is.null(tb)) return(character(0))
    if (inherits(tb, "rtf_table_border")) {
      return(.collect_table_border_colors(tb))
    }
    # Old plain-list format — no color support.
    character(0)
  }

  for (sec in report$sections) {
    cols <- c(cols, .hf_colors(.normalize_hf(sec$header)))
    cols <- c(cols, .hf_colors(.normalize_hf(sec$footer)))
    for (pg in sec$pages) {
      for (blk in pg$content) {
        if (inherits(blk$data, "rtftable")) cols <- c(cols, .tbl_colors(blk$data))
      }
    }
  }
  unique(cols)
}

# Build the RTF color table string from a character vector of hex colors.
# Returns the RTF {\colortbl ...} string.
# Color indices: 1 = first entry (after the implicit auto-color entry).
.build_color_table_rtf <- function(hex_colors) {
  if (length(hex_colors) == 0L) {
    return("{\\colortbl;\\red0\\green0\\blue0;}")
  }
  entries <- vapply(hex_colors, function(h) {
    h <- sub("^#", "", h)
    r <- strtoi(substr(h, 1L, 2L), 16L)
    g <- strtoi(substr(h, 3L, 4L), 16L)
    b <- strtoi(substr(h, 5L, 6L), 16L)
    sprintf("\\red%d\\green%d\\blue%d;", r, g, b)
  }, character(1L))
  paste0("{\\colortbl;\\red0\\green0\\blue0;", paste(entries, collapse = ""), "}")
}

# Build a named list mapping "#RRGGBB" -> integer color-table index (1-based).
# Index 1 = black (auto), so user colors start at 2.
.build_color_index_map <- function(hex_colors) {
  if (length(hex_colors) == 0L) return(list())
  idx <- seq_along(hex_colors) + 1L   # +1 because index 1 = black
  stats::setNames(as.list(idx), hex_colors)
}



#' Generate an RTF file from an rtfreport object
#'
#' @param report An `rtfreport` object.
#' @param file_path Output RTF file path.
#' @param overwrite Logical; whether to overwrite an existing file.
# ============================================================================
# Pipe API Adapter: Convert rtf_document → rtfreport_r6
# ============================================================================

# Internal helper: convert S3 rtf_document (pipe API) to R6 rtfreport_r6
# for rendering via existing RTF generation logic.
.pipe_doc_to_r6_report <- function(pipe_doc) {
  if (!inherits(pipe_doc, "rtf_document")) {
    return(NULL) # Not a pipe document
  }

  # Create new R6 report with same document settings
  r6_report <- rtfreport_r6$new()

  # Copy document settings
  if (!is.null(pipe_doc$document$font_table)) {
    r6_report$set_document_defaults(
      font_table = pipe_doc$document$font_table
    )
  }
  if (!is.null(pipe_doc$document$color_table)) {
    r6_report$set_document_defaults(
      color_table = pipe_doc$document$color_table
    )
  }
  if (!is.null(pipe_doc$document$page)) {
    page_spec <- pipe_doc$document$page
    if (!is.null(page_spec)) {
      # Convert page dimensions and margins from inches to twips
      r6_report$set_default_page(list(
        orientation        = page_spec$orientation %||% "landscape",
        width_twips        = .in_to_twips(page_spec$width_in %||% 11),
        height_twips       = .in_to_twips(page_spec$height_in %||% 8.5),
        margin_left_twips  = .in_to_twips(page_spec$margin_left_in %||% 0.5),
        margin_right_twips = .in_to_twips(page_spec$margin_right_in %||% 0.5),
        margin_top_twips   = .in_to_twips(page_spec$margin_top_in %||% 0.75),
        margin_bottom_twips = .in_to_twips(page_spec$margin_bottom_in %||% 0.75)
      ))
    }
  }

  # Map sections and pages from pipe API structure
  # In pipe API: sections is a list with page numbers as keys
  # Example: sections$`1` = page 1 section, sections$`3` = page 3 section
  # Pages between section starts inherit the previous section's header/footer

  # First, determine section boundaries
  section_page_breaks <- as.numeric(names(pipe_doc$sections))
  section_page_breaks <- sort(section_page_breaks)

  # Add sections to R6 report
  section_idx_map <- list()  # Map: page_num -> section_idx
  current_section_idx <- NA

  for (page_num in 1:length(pipe_doc$contents)) {
    # Check if a new section starts at this page
    if (page_num %in% section_page_breaks) {
      # Add new section
      sec_info <- pipe_doc$sections[[as.character(page_num)]]
      current_section_idx <- r6_report$add_section(
        header = sec_info$header,
        footer = sec_info$footer
      )
    } else if (is.na(current_section_idx)) {
      # No sections defined, create default first section
      current_section_idx <- r6_report$add_section()
    }

    # Map this page to its section
    section_idx_map[[as.character(page_num)]] <- current_section_idx
  }

  # Add content as pages
  for (page_num in 1:length(pipe_doc$contents)) {
    content_item <- pipe_doc$contents[[page_num]]
    sec_idx <- section_idx_map[[as.character(page_num)]]

    # Add page with content
    r6_report$add_page(section_index = sec_idx, content = list(content_item))
  }

  r6_report
}

#'
#' @return Invisibly returns `file_path`.
#' @export
generate_rtfreport <- function(report, file_path, overwrite = FALSE) {
  # Support both R6 rtfreport_r6 objects and S3 rtf_document pipe API objects
  if (inherits(report, "rtf_document")) {
    # Convert pipe API object to R6 object
    report <- .pipe_doc_to_r6_report(report)
    if (is.null(report)) {
      stop("`report` must be an rtfreport or rtf_document object.", call. = FALSE)
    }
  } else if (!inherits(report, "rtfreport_r6")) {
    stop("`report` must be an rtfreport object (from rtfreport()) or rtf_document (from rtf_document()).",
         call. = FALSE)
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

  # Build dynamic color table from all border colors in the report.
  doc_colors       <- .collect_report_colors(report)
  color_table_str  <- .build_color_table_rtf(doc_colors)
  color_index_map  <- .build_color_index_map(doc_colors)

  lines <- c(
    doc_cmd$rtf_header_open,
    .cmd_fmt(doc_cmd$font_table_template, list(font_name = .rtf_escape(primary_font))),
    color_table_str,
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
  prev_header_hf  <- NULL
  prev_footer_hf  <- NULL

  for (s_idx in seq_along(report$sections)) {
    sec <- report$sections[[s_idx]]

    # Resolve header: normalize current section's header, or inherit from previous.
    cur_header_hf <- .normalize_hf(sec$header)
    if (is.null(cur_header_hf)) cur_header_hf <- prev_header_hf
    prev_header_hf <- cur_header_hf

    # Resolve footer: normalize current section's footer, or inherit from previous.
    cur_footer_hf <- .normalize_hf(sec$footer)
    if (is.null(cur_footer_hf)) cur_footer_hf <- prev_footer_hf
    prev_footer_hf <- cur_footer_hf

    lines <- c(lines, doc_cmd$section_defaults)

    # Emit {\header} and {\footer} ONCE per section (RTF spec: header/footer
    # applies to all pages in the section; re-emitting per page is incorrect).
    sec_first_page <- global_page_num
    header_rtf <- .render_header_footer(cur_header_hf, writable_width, is_footer = FALSE,
                                        current_page = sec_first_page, total_pages = total_pages,
                                        color_index_map = color_index_map)
    footer_rtf <- .render_header_footer(cur_footer_hf, writable_width, is_footer = TRUE,
                                        current_page = sec_first_page, total_pages = total_pages,
                                        color_index_map = color_index_map)

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
          if (inherits(block$data, "rtftable_r6")) {
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
          if (inherits(block$data, "rtfplot_r6")) {
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

      if (p_idx < length(sec$pages)) {
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
