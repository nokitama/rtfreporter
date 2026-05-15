# rtftable: standalone table object for use with rtfreport.
#
# Holds a data.frame plus all table-level formatting metadata.
# Pass an rtftable to report$add_table() instead of a bare data.frame.

# Default TFL-style border specification.
.default_tfl_border <- function() {
  list(
    header    = list(top = "single", bottom = "single",
                     left = "none",  right = "none", width = 15L),
    spanning  = list(top = "none",   bottom = "none",
                     left = "none",  right = "none", width = 15L),
    body      = list(top = "none",   bottom = "none",
                     left = "none",  right = "none", width = 15L),
    first_row = list(),
    last_row  = list(bottom = "single")
  )
}

# Merge a user border spec onto TFL defaults.
# Applies recursively per section (header, spanning, body, first_row, last_row).
.merge_border_spec <- function(user_border) {
  if (is.null(user_border)) return(NULL)
  if (identical(user_border, "tfl")) return(.default_tfl_border())

  defaults <- .default_tfl_border()
  for (section in names(user_border)) {
    if (!is.null(user_border[[section]])) {
      if (is.null(defaults[[section]])) {
        defaults[[section]] <- user_border[[section]]
      } else {
        defaults[[section]] <- .merge_list(defaults[[section]], user_border[[section]])
      }
    }
  }
  defaults
}

# Normalize col_spec: list of per-column lists → internal indexed form.
# Each element: list(col=..., align=..., bold=..., italic=..., underline=...,
#                    indent_twips=..., header_bold=..., header_align=..., header_italic=...)
# Returns a list of length ncol, each element is a list of attributes.
.normalize_col_spec <- function(col_spec, ncol_df, col_names) {
  # Start with per-column defaults.
  result <- lapply(seq_len(ncol_df), function(j) {
    list(
      align         = "left",
      bold          = FALSE,
      italic        = FALSE,
      underline     = FALSE,
      indent_twips  = 0L,
      header_bold   = TRUE,
      header_align  = "center",
      header_italic = FALSE
    )
  })

  if (is.null(col_spec)) return(result)
  if (!is.list(col_spec)) stop("`col_spec` must be a list.", call. = FALSE)

  for (spec in col_spec) {
    if (!is.list(spec) || is.null(spec$col)) {
      stop("Each element of `col_spec` must be a list with a `col` key.", call. = FALSE)
    }
    # Resolve column index.
    col_ref <- spec$col
    if (is.character(col_ref)) {
      idx <- match(col_ref, col_names)
      if (is.na(idx)) stop(sprintf("col_spec col '%s' not found in data.", col_ref), call. = FALSE)
    } else {
      idx <- as.integer(col_ref)
      if (is.na(idx) || idx < 1L || idx > ncol_df) {
        stop(sprintf("col_spec col index %d out of range (1..%d).", idx, ncol_df), call. = FALSE)
      }
    }
    # Merge spec into the column's defaults (skip 'col' key itself).
    for (attr in setdiff(names(spec), "col")) {
      result[[idx]][[attr]] <- spec[[attr]]
    }
  }

  result
}

