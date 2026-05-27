# ============================================================================
#  Unified column-header API (v0.0.21+)
# ============================================================================
#
#  Multi-row column headers were historically split across two arguments —
#  `col_header` (label rows + nested spanning rows) and `spanning_header`
#  (a single span row placed above col_header).  The split made it awkward
#  to span at the top-most level using `col_header` alone and forced two
#  different cell-spec shapes (`from = / to =` versus a plain character
#  vector).
#
#  This file adds a single unified specification, accepted by
#  `rtftable(col_header = ...)`, in which every cell is described by
#  `pos = ...`:
#
#    pos = 1            single-column cell at data column 1
#    pos = c(2, 5)      cell spanning data columns 2 through 5
#
#  Positions always refer to the underlying **data columns** — not to the
#  positions of cells in the row above.  Cells in a row must not overlap;
#  gaps are filled internally with empty cells so the renderer always
#  sees a fully-covered row.
#
#  Three small public helpers make the API ergonomic:
#
#    col_cell(pos, label, ...)           — one cell
#    rtf_col_header(...)                 — collect rows top-to-bottom
#    add_col_header_row(hdr, row, ...)   — append (or prepend) a row
#
#  Internally a pos-style row is converted to the existing (from, to)
#  spanning-row representation via `.pos_row_to_spans()`, so every
#  renderer path keeps working unchanged.
#
#  Backward compatibility
#  ----------------------
#  Every previously-accepted form continues to work:
#    NULL                              -> use names(data)
#    c("A", "B", "C")                  -> single label row
#    "A | B | C"                       -> single label row
#    list(c("A","B"), c("X","Y"))      -> multi-row labels
#    list(list(list(from=1,to=2,label="X")), c("A","B")) -> spanning + labels
#  The old `spanning_header =` argument is also unchanged.
#  ============================================================================


#' Column-header cell specification
#'
#' Convenience constructor for a single cell in a column-header row passed
#' to [rtftable()] (via `col_header =`) or [rtf_col_header()].
#'
#' Use `pos = 1` for a single-column cell and `pos = c(start, end)` for a
#' cell that spans several data columns.  Positions are always relative to
#' the underlying data columns, not to the previous header row.
#'
#' @param pos Numeric of length 1 (single column) or length 2
#'   (`c(start, end)`, inclusive).  `start <= end` required; values must
#'   be `>= 1`.
#' @param label Character scalar.  Cell text; may be `""`.
#' @param align Optional `"left"`, `"center"`, or `"right"`.  `NULL`
#'   (default) inherits the leftmost covered column's `header_align`.
#' @param bold,italic,underline Logical.  Default `FALSE`.
#'
#' @return A list of class `"rtf_col_cell"`.
#'
#' @examples
#' col_cell(1, "Item")
#' col_cell(c(2, 5), "Treatment", align = "center", underline = TRUE)
#'
#' @export
col_cell <- function(pos, label = "", align = NULL,
                     bold = FALSE, italic = FALSE, underline = FALSE) {
  if (!is.numeric(pos) || !length(pos) %in% c(1L, 2L) || any(is.na(pos))) {
    stop("`pos` must be a numeric of length 1 or 2.", call. = FALSE)
  }
  pos <- as.integer(pos)
  if (any(pos < 1L)) stop("`pos` values must be >= 1.", call. = FALSE)
  if (length(pos) == 2L && pos[1L] > pos[2L]) {
    stop("`pos` start must be <= end.", call. = FALSE)
  }
  if (!is.null(align) && !align %in% c("left", "center", "right")) {
    stop("`align` must be NULL, \"left\", \"center\", or \"right\".",
         call. = FALSE)
  }
  spec <- list(
    pos   = pos,
    label = if (is.null(label)) "" else as.character(label)[1L]
  )
  if (!is.null(align))   spec$align     <- align
  if (isTRUE(bold))      spec$bold      <- TRUE
  if (isTRUE(italic))    spec$italic    <- TRUE
  if (isTRUE(underline)) spec$underline <- TRUE
  structure(spec, class = "rtf_col_cell")
}

#' @export
print.rtf_col_cell <- function(x, ...) {
  pos_str <- if (length(x$pos) == 1L) sprintf("%d", x$pos)
             else sprintf("%d..%d", x$pos[1L], x$pos[2L])
  deco <- c(if (isTRUE(x$bold)) "b", if (isTRUE(x$italic)) "i",
             if (isTRUE(x$underline)) "u")
  align <- if (!is.null(x$align)) sprintf(", align=%s", x$align) else ""
  deco_str <- if (length(deco)) sprintf(" [%s]", paste(deco, collapse = "")) else ""
  cat(sprintf("<col_cell pos=%s label=%s%s%s>\n",
              pos_str, dQuote(x$label, q = FALSE), align, deco_str))
  invisible(x)
}

