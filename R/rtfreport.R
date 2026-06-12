# Internal utility: inches to twips.
.in_to_twips <- function(x) {
  as.integer(round(x * 1440))
}

# Make page dimensions agree with the page orientation, so the RTF orientation
# flag and the paper dimensions never contradict each other.
#
#   * orientation = "landscape" -> width is the LONG side, height the short one.
#   * orientation = "portrait"  -> width is the short side, height the long one.
#   * orientation = NULL        -> inferred from the dimensions
#                                  (width >= height => landscape, else portrait).
#
# Returns list(orientation, width_twips, height_twips).
.orient_page <- function(width_twips, height_twips, orientation = NULL) {
  width_twips  <- as.integer(width_twips)
  height_twips <- as.integer(height_twips)
  long  <- max(width_twips, height_twips)
  short <- min(width_twips, height_twips)
  if (is.null(orientation)) {
    orientation <- if (width_twips >= height_twips) "landscape" else "portrait"
    return(list(orientation = orientation,
                width_twips = width_twips, height_twips = height_twips))
  }
  if (!orientation %in% c("landscape", "portrait")) {
    stop("`orientation` must be \"landscape\" or \"portrait\".", call. = FALSE)
  }
  if (orientation == "landscape") {
    list(orientation = "landscape", width_twips = long,  height_twips = short)
  } else {
    list(orientation = "portrait",  width_twips = short, height_twips = long)
  }
}

# Internal utility: merge two named lists (override wins).
.merge_list <- function(base, override) {
  if (is.null(override)) return(base)
  out <- base
  for (nm in names(override)) out[[nm]] <- override[[nm]]
  out
}

# Internal utility: validate positive integer-like index.
.assert_index <- function(x, max_value, label) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || x < 1L || x > max_value) {
    stop(sprintf("%s is out of range.", label), call. = FALSE)
  }
  as.integer(x)
}

# Internal utility: normalize a raw content value to rtftable or rtfplot.
.normalize_content <- function(item) {
  if (is.null(item)) return(NULL)
  if (inherits(item, "rtftable") || inherits(item, "rtfplot")) return(item)
  if (is.data.frame(item)) return(rtftable(data = item))
  stop("content must be an rtftable, rtfplot, or data.frame.", call. = FALSE)
}

# -- Internal S3 object constructors ------------------------------------------

# rtf_page: structured page object stored in rtfreport$pages
#   title    -- character vector (multi-line, center)
#   content  -- rtftable | rtfplot | NULL (exactly 1 per page)
#   footnote -- character vector (multi-line, rendered as left-aligned paragraphs)
.new_page <- function(title = NULL, content = NULL, footnote = NULL) {
  structure(
    list(title = title, content = content, footnote = footnote),
    class = "rtf_page"
  )
}

# rtf_sect: structured section definition stored in rtfreport$sections
#   header    -- rtf_header() | named vector | NULL (NULL = inherit from previous)
#   footer    -- rtf_footer() | named vector | NULL (NULL = inherit from previous)
#   from_page -- integer: first page this section applies to
.new_sect <- function(header = NULL, footer = NULL, from_page = NULL) {
  structure(
    list(header = header, footer = footer, from_page = from_page),
    class = "rtf_sect"
  )
}

# -- Internal helper: update a single row in a header/footer rows list ---------

.update_hf_rows <- function(hf, row, content) {
  if (!is.list(hf) || is.null(hf$rows)) {
    stop("First argument must be an rtf_header() or rtf_footer() object.", call. = FALSE)
  }
  row <- as.integer(row)
  if (row < 1L) stop("`row` must be >= 1.", call. = FALSE)
  # Normalize to a plain character vector, but preserve names.
  if (is.character(content) && !is.list(content)) {
    nm      <- names(content)
    content <- as.vector(content)
    if (length(nm)) names(content) <- nm
  }

  current_rows <- hf$rows
  n_current    <- length(current_rows)

  if (row > n_current) {
    # Fill gap with empty center rows, then append content at target row.
    n_gap <- row - n_current - 1L
    if (n_gap > 0L) {
      gap <- replicate(n_gap, c(c = ""), simplify = FALSE)
      current_rows <- c(current_rows, gap)
    }
    current_rows <- c(current_rows, list(content))
  } else {
    # Replace existing row.
    current_rows[[row]] <- content
  }

  hf$rows <- current_rows
  hf
}

