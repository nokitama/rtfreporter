# rtftable: standalone table object for use with rtfreport.
#
# Holds one or more data.frames plus all table-level formatting metadata.
# Pass an rtftable to report$add_table() instead of a bare data.frame.

# Normalize a border specification to rtf_table_border.
# Accepts: rtf_table_border (returned as-is), "tfl" string (→ rtf_border_tfl()),
# NULL (→ NULL), or old plain nested list (→ .plain_list_to_table_border()).
.normalize_table_border <- function(border) {
  if (is.null(border)) return(NULL)
  if (inherits(border, "rtf_table_border")) return(border)
  if (identical(border, "tfl")) return(rtf_border_tfl())
  if (is.list(border)) return(.plain_list_to_table_border(border))
  stop("`border` must be \"tfl\", NULL, an rtf_table_border object, or a named list.",
       call. = FALSE)
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

# Normalize a single col_header spec to a list of character vectors (one per row).
# Accepts: NULL | pipe string | char vector | list of char vectors.
.normalize_single_col_header <- function(col_header) {
  if (is.null(col_header)) return(NULL)
  if (is.character(col_header) && length(col_header) == 1L &&
      grepl("|", col_header, fixed = TRUE)) {
    col_header <- trimws(strsplit(col_header, "|", fixed = TRUE)[[1]])
  }
  if (is.character(col_header)) return(list(col_header))
  if (is.list(col_header)) return(col_header)
  stop("Invalid col_header specification.", call. = FALSE)
}

# Normalize col_header for multi-DF mode.
# Returns a list of length n_dfs, each element is a normalized col_header
# (NULL or list of char vectors).
#
# Detection rule:
#   - NULL                                 → replicate NULL n_dfs times
#   - char scalar / char vector            → shared header, replicate n_dfs times
#   - list of length n_dfs whose elements
#     are each NULL / char / list-of-char  → per-DF headers (one per DF)
#   - other list                           → shared multi-row header, replicate n_dfs times
.normalize_multi_col_header <- function(col_header, n_dfs) {
  if (is.null(col_header)) return(rep(list(NULL), n_dfs))

  # Plain character (scalar or vector) → shared single header for all DFs.
  if (is.character(col_header)) {
    h <- .normalize_single_col_header(col_header)
    return(rep(list(h), n_dfs))
  }

  if (!is.list(col_header)) {
    stop("`col_header` must be NULL, a character vector, or a list.", call. = FALSE)
  }

  # List: check if it qualifies as N per-DF specs.
  .is_header_spec <- function(x) {
    is.null(x) || is.character(x) || (is.list(x) && all(vapply(x, is.character, logical(1L))))
  }
  if (length(col_header) == n_dfs && all(vapply(col_header, .is_header_spec, logical(1L)))) {
    # Treat as N per-DF header specs.
    return(lapply(col_header, .normalize_single_col_header))
  }

  # Otherwise treat as shared multi-row header, replicate n_dfs times.
  h <- lapply(col_header, function(row) {
    if (!is.character(row)) stop("Each row in a multi-row col_header must be a character vector.", call. = FALSE)
    row
  })
  rep(list(h), n_dfs)
}


#' RTF table object
#'
#' `rtftable` holds one or more `data.frame`s together with all table-level
#' formatting metadata.  Pass an `rtftable` to `report$add_table()` to use
#' rich formatting.
#'
#' @param data A `data.frame`, **or a list of `data.frame`s** with identical
#'   column count.  When a list is supplied every data.frame is rendered
#'   consecutively, each preceded by its own column-header row(s).
#' @param col_header Column header specification.  One of:
#'   \itemize{
#'     \item `NULL` – use column names as single header row.
#'     \item A character vector – one element per column.
#'     \item A pipe-delimited string `"A | B | C"`.
#'     \item A `list` of the above for multiple header rows (shared across all
#'       data.frames).
#'     \item When `data` is a list of N data.frames: a list of exactly N header
#'       specs (one per data.frame).
#'   }
#' @param spanning_header A list of spanning-header specs, each a list with
#'   `from` (int), `to` (int), `label` (chr), `underline` (logical).
#'   When `data` is a list, the spanning header is repeated before each
#'   data.frame.
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
#'   specified, e.g. `c(0, 5, 10)`.  When `data` is a list, `blank_rows`
#'   applies independently to each data.frame.
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
#' Internal R6 class for table objects
#' (S3 wrapper rtftable() is the public API)
rtftable_r6 <- R6::R6Class(
  classname = "rtftable_r6",
  public = list(
    data = NULL,
    data_list = NULL,
    col_header = NULL,
    col_header_list = NULL,
    spanning_header = NULL,
    col_spec = NULL,
    border = NULL,
    blank_rows = NULL,
    col_rel_width = NULL,
    column_widths_twips = NULL,
    table_width_twips = NULL,
    table_width_pct_of_writable = NULL,
    table_align = NULL,
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
      table_width_pct = NULL,
      table_align = "left",
      row_height_twips = 0L,
      row_height_exact = FALSE,
      header_row_height_twips = NULL,
      blank_row_height_twips = NULL,
      cell_padding_left_twips = 72L,
      cell_padding_right_twips = 72L,
      cell_valign = "bottom"
    ) {
      if (is.data.frame(data)) {
        # ── Single data.frame mode ────────────────────────────────────────────
        self$data      <- data
        self$data_list <- NULL

        # Normalize col_header to a list of character vectors.
        if (!is.null(col_header)) {
          if (is.character(col_header) && length(col_header) == 1L &&
              grepl("|", col_header, fixed = TRUE)) {
            col_header <- trimws(strsplit(col_header, "|", fixed = TRUE)[[1]])
          }
          if (is.character(col_header)) col_header <- list(col_header)
          self$col_header <- col_header
        }
        self$col_header_list <- NULL

        self$col_spec <- .normalize_col_spec(col_spec, ncol(data), names(data))

      } else if (is.list(data) && length(data) > 0L) {
        # ── Multi data.frame mode ─────────────────────────────────────────────
        for (i in seq_along(data)) {
          if (!is.data.frame(data[[i]])) {
            stop(sprintf("`data[[%d]]` must be a data.frame.", i), call. = FALSE)
          }
        }
        ncols_all <- vapply(data, ncol, integer(1L))
        if (length(unique(ncols_all)) > 1L) {
          stop("All data.frames in `data` must have the same number of columns.",
               call. = FALSE)
        }
        self$data      <- NULL
        self$data_list <- data

        # Normalize col_header → col_header_list (one per DF).
        self$col_header      <- NULL
        self$col_header_list <- .normalize_multi_col_header(col_header, length(data))

        # col_spec uses first DF's column structure (ncol and names).
        ref_ncol  <- ncols_all[1L]
        ref_names <- names(data[[1L]])
        self$col_spec <- .normalize_col_spec(col_spec, ref_ncol, ref_names)

      } else {
        stop("`data` must be a data.frame or a non-empty list of data.frames.",
             call. = FALSE)
      }

      self$spanning_header <- spanning_header

      # Border: normalize to rtf_table_border (or NULL for no borders).
      self$border <- .normalize_table_border(border)

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
      # table_width_pct (0-100) takes precedence over table_width_pct_of_writable (0-1).
      if (!is.null(table_width_pct)) {
        pct <- as.numeric(table_width_pct)
        if (is.na(pct) || pct <= 0 || pct > 100) {
          stop("`table_width_pct` must be a number in (0, 100].", call. = FALSE)
        }
        self$table_width_pct_of_writable <- pct / 100
      } else {
        self$table_width_pct_of_writable <- table_width_pct_of_writable
      }
      if (!table_align %in% c("left", "center", "right")) {
        stop("`table_align` must be 'left', 'center', or 'right'.", call. = FALSE)
      }
      self$table_align <- table_align
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
