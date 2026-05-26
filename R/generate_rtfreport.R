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
      # Built-in fallback: hard-coded approximation of the resource file.
      cache <<- list(
        default_row_height_twips_by_font_half_points = list("18" = 230L),
        default_row_height_twips_per_half_point      = 12.8,
        default_row_height_twips_min                 = 180L,
        default_cell_padding_left_twips              = 72L,
        default_cell_padding_right_twips             = 72L
      )
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

# ── Magic-token resolution for blank rows ─────────────────────────────────────
#
# A single character value may carry one of two "blank row" markers used by
# titles, footnotes, and RTF page header/footer rows:
#
#   "{HALF_BLANK_ROW}"  — render an empty row at half the default row height
#   "{BLANK_ROW}"       — render an empty row at the full default row height
#                          (synonym of "" for a single-cell context)
#
# `.parse_blank_token()` returns a named list:
#   text          — text to actually print ("" for blank rows)
#   height_factor — multiplier applied to .default_row_height_twips()
#                    (1.0 = full default, 0.5 = half)
#   is_blank      — TRUE when no visible text
#
# Treating an empty string as a full-default blank row is intentional: users
# who type `""` get a plain empty row, while the explicit
# `"{HALF_BLANK_ROW}"` is required for the half-height variant.
.parse_blank_token <- function(text) {
  if (is.null(text)) text <- ""
  text <- as.character(text)
  if (length(text) != 1L) text <- paste(text, collapse = "\n")
  if (identical(text, "{HALF_BLANK_ROW}")) {
    list(text = "", height_factor = 0.5, is_blank = TRUE)
  } else if (identical(text, "{BLANK_ROW}") || !nzchar(text)) {
    list(text = "", height_factor = 1.0, is_blank = TRUE)
  } else {
    list(text = text, height_factor = 1.0, is_blank = FALSE)
  }
}

# Resolve a height factor (1.0, 0.5, ...) to a twips integer based on the
# document font size.
.row_height_from_factor <- function(factor, font_half_points) {
  default_h <- .default_row_height_twips(font_half_points)
  as.integer(round(default_h * as.numeric(factor)))
}