#' Update a specific row in an `rtf_header()` object
#'
#' Adds a new row or replaces an existing row in a header/footer object.
#' If `row` is beyond the current number of rows, intermediate rows are
#' auto-filled with empty center-aligned rows (`c(c = "")`).
#'
#' @param header An `rtf_header()` object (returned by `rtf_header()`).
#' @param row Integer. Target row number (1-based).
#' @param content A named character vector for the row (e.g.
#'   `c(l = "Left", r = "Right")`). See `rtf_header()` for column rules.
#'
#' @return A modified `rtf_header()` object.
#'
#' @examples
#' hdr <- rtf_header(rows = list(
#'   c(l = "Protocol: XXX-001", r = "Company"),
#'   c(l = "Table 14.1.1",     r = "Page {AUTO_PAGE} of {AUTO_TOTAL_PAGES}")
#' ))
#'
#' hdr <- update_header_row(hdr, row = 2, content = c(l = "Table 14.2.1", r = "Page {AUTO_PAGE}"))
#' hdr <- update_header_row(hdr, row = 3, content = c(c = "Draft - Confidential"))
#' hdr <- update_header_row(hdr, row = 5, content = c(l = "Run date: 2026-01-01"))
#'
#' @export
update_header_row <- function(header, row, content) {
  .update_hf_rows(header, row, content)
}

#' @rdname update_header_row
#' @param footer An `rtf_footer()` object (returned by `rtf_footer()`).
#' @export
update_footer_row <- function(footer, row, content) {
  .update_hf_rows(footer, row, content)
}

# -- rtf_header() / rtf_footer() ----------------------------------------------

#' Create a header or footer object for a section
#'
#' `rtf_header()` and `rtf_footer()` create structured header/footer objects
#' that can be passed to `rtf_section()`. Use [update_header_row()] /
#' [update_footer_row()] to add or replace individual rows after creation.
#'
#' @param rows A named character vector (single row) or a `list` of named
#'   character vectors (multi-row). Each vector uses names `l`, `c`, `r` for
#'   left, center, right column content.
#' @param border An [rtf_border()] object controlling the border applied to
#'   all rows of the header/footer table. `NULL` = no border (default for
#'   header). Use [rtf_border_top()] for a horizontal dividing line (default
#'   for footer).
#' @param width_twips Integer. Table width in twips. `NULL` (default) uses the
#'   full writable width (page width minus margins).
#' @param row_height_twips Integer. Row height in twips. `NULL` (default) reads
#'   the value from `inst/resources/rtfreporter_defaults.R`.
#' @param cell_padding_left_twips,cell_padding_right_twips Integer cell padding
#'   on the left / right side of each header (or footer) cell, matching the
#'   content-table convention. `NULL` (default) reads from
#'   `inst/resources/rtfreporter_defaults.R` (0L for both since v0.0.21).
#'
#' @return A named list with elements `rows`, `border`, `width_twips`, and
#'   `row_height_twips`.
#'
#' @examples
#' hdr <- rtf_header(
#'   rows = list(
#'     c(l = "Protocol: RTF-101", r = "ACME Pharma"),
#'     c(l = "Table 14.1.1",     r = "Page {AUTO_PAGE} of {AUTO_TOTAL_PAGES}")
#'   )
#' )
#' ftr <- rtf_footer(c(l = "Confidential"))
#'
#' hdr <- update_header_row(hdr, row = 3, content = c(c = "Draft"))
#'
#' @export
rtf_header <- function(rows,
                        border                   = NULL,
                        width_twips              = NULL,
                        row_height_twips         = NULL,
                        cell_padding_left_twips  = NULL,
                        cell_padding_right_twips = NULL) {
  if (!is.null(border) && !inherits(border, "rtf_border")) {
    stop("`border` must be NULL or an rtf_border object.", call. = FALSE)
  }
  if (is.character(rows)) rows <- list(rows)
  if (!is.list(rows)) stop("`rows` must be a named character vector or list of named vectors.", call. = FALSE)
  list(rows = rows, border = border, width_twips = width_twips,
       row_height_twips         = row_height_twips,
       cell_padding_left_twips  = cell_padding_left_twips,
       cell_padding_right_twips = cell_padding_right_twips)
}