#' Build a multi-row column-header specification
#'
#' Collects column-header rows, top-to-bottom, into a single object that
#' can be passed to `rtftable(col_header = ...)`.  Each argument is one
#' row; a row may be either:
#'
#' * a character vector — one label per data column (legacy form), or
#' * a list of [col_cell()] objects — for a row with single and/or
#'   spanning cells.
#'
#' @param ... Header rows in render order (top first).
#'
#' @return A list of class `"rtf_col_header"`.
#'
#' @examples
#' \dontrun{
#' rtf_col_header(
#'   list(col_cell(1, ""), col_cell(c(2, 5), "Treatment")),
#'   list(col_cell(1, ""),
#'        col_cell(c(2, 3), "Drug A"),
#'        col_cell(c(4, 5), "Drug B")),
#'   c("Item", "N", "Mean", "N", "Mean")
#' )
#' }
#'
#' @export
rtf_col_header <- function(...) {
  rows <- list(...)
  structure(rows, class = "rtf_col_header")
}

#' @export
print.rtf_col_header <- function(x, ...) {
  cat(sprintf("<rtf_col_header — %d row%s>\n",
              length(x), if (length(x) == 1L) "" else "s"))
  for (i in seq_along(x)) {
    row <- x[[i]]
    if (is.character(row)) {
      cat(sprintf("  [%d] labels: %s\n", i,
                  paste(dQuote(row, q = FALSE), collapse = ", ")))
    } else if (is.list(row)) {
      cells <- vapply(row, function(c) {
        pos <- c$pos %||% c(c$from %||% NA, c$to %||% NA)
        if (length(pos) == 1L || (length(pos) == 2L && pos[1L] == pos[2L])) {
          sprintf("%s@%d", c$label %||% "", pos[1L])
        } else {
          sprintf("%s@%d-%d", c$label %||% "", pos[1L], pos[2L])
        }
      }, character(1L))
      cat(sprintf("  [%d] cells: %s\n", i,
                  paste(cells, collapse = ", ")))
    }
  }
  invisible(x)
}

#' Append (or prepend) a row to an `rtf_col_header`
#'
#' @param hdr An [rtf_col_header()], or any value accepted by
#'   `rtftable(col_header = ...)`.  Non-`rtf_col_header` inputs are
#'   promoted automatically.
#' @param row One header row: a character vector or a list of cell specs.
#' @param .position `"bottom"` (default) appends below the existing rows;
#'   `"top"` prepends above.
#'
#' @return A new `rtf_col_header`.
#'
#' @examples
#' \dontrun{
#' hdr <- rtf_col_header(c("Item", "N", "Mean", "N", "Mean"))   # bottom row
#' hdr <- add_col_header_row(
#'   hdr,
#'   list(col_cell(1, ""),
#'        col_cell(c(2, 3), "Drug A"),
#'        col_cell(c(4, 5), "Drug B")),
#'   .position = "top"
#' )
#' }
#'
#' @export
add_col_header_row <- function(hdr, row,
                                .position = c("bottom", "top")) {
  .position <- match.arg(.position)
  if (!inherits(hdr, "rtf_col_header")) {
    hdr <- rtf_col_header(hdr)
  }
  current <- unclass(hdr)
  result  <- if (.position == "bottom") c(current, list(row))
             else c(list(row), current)
  structure(result, class = "rtf_col_header")
}


# ── Internal helpers ────────────────────────────────────────────────────────

# Is `x` a cell spec — either the new pos form or the legacy from/to form?
.is_cell_spec <- function(x) {
  is.list(x) && length(x) > 0L && (!is.null(x$pos) || !is.null(x$from))
}

# Convert a pos-style row into the (from, to)-spanning representation the
# renderer expects.  Cells are sorted by start position; gaps in coverage
# are filled with empty cells so every data column is covered exactly once.
.pos_row_to_spans <- function(row, ncol_df) {
  if (length(row) == 0L) return(list())

  # Sort cells by start position.
  starts <- vapply(row, function(c) {
    if (is.null(c$pos)) stop("Cell spec missing `pos` field.", call. = FALSE)
    as.integer(c$pos[1L])
  }, integer(1L))
  row <- row[order(starts)]

  result   <- list()
  next_col <- 1L
  for (cell in row) {
    p <- as.integer(cell$pos)
    if (length(p) > 2L) {
      stop("`pos` must be a scalar or a length-2 integer vector.",
           call. = FALSE)
    }
    from <- p[1L]
    to   <- if (length(p) == 1L) p[1L] else p[2L]
    if (from > to) {
      stop(sprintf("`pos` start (%d) must be <= end (%d).", from, to),
           call. = FALSE)
    }
    if (from < 1L || to > ncol_df) {
      stop(sprintf("`pos` %d-%d outside data column range 1..%d.",
                   from, to, ncol_df), call. = FALSE)
    }
    if (from < next_col) {
      stop(sprintf("`pos` %d-%d overlaps the previous cell (which ended at column %d).",
                   from, to, next_col - 1L), call. = FALSE)
    }
    # Fill gap with an empty cell.
    if (from > next_col) {
      result <- c(result, list(list(from = next_col, to = from - 1L,
                                     label = "")))
    }
    # Convert: drop pos, add from / to, keep other fields.
    spec <- list(from = from, to = to)
    for (k in setdiff(names(cell), "pos")) spec[[k]] <- cell[[k]]
    if (is.null(spec$label)) spec$label <- ""
    result   <- c(result, list(spec))
    next_col <- to + 1L
  }
  # Tail gap.
  if (next_col <= ncol_df) {
    result <- c(result, list(list(from = next_col, to = ncol_df, label = "")))
  }
  result
}