# Resolve the default row (cell) height for a given font size.
#
# Looked up from `rtfreporter_defaults.R`:
#   1. If the font size (in half-points) appears in the lookup table, that
#      value is returned.
#   2. Otherwise a linear fallback `font_half_points * per_half_point` is
#      used.
#   3. The result is clamped to `default_row_height_twips_min`.
#
# Used by all table-shaped renderers (header / footer / table body /
# footnote) so a single resource-file entry controls the package-wide
# default visual density.
.default_row_height_twips <- function(font_half_points = 18L) {
  defaults <- .load_rtfreporter_defaults()
  fhp <- as.integer(font_half_points %||% 18L)

  tbl <- defaults$default_row_height_twips_by_font_half_points
  key <- as.character(fhp)
  h <- if (!is.null(tbl) && key %in% names(tbl)) {
    as.integer(tbl[[key]])
  } else {
    rate <- defaults$default_row_height_twips_per_half_point %||% 12.8
    as.integer(round(fhp * as.numeric(rate)))
  }

  lo <- as.integer(defaults$default_row_height_twips_min %||% 0L)
  if (h < lo) lo else h
}

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
# font_half_points drives the default row-height lookup when the table does
# not specify an explicit row_height_twips.
.render_rtftable <- function(tbl, writable_width_twips, font_half_points = 18L) {
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

  # Resolve the effective body row height:
  #   • explicit positive integer  → use as given
  #   • 0L                          → legacy "automatic" (no \trrh emitted)
  #   • NULL                        → apply the document-wide default
  base_rh   <- tbl$row_height_twips
  effective <- if (is.null(base_rh)) {
    .default_row_height_twips(font_half_points)
  } else {
    as.integer(base_rh)
  }

  # Apply row_height_exact flag: negate twips value to signal \trrh exact height.
  .apply_exact <- function(h) {
    if (isTRUE(tbl$row_height_exact) && !is.null(h) && as.integer(h) > 0L)
      -as.integer(h)
    else
      h
  }
  hdr_h   <- .apply_exact(tbl$header_row_height_twips %||% effective)
  data_h  <- .apply_exact(effective)
  blank_h <- .apply_exact(tbl$blank_row_height_twips %||% effective)

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
                                   color_index_map = NULL,
                                   font_half_points = 18L) {
  if (is.null(hf) || length(hf$rows) == 0L) {
    return(character())
  }

  rows        <- hf$rows
  hf_border   <- hf$border   # rtf_border or NULL
  width       <- if (!is.null(hf$width_twips)) hf$width_twips else writable_width_twips
  cmds <- .load_rtf_commands()
  table_cmd <- cmds$table
  align_cmd <- cmds$alignment

  rh_full  <- hf$row_height_twips %||% .default_row_height_twips(font_half_points)
  rh_str   <- .cmd_fmt(table_cmd$row_height_template,
                        list(row_height_twips = rh_full))
  rh_half  <- as.integer(round(rh_full * 0.5))
  rh_h_str <- .cmd_fmt(table_cmd$row_height_template,
                        list(row_height_twips = rh_half))

  out_rows <- character()
  for (row_idx in seq_along(rows)) {
    row_def  <- rows[[row_idx]]
    # Accept plain vector c(l=..., r=...) directly, or legacy list(columns=c(...)).
    cols_vec <- if (is.list(row_def) && !is.null(row_def$columns)) row_def$columns else row_def
    if (is.null(cols_vec) || length(cols_vec) == 0L) {
      cols_vec <- c("")
    }

    # ── Magic blank-row token: any cell value == "{HALF_BLANK_ROW}" ─────────
    is_half_blank <- any(vapply(cols_vec, function(x) {
      identical(as.character(x), "{HALF_BLANK_ROW}")
    }, logical(1L)))
    if (is_half_blank) {
      # Single empty cell spanning the full width at half default row height.
      row_border_cmds <- if (row_idx == 1L)
        .build_border_commands(hf_border, color_index_map) else ""
      row <- paste0(table_cmd$row_start, rh_h_str)
      if (nzchar(row_border_cmds)) {
        row <- paste0(row, row_border_cmds, "\\cellx", width)
      } else {
        row <- paste0(row, .cmd_fmt(table_cmd$cell_boundary_template, list(cx = width)))
      }
      row <- paste0(row, .cmd_fmt(table_cmd$cell_text_aligned_template,
                                   list(align = align_cmd$left, text = "")))
      row <- paste0(row, table_cmd$row_end)
      out_rows <- c(out_rows, row)
      next
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
    if (!inherits(tbl, "rtftable_r6")) return(character(0))
    tb <- tbl$border
    if (is.null(tb)) return(character(0))
    if (inherits(tb, "rtf_table_border")) return(.collect_table_border_colors(tb))
    character(0)
  }

  for (sec in report$sections) {
    cols <- c(cols, .hf_colors(.normalize_hf(sec$header)))
    cols <- c(cols, .hf_colors(.normalize_hf(sec$footer)))
  }
  for (pg in report$pages) {
    ct <- pg$content
    if (inherits(ct, "rtftable_r6")) cols <- c(cols, .tbl_colors(ct))
  }
  unique(cols)
}

# Resolve sections to sorted list with from_page / to_page ranges.
# Returns a list of list(header, footer, from_page, to_page).
.resolve_sections <- function(report) {
  n_pages <- length(report$pages)
  if (n_pages == 0L) return(list())

  sections <- report$sections
  from_pages <- vapply(sections, function(s) {
    fp <- s$from_page
    if (is.null(fp) || is.na(fp)) NA_integer_ else as.integer(fp)
  }, integer(1L))

  # Single section with no from_page → covers all pages
  if (length(sections) == 1L && is.na(from_pages[1L])) from_pages[1L] <- 1L

  # Sort by from_page (NAs last, assigned sequentially)
  ord        <- order(from_pages, na.last = TRUE)
  sections   <- sections[ord]
  from_pages <- from_pages[ord]
  from_pages[1L] <- 1L  # first section always starts at page 1

  n_sec    <- length(sections)
  to_pages <- c(if (n_sec > 1L) from_pages[-1L] - 1L else integer(0L), n_pages)

  lapply(seq_len(n_sec), function(i) {
    list(
      header    = sections[[i]]$header,
      footer    = sections[[i]]$footer,
      from_page = from_pages[i],
      to_page   = to_pages[i]
    )
  })
}

# Compute the rendered width of a content block in twips.
.compute_content_width <- function(content, writable_width) {
  if (is.null(content)) return(writable_width)
  if (inherits(content, "rtftable_r6")) {
    if (!is.null(content$column_widths_twips)) return(sum(as.integer(content$column_widths_twips)))
    if (!is.null(content$table_width_twips))   return(as.integer(content$table_width_twips))
    if (!is.null(content$table_width_pct_of_writable)) {
      return(as.integer(round(writable_width * content$table_width_pct_of_writable)))
    }
  }
  if (inherits(content, "rtfplot_r6")) {
    return(content$width_twips %||% writable_width)
  }
  writable_width
}

# Render footnote as an N×1 RTF table directly below the content block.
#
# `footnote` is a character vector — each element becomes one row.
# Magic tokens ({HALF_BLANK_ROW}, {BLANK_ROW}) are honoured per row.
# The top border is emitted on the first row only.
.render_footnote_table <- function(footnote, width_twips, font_half_points = 18L) {
  if (is.null(footnote) || length(footnote) == 0L) return(character())
  border_cmd <- .build_border_commands(rtf_border_top())
  defaults   <- .load_rtfreporter_defaults()
  pad_l      <- as.integer(defaults$default_cell_padding_left_twips  %||% 72L)
  pad_r      <- as.integer(defaults$default_cell_padding_right_twips %||% 72L)

  rows_rtf <- character()
  for (i in seq_along(footnote)) {
    parsed   <- .parse_blank_token(footnote[[i]])
    rh       <- .row_height_from_factor(parsed$height_factor, font_half_points)
    text_rtf <- if (parsed$is_blank) "" else .format_cell_text(parsed$text)
    border   <- if (i == 1L) border_cmd else ""
    rows_rtf <- c(rows_rtf, paste0(
      "\\trowd\\trgaph0\\trrh", rh,
      border, "\\clvertalb\\cellx", width_twips,
      "\\ql\\li", pad_l, "\\ri", pad_r, " ", text_rtf, "\\cell",
      "\\row"
    ))
  }
  rows_rtf
}

# Render a content title as an N×1 RTF table sitting above the content block.
#
# `title` is a character vector — each element becomes one row.
# When `title` is NULL (the default), one `{HALF_BLANK_ROW}` row is emitted
# automatically so there is always a small visual gap between the RTF page
# header and the content.  Use `title = character(0)` to suppress the title
# block entirely.
#
# Non-blank rows are centred and bold; blank rows omit the bold attribute.
.render_title_table <- function(title, width_twips, font_half_points = 18L) {
  if (is.null(title)) {
    title <- "{HALF_BLANK_ROW}"
  }
  if (length(title) == 0L) return(character())

  defaults <- .load_rtfreporter_defaults()
  pad_l    <- as.integer(defaults$default_cell_padding_left_twips  %||% 72L)
  pad_r    <- as.integer(defaults$default_cell_padding_right_twips %||% 72L)

  rows_rtf <- character()
  for (i in seq_along(title)) {
    parsed <- .parse_blank_token(title[[i]])
    rh     <- .row_height_from_factor(parsed$height_factor, font_half_points)
    cell_def <- paste0("\\clvertalb\\cellx", width_twips)
    if (parsed$is_blank) {
      cell_content <- paste0("\\ql\\li", pad_l, "\\ri", pad_r, " \\cell")
    } else {
      txt <- .format_cell_text(parsed$text)
      cell_content <- paste0("\\qc\\li", pad_l, "\\ri", pad_r,
                              " \\b ", txt, "\\b0 \\cell")
    }
    rows_rtf <- c(rows_rtf, paste0(
      "\\trowd\\trgaph0\\trrh", rh,
      cell_def, cell_content,
      "\\row"
    ))
  }
  rows_rtf
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



# ============================================================================
# Pipe API Adapter: Convert rtf_document → rtfreport_r6
# ============================================================================

# ── auto_section helpers ───────────────────────────────────────────────────────

# Build a per-section header by appending a label row to the base header
# from the "_default" section.
# default_sec : the "_default" entry from pipe_doc$sections (or NULL).
# label       : character label to append as a new row.
# label_align : "left" | "center" | "right"
.build_auto_section_header <- function(default_sec, label, label_align = "left") {
  base_hdr <- if (!is.null(default_sec)) default_sec$header else NULL
  norm     <- .normalize_hf(base_hdr)

  label_row <- switch(label_align,
    right  = c(r = label),
    center = c(c = label),
    c(l = label)   # default: left
  )

  if (is.null(norm)) {
    # No base header: create a single-row header with just the label.
    return(list(rows = list(label_row)))
  }

  # Append label row to the existing rows list.
  norm$rows <- c(norm$rows, list(label_row))
  norm
}

# Unwrap an rtf_auto_section_item to its underlying content object.
# By contract, item$content is always a single rtftable_r6, rtfplot_r6, or
# data.frame (validated and promoted in rtf_tables()).
.unwrap_auto_section_item <- function(item) {
  item$content
}

# Internal helper: pass through a single content item.
# By contract, rtf_tables() and rtf_figures() guarantee a single content
# object (rtftable_r6, rtfplot_r6, or data.frame) per element.
.normalise_content_item <- function(content_item) {
  content_item
}

# Internal helper: convert S3 rtf_document (pipe API) to R6 rtfreport_r6.
.pipe_doc_to_r6_report <- function(pipe_doc) {
  if (!inherits(pipe_doc, "rtf_document")) return(NULL)

  r6_report <- rtfreport_r6$new()

  # Copy document-level settings
  if (!is.null(pipe_doc$document$font_table)) {
    r6_report$set_document_defaults(font_table = pipe_doc$document$font_table)
  }
  if (!is.null(pipe_doc$document$color_table)) {
    r6_report$set_document_defaults(color_table = pipe_doc$document$color_table)
  }
  if (!is.null(pipe_doc$document$page)) {
    ps <- pipe_doc$document$page
    r6_report$set_default_page(list(
      orientation         = ps$orientation        %||% "landscape",
      width_twips         = .in_to_twips(ps$width_in        %||% 11),
      height_twips        = .in_to_twips(ps$height_in       %||% 8.5),
      margin_left_twips   = .in_to_twips(ps$margin_left_in  %||% 0.5),
      margin_right_twips  = .in_to_twips(ps$margin_right_in %||% 0.5),
      margin_top_twips    = .in_to_twips(ps$margin_top_in   %||% 0.75),
      margin_bottom_twips = .in_to_twips(ps$margin_bottom_in %||% 0.75)
    ))
  }
  if (!is.null(pipe_doc$document$default_format)) {
    r6_report$set_default_format(pipe_doc$document$default_format)
  }

  # ── Detect auto-section items ─────────────────────────────────────────────
  has_auto_section <- any(vapply(pipe_doc$contents,
    function(x) inherits(x, "rtf_auto_section_item"), logical(1L)))

  if (has_auto_section) {
    # ── Auto-section path ──────────────────────────────────────────────────
    # "_default" section provides the base header/footer template.
    default_sec <- pipe_doc$sections[["_default"]]

    # Add any explicit page-number sections (not "_default") first.
    all_keys     <- names(pipe_doc$sections)
    explicit_keys <- sort(as.integer(all_keys[all_keys != "_default"]))
    for (key in explicit_keys) {
      si <- pipe_doc$sections[[as.character(key)]]
      r6_report$add_section(header = si$header, footer = si$footer,
                             from_page = key)
    }

    # Process contents one by one, creating one RTF section per named item.
    page_counter <- 0L
    for (ci in seq_along(pipe_doc$contents)) {
      content_item <- pipe_doc$contents[[ci]]
      page_counter <- page_counter + 1L

      if (inherits(content_item, "rtf_auto_section_item")) {
        label       <- content_item$label
        label_align <- content_item$label_align %||% "left"
        sec_header  <- .build_auto_section_header(default_sec, label, label_align)
        sec_footer  <- if (!is.null(default_sec)) default_sec$footer else NULL
        r6_report$add_section(header = sec_header, footer = sec_footer,
                               from_page = page_counter)
        ct <- .unwrap_auto_section_item(content_item)
      } else {
        ct <- .normalise_content_item(content_item)
      }
      title_i    <- if (ci <= length(pipe_doc$titles))    pipe_doc$titles[[ci]]    else NULL
      footnote_i <- if (ci <= length(pipe_doc$footnotes)) pipe_doc$footnotes[[ci]] else NULL
      r6_report$add_page(content = ct, title = title_i, footnote = footnote_i)
    }

    # Guard: if no section was added at all (e.g., all items were non-auto),
    # fall back to the "_default" section or an empty one.
    if (length(r6_report$sections) == 0L) {
      if (!is.null(default_sec)) {
        r6_report$add_section(header = default_sec$header,
                               footer = default_sec$footer)
      } else {
        r6_report$add_section()
      }
    }

  } else {
    # ── Original path (no auto-section items) ─────────────────────────────
    all_keys     <- names(pipe_doc$sections)
    non_def_keys <- all_keys[all_keys != "_default"]
    section_keys <- sort(as.integer(non_def_keys))

    if (length(section_keys) == 0L) {
      # No explicit page sections – use "_default" or an empty default.
      default_sec <- pipe_doc$sections[["_default"]]
      if (!is.null(default_sec)) {
        r6_report$add_section(header = default_sec$header,
                               footer = default_sec$footer)
      } else {
        r6_report$add_section()  # default section covering all pages
      }
    } else {
      for (key in section_keys) {
        si <- pipe_doc$sections[[as.character(key)]]
        r6_report$add_section(header = si$header, footer = si$footer,
                               from_page = key)
      }
    }

    # Add pages from pipe_doc$contents (each element = one page)
    for (ci in seq_along(pipe_doc$contents)) {
      ct         <- .normalise_content_item(pipe_doc$contents[[ci]])
      title_i    <- if (ci <= length(pipe_doc$titles))    pipe_doc$titles[[ci]]    else NULL
      footnote_i <- if (ci <= length(pipe_doc$footnotes)) pipe_doc$footnotes[[ci]] else NULL
      r6_report$add_page(content = ct, title = title_i, footnote = footnote_i)
    }
  }

  r6_report
}

#' Generate an RTF file from a report object
#'
#' Renders an `rtf_document` (from the pipe API) or `rtfreport_r6` object
#' to an RTF file.
#'
#' @param report An `rtf_document` object (from `rtf_document()`) or an
#'   internal `rtfreport_r6` object.
#' @param file_path Output RTF file path.
#' @param overwrite Logical; whether to overwrite an existing file.
#'   Default `FALSE`.
#'
#' @return Invisibly returns `file_path`.
#' @export
generate_rtfreport <- function(report, file_path, overwrite = FALSE) {
  if (inherits(report, "rtf_document")) {
    report <- .pipe_doc_to_r6_report(report)
    if (is.null(report)) {
      stop("`report` must be an rtf_document or rtfreport_r6 object.", call. = FALSE)
    }
  } else if (!inherits(report, "rtfreport_r6")) {
    stop("`report` must be an rtf_document (from rtf_document()) or rtfreport_r6 object.",
         call. = FALSE)
  }
  if (file.exists(file_path) && !isTRUE(overwrite)) {
    stop("`file_path` already exists. Set overwrite = TRUE.", call. = FALSE)
  }

  report$validate()

  doc           <- report$document
  page_defaults <- doc$default_page
  primary_font  <- doc$font_table[[1]]$name %||% "Courier"
  writable_w    <- page_defaults$width_twips -
                   page_defaults$margin_left_twips -
                   page_defaults$margin_right_twips

  cmds     <- .load_rtf_commands()
  doc_cmd  <- cmds$document
  para_cmd <- cmds$paragraph

  total_pages     <- length(report$pages)
  doc_colors      <- .collect_report_colors(report)
  color_table_str <- .build_color_table_rtf(doc_colors)
  color_index_map <- .build_color_index_map(doc_colors)

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

  # Font-size command used inside {\header} / {\footer} groups.
  # RTF header/footer groups are independent scopes and do NOT inherit the
  # document-level \fs, so the viewer falls back to its built-in default
  # (typically \fs24 = 12 pt).  Prepending the same \fs here keeps the
  # font size consistent with the body text.
  font_half_points <- as.integer(doc$default_format$font_size_half_points %||% 18L)
  fs_cmd           <- paste0("\\fs", font_half_points)

  # Resolve sections (sorted, with from_page / to_page assigned).
  resolved_sections <- .resolve_sections(report)

  prev_header_hf <- NULL
  prev_footer_hf <- NULL

  for (rs_idx in seq_along(resolved_sections)) {
    rs      <- resolved_sections[[rs_idx]]
    pg_from <- rs$from_page
    pg_to   <- rs$to_page

    # Resolve header/footer with inheritance from previous section.
    cur_header_hf <- .normalize_hf(rs$header)
    if (is.null(cur_header_hf)) cur_header_hf <- prev_header_hf
    prev_header_hf <- cur_header_hf

    cur_footer_hf <- .normalize_hf(rs$footer)
    if (is.null(cur_footer_hf)) cur_footer_hf <- prev_footer_hf
    prev_footer_hf <- cur_footer_hf

    lines <- c(lines, doc_cmd$section_defaults)

    # Re-emit section-level page properties after \sectd.
    #
    # \sectd resets all section formatting to RTF built-in defaults, so we must
    # explicitly re-specify:
    #   \sbkpage      – force each section to start on a new page (required for
    #                   per-section headers to work; without it sections are
    #                   "continuous" and share the first section's header).
    #   \lndscpsxn    – landscape orientation (document-level \landscape only
    #                   applies to the first section in many RTF viewers).
    #   \pgwsxn / \pghsxn         – section page dimensions.
    #   \marglsxn / \margrsxn ... – section margins.
    {
      pg     <- page_defaults
      is_lnd <- isTRUE(pg$orientation == "landscape")
      lnd_cmd <- if (is_lnd) "\\lndscpsxn" else ""
      lines <- c(lines, paste0(
        "\\sbkpage", lnd_cmd,
        "\\pgwsxn",   pg$width_twips,
        "\\pghsxn",   pg$height_twips,
        "\\marglsxn", pg$margin_left_twips,
        "\\margrsxn", pg$margin_right_twips,
        "\\margtsxn", pg$margin_top_twips,
        "\\margbsxn", pg$margin_bottom_twips
      ))
    }

    # Emit {\header} and {\footer} once per RTF section.
    header_rtf <- .render_header_footer(cur_header_hf, writable_w, is_footer = FALSE,
                                        current_page = pg_from, total_pages = total_pages,
                                        color_index_map = color_index_map,
                                        font_half_points = font_half_points)
    footer_rtf <- .render_header_footer(cur_footer_hf, writable_w, is_footer = TRUE,
                                        current_page = pg_from, total_pages = total_pages,
                                        color_index_map = color_index_map,
                                        font_half_points = font_half_points)

    if (length(header_rtf) > 0L) {
      lines <- c(lines, .cmd_fmt(doc_cmd$header_wrapper,
                                 list(content = paste0(fs_cmd,
                                        paste(header_rtf, collapse = "")))))
    }
    if (length(footer_rtf) > 0L) {
      lines <- c(lines, .cmd_fmt(doc_cmd$footer_wrapper,
                                 list(content = paste0(fs_cmd,
                                        paste(footer_rtf, collapse = "")))))
    }

    # Render pages belonging to this section.
    sec_pages <- seq(pg_from, pg_to)
    for (sp_idx in seq_along(sec_pages)) {
      p_idx <- sec_pages[sp_idx]
      page  <- report$pages[[p_idx]]

      # ── Content (single rtftable_r6 or rtfplot_r6) ───────────────────────
      ct <- page$content
      content_width <- .compute_content_width(ct, writable_w)

      # ── Title (N×1 table above content; NULL → one {HALF_BLANK_ROW}) ────
      lines <- c(lines, .render_title_table(page$title, content_width, font_half_points))
      if (!is.null(ct)) {
        if (inherits(ct, "rtftable_r6")) {
          lines <- c(lines, .render_rtftable(ct, writable_w, font_half_points))
        } else if (inherits(ct, "rtfplot_r6")) {
          lines <- c(lines, .render_rtfplot(ct, writable_w))
        }
      }

      # ── Footnote (N×1 table, same width as content) ──────────────────────
      if (!is.null(page$footnote) && length(page$footnote) > 0L) {
        lines <- c(lines, .render_footnote_table(page$footnote, content_width, font_half_points))
      }

      # Page break between pages; section break between sections.
      is_last_in_section <- (sp_idx == length(sec_pages))
      is_last_section    <- (rs_idx == length(resolved_sections))
      if (!is_last_in_section) {
        lines <- c(lines, doc_cmd$page_break)
      } else if (!is_last_section) {
        lines <- c(lines, doc_cmd$section_break)
      }
    }
  }

  lines <- c(lines, doc_cmd$document_close)
  writeLines(lines, con = file_path, useBytes = TRUE)
  invisible(file_path)
}