#' @rdname rtf_header
#' @export
rtf_footer <- function(rows,
                        border                   = rtf_border_top(),
                        width_twips              = NULL,
                        row_height_twips         = NULL,
                        cell_padding_left_twips  = NULL,
                        cell_padding_right_twips = NULL) {
  if (!is.null(border) && !inherits(border, "rtf_border")) {
    stop("`border` must be NULL or an rtf_border object.", call. = FALSE)
  }
  if (is.character(rows)) rows <- list(rows)
  if (!is.list(rows)) stop("`rows` must be a named character vector or list of named vectors.", call. = FALSE)
  list(rows = rows, border = border, width_twips = width_twips,
       row_height_twips         = row_height_twips,
       cell_padding_left_twips  = cell_padding_left_twips,
       cell_padding_right_twips = cell_padding_right_twips)
}

# ============================================================================
# Internal S3 type: rtfreport
# ============================================================================
#
# Structure:
#   document  -- font_table, color_table, default_page, default_format
#   pages[]   -- list of rtf_page objects: list(title, content, footnote)
#   sections[]-- list of rtf_sect objects: list(header, footer, from_page)
#
# Section-to-page mapping (resolved at render time):
#   Sections sorted by from_page. Each section covers pages from its
#   from_page up to (but not including) the next section's from_page.
#   The first section always covers from page 1.
#   If sections is empty, .rtfreport_validate() auto-creates one empty
#   default section.

# Constructor: build a fresh rtfreport with default document settings.
.new_rtfreport <- function(font_table     = NULL,
                           color_table    = NULL,
                           default_page   = NULL,
                           default_format = NULL) {
  if (is.null(font_table))  font_table  <- list(list(name = "Courier"))
  if (is.null(color_table)) color_table <- c("#000000")
  if (is.null(default_page)) {
    default_page <- list(
      paper               = "letter",
      orientation         = "landscape",
      width_twips         = .in_to_twips(11),
      height_twips        = .in_to_twips(8.5),
      margin_top_twips    = .in_to_twips(0.9),
      margin_bottom_twips = .in_to_twips(0.9),
      margin_left_twips   = .in_to_twips(0.6),
      margin_right_twips  = .in_to_twips(0.6)
    )
  }
  if (is.null(default_format)) {
    default_format <- list(
      font_index            = 0L,
      font_size_half_points = 18L,
      line_spacing          = 1L
    )
  }
  structure(
    list(
      document = list(
        font_table     = font_table,
        color_table    = color_table,
        default_page   = default_page,
        default_format = default_format
      ),
      pages    = list(),
      sections = list()
    ),
    class = "rtfreport"
  )
}

# -- Document defaults -------------------------------------------------------

.rtfreport_set_default_page <- function(report, page) {
  report$document$default_page <- .merge_list(report$document$default_page, page)
  report
}

.rtfreport_set_default_format <- function(report, fmt) {
  report$document$default_format <- .merge_list(report$document$default_format, fmt)
  report
}

.rtfreport_set_font_table <- function(report, font_table) {
  report$document$font_table <- font_table
  report
}

.rtfreport_set_color_table <- function(report, color_table) {
  report$document$color_table <- color_table
  report
}

# -- Page ops ----------------------------------------------------------------

.rtfreport_add_page <- function(report, title = NULL, content = NULL, footnote = NULL) {
  if (!is.null(content)) content <- .normalize_content(content)
  page <- .new_page(title = title, content = content, footnote = footnote)
  report$pages[[length(report$pages) + 1L]] <- page
  report
}

# -- Section ops -------------------------------------------------------------

.rtfreport_add_section <- function(report, header = NULL, footer = NULL,
                                    from_page = NULL) {
  if (!is.null(from_page)) from_page <- as.integer(from_page)
  sec <- .new_sect(header = header, footer = footer, from_page = from_page)
  report$sections[[length(report$sections) + 1L]] <- sec
  report
}

# -- Validation --------------------------------------------------------------

.rtfreport_validate <- function(report) {
  # Auto-create a default empty section if none is defined.
  if (length(report$sections) == 0L) {
    message("No sections defined -- creating a default empty section (no header/footer).")
    report$sections[[1L]] <- .new_sect()
  }
  if (length(report$pages) == 0L) {
    stop("rtfreport must contain at least one page.", call. = FALSE)
  }
  for (i in seq_along(report$pages)) {
    ct <- report$pages[[i]]$content
    if (!is.null(ct) && !inherits(ct, "rtftable") && !inherits(ct, "rtfplot")) {
      stop(sprintf("Page %d content must be rtftable, rtfplot, or NULL.", i),
           call. = FALSE)
    }
  }
  report
}
