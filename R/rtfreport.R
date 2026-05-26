# Internal utility: inches to twips.
.in_to_twips <- function(x) {
  as.integer(round(x * 1440))
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

# Internal utility: normalize a raw content value to rtftable_r6 or rtfplot_r6.
.normalize_content <- function(item) {
  if (is.null(item)) return(NULL)
  if (inherits(item, "rtftable_r6") || inherits(item, "rtfplot_r6")) return(item)
  if (is.data.frame(item)) return(rtftable_r6$new(data = item))
  stop("content must be an rtftable_r6, rtfplot_r6, or data.frame.", call. = FALSE)
}

# ── Internal S3 object constructors ──────────────────────────────────────────

# rtf_page: structured page object stored in rtfreport_r6$pages
#   title    — character vector (multi-line, center)
#   content  — rtftable_r6 | rtfplot_r6 | NULL (exactly 1 per page)
#   footnote — character vector (multi-line, rendered as 1×1 table, left)
.new_page <- function(title = NULL, content = NULL, footnote = NULL) {
  structure(
    list(title = title, content = content, footnote = footnote),
    class = "rtf_page"
  )
}

# rtf_sect: structured section definition stored in rtfreport_r6$sections
#   header    — rtf_header() | named vector | NULL (NULL = inherit from previous)
#   footer    — rtf_footer() | named vector | NULL (NULL = inherit from previous)
#   from_page — integer: first page this section applies to
.new_sect <- function(header = NULL, footer = NULL, from_page = NULL) {
  structure(
    list(header = header, footer = footer, from_page = from_page),
    class = "rtf_sect"
  )
}

# ── Internal helper: update a single row in a header/footer rows list ─────────

.update_hf_rows <- function(hf, row, content) {
  if (!is.list(hf) || is.null(hf$rows)) {
    stop("First argument must be an rtf_header() or rtf_footer() object.", call. = FALSE)
  }
  row <- as.integer(row)
  if (row < 1L) stop("`row` must be >= 1.", call. = FALSE)
  # Normalize to a plain character vector, but preserve names.
  # as.vector() strips names on character vectors in R, so we restore them.
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
#' # Replace row 2
#' hdr <- update_header_row(hdr, row = 2, content = c(l = "Table 14.2.1", r = "Page {AUTO_PAGE}"))
#'
#' # Append row 3
#' hdr <- update_header_row(hdr, row = 3, content = c(c = "Draft - Confidential"))
#'
#' # Add row 5 (row 4 auto-filled with empty center row)
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

# ── rtf_header() / rtf_footer() ──────────────────────────────────────────────

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
#' @param top_border **Deprecated.** Use `border = rtf_border_top()` or
#'   `border = NULL` instead.
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
#' # Add a third row later
#' hdr <- update_header_row(hdr, row = 3, content = c(c = "Draft"))
#'
#' @export
rtf_header <- function(rows,
                        border           = NULL,
                        width_twips      = NULL,
                        row_height_twips = NULL,
                        top_border       = NULL) {
  if (!is.null(top_border)) {
    warning("`top_border` is deprecated in rtf_header(). ",
            "Use `border = rtf_border_top()` or `border = NULL` instead.",
            call. = FALSE)
    if (is.null(border)) border <- if (isTRUE(top_border)) rtf_border_top() else NULL
  }
  if (!is.null(border) && !inherits(border, "rtf_border")) {
    stop("`border` must be NULL or an rtf_border object.", call. = FALSE)
  }
  if (is.character(rows)) rows <- list(rows)
  if (!is.list(rows)) stop("`rows` must be a named character vector or list of named vectors.", call. = FALSE)
  list(rows = rows, border = border, width_twips = width_twips, row_height_twips = row_height_twips)
}

#' @rdname rtf_header
#' @export
rtf_footer <- function(rows,
                        border           = rtf_border_top(),
                        width_twips      = NULL,
                        row_height_twips = NULL,
                        top_border       = NULL) {
  if (!is.null(top_border)) {
    warning("`top_border` is deprecated in rtf_footer(). ",
            "Use `border = rtf_border_top()` or `border = NULL` instead.",
            call. = FALSE)
    if (!missing(border) && identical(border, rtf_border_top())) {
      border <- if (isTRUE(top_border)) rtf_border_top() else NULL
    } else if (missing(border)) {
      border <- if (isTRUE(top_border)) rtf_border_top() else NULL
    }
  }
  if (!is.null(border) && !inherits(border, "rtf_border")) {
    stop("`border` must be NULL or an rtf_border object.", call. = FALSE)
  }
  if (is.character(rows)) rows <- list(rows)
  if (!is.list(rows)) stop("`rows` must be a named character vector or list of named vectors.", call. = FALSE)
  list(rows = rows, border = border, width_twips = width_twips, row_height_twips = row_height_twips)
}

# ============================================================================
# Internal R6 class: rtfreport_r6
# ============================================================================
#
# Structure:
#   document  — font_table, color_table, default_page, default_format
#   pages[]   — list of rtf_page objects: list(title, content, footnote)
#   sections[]— list of rtf_sect objects: list(header, footer, from_page)
#
# Section-to-page mapping (resolved at render time):
#   Sections sorted by from_page. Each section covers pages from its
#   from_page up to (but not including) the next section's from_page.
#   The first section always covers from page 1.
#   If sections is empty, validate() auto-creates one empty default section.

rtfreport_r6 <- R6::R6Class(
  classname = "rtfreport_r6",
  public = list(
    document = NULL,
    pages    = NULL,
    sections = NULL,

    initialize = function(
      font_table     = NULL,
      color_table    = NULL,
      default_page   = NULL,
      default_format = NULL
    ) {
      if (is.null(font_table))  font_table  <- list(list(name = "Courier"))
      if (is.null(color_table)) color_table <- c("#000000")
      if (is.null(default_page)) {
        default_page <- list(
          paper               = "letter",
          orientation         = "landscape",
          width_twips         = .in_to_twips(11),
          height_twips        = .in_to_twips(8.5),
          margin_top_twips    = .in_to_twips(0.75),
          margin_bottom_twips = .in_to_twips(0.75),
          margin_left_twips   = .in_to_twips(0.5),
          margin_right_twips  = .in_to_twips(0.5)
        )
      }
      if (is.null(default_format)) {
        default_format <- list(
          font_index            = 0L,
          font_size_half_points = 18L,
          line_spacing          = 1L
        )
      }
      self$document <- list(
        font_table     = font_table,
        color_table    = color_table,
        default_page   = default_page,
        default_format = default_format
      )
      self$pages    <- list()
      self$sections <- list()
      invisible(self)
    },

    # ── Page methods ──────────────────────────────────────────────────────────

    add_page = function(title = NULL, content = NULL, footnote = NULL) {
      if (!is.null(content)) content <- .normalize_content(content)
      page <- .new_page(title = title, content = content, footnote = footnote)
      self$pages[[length(self$pages) + 1L]] <- page
      invisible(length(self$pages))
    },

    get_page = function(page_index) {
      idx <- .assert_index(page_index, length(self$pages), "page_index")
      self$pages[[idx]]
    },

    set_page_title = function(page_index, title) {
      idx <- .assert_index(page_index, length(self$pages), "page_index")
      self$pages[[idx]]$title <- title
      invisible(self)
    },

    set_page_content = function(page_index, content) {
      idx <- .assert_index(page_index, length(self$pages), "page_index")
      if (!is.null(content)) content <- .normalize_content(content)
      self$pages[[idx]]$content <- content
      invisible(self)
    },

    set_page_footnote = function(page_index, footnote) {
      idx <- .assert_index(page_index, length(self$pages), "page_index")
      self$pages[[idx]]$footnote <- footnote
      invisible(self)
    },

    # ── Section methods ───────────────────────────────────────────────────────

    add_section = function(header = NULL, footer = NULL, from_page = NULL) {
      if (!is.null(from_page)) from_page <- as.integer(from_page)
      sec <- .new_sect(header = header, footer = footer, from_page = from_page)
      self$sections[[length(self$sections) + 1L]] <- sec
      invisible(length(self$sections))
    },

    get_section = function(section_index) {
      idx <- .assert_index(section_index, length(self$sections), "section_index")
      self$sections[[idx]]
    },

    get_section_header = function(section_index) {
      idx <- .assert_index(section_index, length(self$sections), "section_index")
      self$sections[[idx]]$header
    },

    get_section_footer = function(section_index) {
      idx <- .assert_index(section_index, length(self$sections), "section_index")
      self$sections[[idx]]$footer
    },

    set_section_header = function(section_index, header) {
      idx <- .assert_index(section_index, length(self$sections), "section_index")
      self$sections[[idx]]$header <- header
      invisible(self)
    },

    set_section_footer = function(section_index, footer) {
      idx <- .assert_index(section_index, length(self$sections), "section_index")
      self$sections[[idx]]$footer <- footer
      invisible(self)
    },

    set_section_from_page = function(section_index, from_page) {
      idx <- .assert_index(section_index, length(self$sections), "section_index")
      self$sections[[idx]]$from_page <- as.integer(from_page)
      invisible(self)
    },

    # ── Document defaults ──────────────────────────────────────────────────────

    set_document_defaults = function(
      font_table     = NULL,
      color_table    = NULL,
      default_page   = NULL,
      default_format = NULL
    ) {
      if (!is.null(font_table))     self$document$font_table     <- font_table
      if (!is.null(color_table))    self$document$color_table    <- color_table
      if (!is.null(default_page))   self$document$default_page   <- .merge_list(self$document$default_page,   default_page)
      if (!is.null(default_format)) self$document$default_format <- .merge_list(self$document$default_format, default_format)
      invisible(self)
    },

    set_default_page = function(page) {
      self$document$default_page <- .merge_list(self$document$default_page, page)
      invisible(self)
    },

    set_default_format = function(fmt) {
      self$document$default_format <- .merge_list(self$document$default_format, fmt)
      invisible(self)
    },

    set_default_header = function(header) {
      warning("set_default_header() is deprecated.", call. = FALSE)
      invisible(self)
    },

    set_default_footer = function(footer) {
      warning("set_default_footer() is deprecated.", call. = FALSE)
      invisible(self)
    },

    # ── Validation ─────────────────────────────────────────────────────────────

    validate = function() {
      # Auto-create a default empty section if none is defined.
      if (length(self$sections) == 0L) {
        message("No sections defined — creating a default empty section (no header/footer).")
        self$sections[[1L]] <- .new_sect()
      }
      if (length(self$pages) == 0L) {
        stop("rtfreport must contain at least one page.", call. = FALSE)
      }
      for (i in seq_along(self$pages)) {
        ct <- self$pages[[i]]$content
        if (!is.null(ct) && !inherits(ct, "rtftable_r6") && !inherits(ct, "rtfplot_r6")) {
          stop(sprintf("Page %d content must be rtftable_r6, rtfplot_r6, or NULL.", i),
               call. = FALSE)
        }
      }
      invisible(TRUE)
    }
  )
)