#' RTF table object
#'
#' `rtftable` holds a `data.frame` together with all table-level formatting
#' metadata.  Pass an `rtftable` to `report$add_table()` to use rich formatting.
#'
#' @param data A `data.frame`.
#' @param col_header Column header specification.  One of:
#'   \itemize{
#'     \item `NULL` – use column names as single header row.
#'     \item A character vector – one element per column.
#'     \item A pipe-delimited string `"A | B | C"`.
#'     \item A `list` of the above for multiple header rows.
#'   }
#' @param spanning_header A list of spanning-header specs, each a list with
#'   `from` (int), `to` (int), `label` (chr), `underline` (logical).
#' @param col_spec A list of per-column formatting specs.  Each element is a
#'   named list with `col` (column index or name) plus any of: `align`,
#'   `bold`, `italic`, `underline`, `indent_twips`, `header_bold`,
#'   `header_align`, `header_italic`.
#' @param border Border specification.  `"tfl"` (default) applies the
#'   Clinical-TFL standard (header top+bottom, last-data-row bottom, no
#'   vertical lines).  `NULL` disables all borders.  A named list partially
#'   overrides the TFL defaults; keys are `header`, `spanning`, `body`,
#'   `first_row`, `last_row`, each a list with sides `top`, `bottom`, `left`,
#'   `right` (border type string) and optional `width` (twips).
#' @param blank_rows Integer vector of positions at which to insert a blank
#'   separator row in the **data** section.  `0` inserts one before the first
#'   data row; `k` inserts one after data row `k`.  Multiple positions can be
#'   specified, e.g. `c(0, 5, 10)`.
#' @param col_rel_width Numeric vector of relative column widths (e.g.
#'   `c(3, 1, 1)` distributes 3:1:1).  Ignored when `column_widths_twips` is
#'   set.
#' @param column_widths_twips Integer vector of absolute column widths in
#'   twips.  Takes precedence over `col_rel_width`.
#' @param table_width_twips Total table width in twips.  Used with
#'   `col_rel_width` when `column_widths_twips` is not set.
#' @param table_width_pct_of_writable Table width as a fraction of the
#'   writable page width (0–1).
#' @param row_height_twips Row height in twips for data rows.  `0` (default) =
#'   automatic.  Always specify a positive value; use `row_height_exact = TRUE`
#'   to make it an exact (fixed) height instead of a minimum height.
#' @param row_height_exact Logical.  `FALSE` (default) = `row_height_twips` is
#'   a **minimum** height (`\trrh` positive; rows expand if content is taller).
#'   `TRUE` = **exact** height (`\trrh` negative; content is clipped if taller).
#'   Applies to data rows, header rows, and blank rows alike.
#' @param header_row_height_twips Row height for header/spanning rows.
#'   `NULL` uses `row_height_twips`.
#' @param blank_row_height_twips Height of blank separator rows in twips.
#'   `NULL` (default) uses the same height as `row_height_twips`.
#' @param cell_padding_left_twips Left cell margin in twips (default 72 = 0.05").
#' @param cell_padding_right_twips Right cell margin in twips (default 72).
#' @param cell_valign Vertical cell alignment: `"bottom"` (default), `"top"`,
#'   or `"center"`.
#'
#' @export
rtftable <- R6::R6Class(
  classname = "rtftable",
  public = list(
    data = NULL,
    col_header = NULL,
    spanning_header = NULL,
    col_spec = NULL,
    border = NULL,
    blank_rows = NULL,
    col_rel_width = NULL,
    column_widths_twips = NULL,
    table_width_twips = NULL,
    table_width_pct_of_writable = NULL,
    row_height_twips = NULL,
    row_height_exact = NULL,
    header_row_height_twips = NULL,
    blank_row_height_twips = NULL,
    cell_padding_left_twips = NULL,
    cell_padding_right_twips = NULL,
    cell_valign = NULL,

    initialize = function(
      data,
      col_header = NULL,
      spanning_header = NULL,
      col_spec = NULL,
      border = "tfl",
      blank_rows = NULL,
      col_rel_width = NULL,
      column_widths_twips = NULL,
      table_width_twips = NULL,
      table_width_pct_of_writable = NULL,
      row_height_twips = 0L,
      row_height_exact = FALSE,
      header_row_height_twips = NULL,
      blank_row_height_twips = NULL,
      cell_padding_left_twips = 72L,
      cell_padding_right_twips = 72L,
      cell_valign = "bottom"
    ) {
      if (!is.data.frame(data)) stop("`data` must be a data.frame.", call. = FALSE)
      self$data <- data

      # Normalize col_header to a list of character vectors.
      if (!is.null(col_header)) {
        if (is.character(col_header) && length(col_header) == 1L &&
            grepl("|", col_header, fixed = TRUE)) {
          col_header <- trimws(strsplit(col_header, "|", fixed = TRUE)[[1]])
        }
        if (is.character(col_header)) col_header <- list(col_header)
        self$col_header <- col_header
      }

      self$spanning_header <- spanning_header
      self$col_spec <- .normalize_col_spec(col_spec, ncol(data), names(data))

      # Border: "tfl" → defaults, NULL → none, list → partial override.
      if (identical(border, "tfl")) {
        self$border <- .default_tfl_border()
      } else if (is.null(border)) {
        self$border <- NULL
      } else if (is.list(border)) {
        self$border <- .merge_border_spec(border)
      } else {
        stop("`border` must be \"tfl\", NULL, or a list.", call. = FALSE)
      }

      # Validate blank_rows.
      if (!is.null(blank_rows)) {
        blank_rows <- as.integer(blank_rows)
        if (any(is.na(blank_rows)) || any(blank_rows < 0L)) {
          stop("`blank_rows` must be non-negative integers.", call. = FALSE)
        }
        self$blank_rows <- sort(unique(blank_rows))
      }

      self$col_rel_width <- col_rel_width
      if (!is.null(column_widths_twips)) {
        self$column_widths_twips <- as.integer(column_widths_twips)
      }
      self$table_width_twips <- table_width_twips
      self$table_width_pct_of_writable <- table_width_pct_of_writable
      self$row_height_twips <- as.integer(row_height_twips)
      if (!is.logical(row_height_exact) || length(row_height_exact) != 1L) {
        stop("`row_height_exact` must be TRUE or FALSE.", call. = FALSE)
      }
      self$row_height_exact <- row_height_exact
      self$header_row_height_twips <- if (!is.null(header_row_height_twips))
        as.integer(header_row_height_twips) else NULL
      self$blank_row_height_twips <- if (!is.null(blank_row_height_twips))
        as.integer(blank_row_height_twips) else NULL
      self$cell_padding_left_twips  <- as.integer(cell_padding_left_twips)
      self$cell_padding_right_twips <- as.integer(cell_padding_right_twips)
      if (!cell_valign %in% c("top", "center", "bottom")) {
        stop("`cell_valign` must be 'top', 'center', or 'bottom'.", call. = FALSE)
      }
      self$cell_valign <- cell_valign

      invisible(self)
    }
  )
)
