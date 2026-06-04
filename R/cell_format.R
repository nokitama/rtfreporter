# ============================================================================
#  Pluggable cell-format functions
# ============================================================================
#
#  `as_rtftables(cell_format = )` lets you re-format the *body cells* of a
#  table column-by-column just before pagination -- typically to line numbers
#  up in a monospaced clinical layout.
#
#  ---------------------------------------------------------------------------
#  THE CONTRACT (how to write your own format function)
#  ---------------------------------------------------------------------------
#  A cell-format function takes ONE table column and returns the reformatted
#  column:
#
#      function(x, nbsp = "\u00a0") -> character
#
#    * `x`   : a character vector -- the cells of a single column.
#    * value : a character vector of the SAME length as `x`.
#
#  Rules:
#    * Return the same length you were given (one element per row); never drop
#      or add rows.
#    * Cells you do not want to touch (e.g. empty group-label cells, or values
#      that do not match your pattern) must be returned unchanged.
#    * Pad with the non-breaking space `"\u00a0"` (the `nbsp` default), NOT a
#      regular space -- RTF / Word collapse leading and repeated normal spaces,
#      which would undo your alignment.
#    * The function is called once per column (see `cell_format` in
#      [as_rtftables()]); it does not know which column it is, so base any
#      width decisions on `x` alone.
#
#  rtfreporter ships a few ready-made format functions (below).  When none of
#  them fits your data's exact notation, write your own following the rules
#  above and pass it as `cell_format`.
# ============================================================================


#' Right-align the cells of a column to a common width
#'
#' A minimal cell-format function (see *The contract* in the
#' \code{vignette} / [as_rtftables()]): every non-empty cell is right-justified
#' to the width of the widest cell, padding on the left with non-breaking
#' spaces.  Empty cells are left empty.  This is the simplest useful formatter
#' and a good template for writing your own.
#'
#' @param x Character vector (one table column).
#' @param nbsp Padding character; defaults to the non-breaking space
#'   (U+00A0) so RTF / Word keep the alignment.  Pass `" "` for plain text.
#'
#' @return Character vector the same length as `x`.
#'
#' @examples
#' fmt_right_align(c("5", "120", "7"))
#'
#' @seealso [fmt_count_paren()], [realign_count_pct()], and the `cell_format`
#'   argument of [as_rtftables()].
#' @export
fmt_right_align <- function(x, nbsp = "\u00a0") {
  if (length(x) == 0L) return(x)
  x <- as.character(x)
  x[is.na(x)] <- ""
  nz <- nzchar(trimws(x))
  if (!any(nz)) return(x)
  w   <- max(nchar(x[nz]))
  out <- x
  out[nz] <- formatC(x[nz], width = w, flag = "")   # right-justify
  if (!identical(nbsp, " ")) out <- gsub(" ", nbsp, out, fixed = TRUE)
  out
}


#' Align "count (parenthetical)" cells
#'
#' Aligns clinical cells made of an integer **count** optionally followed by a
#' **parenthetical** part -- e.g. `"69 (80.2%)"`, `"3 (<1%)"`, `"70 (100%)"` or
#' a lone `"0"`.  The count is right-justified to the widest count in the
#' column and the parenthetical part is left-justified to the widest one, so
#' the digits and the opening parenthesis line up across rows.  A lone count
#' (such as a zero with no percentage) is aligned in the same count field, so
#' it sits under the other counts instead of drifting out of line.
#'
#' Unlike [realign_count_pct()] this does not care what is *inside* the
#' parentheses, so it copes with mixed notations like `"(<1%)"`, `"(100%)"` and
#' `"( 2.8%)"` in one column (e.g. tables produced by `tfrmt`).  Cells that do
#' not start with an integer are returned unchanged.
#'
#' @inheritParams fmt_right_align
#'
#' @return Character vector the same length as `x`.
#'
#' @examples
#' fmt_count_paren(c("1 (1.2%)", "0", "11 (3.6%)", "108 (35.3%)"))
#'
#' @seealso [fmt_right_align()], [realign_count_pct()], and the `cell_format`
#'   argument of [as_rtftables()].
#' @export
fmt_count_paren <- function(x, nbsp = "\u00a0") {
  if (length(x) == 0L) return(x)
  x <- as.character(x)
  x[is.na(x)] <- ""
  rx <- "^[[:space:]]*([0-9]+)[[:space:]]*(\\(.*\\))?[[:space:]]*$"
  m  <- regmatches(x, regexec(rx, x))
  count <- rep(NA_character_, length(x))
  paren <- rep("", length(x))
  for (i in seq_along(x)) {
    g <- m[[i]]
    if (length(g) == 3L && nzchar(g[2L])) {
      count[i] <- g[2L]
      paren[i] <- g[3L]
    }
  }
  matched <- !is.na(count)
  if (!any(matched)) return(x)
  wc <- max(nchar(count[matched]))         # count field width
  wp <- max(nchar(paren[matched]))         # parenthetical field width (0 if none)
  out <- x
  for (i in which(matched)) {
    cc <- formatC(count[i], width = wc, flag = "")            # right-justify
    if (wp > 0L) {
      pp  <- formatC(paren[i], width = wp, flag = "-")        # left-justify
      out[i] <- paste0(cc, " ", pp)
    } else {
      out[i] <- cc
    }
  }
  if (!identical(nbsp, " ")) out <- gsub(" ", nbsp, out, fixed = TRUE)
  out
}


# Internal: resolve the `cell_format` argument into a per-column list of
# functions (length `ncol`; NULL entries = leave the column untouched).
#
#   * a single function -> applied to columns 2..ncol (column 1 is the row
#     label and is left alone, the usual clinical convention);
#   * a list            -> taken positionally, `cell_format[[j]]` for column j
#     (entries that are not functions are ignored).
.resolve_cell_format <- function(cell_format, ncol) {
  if (is.null(cell_format) || ncol < 1L) return(NULL)
  fl <- vector("list", ncol)
  if (is.function(cell_format)) {
    if (ncol >= 2L) for (j in 2:ncol) fl[[j]] <- cell_format
  } else if (is.list(cell_format)) {
    n <- min(length(cell_format), ncol)
    for (j in seq_len(n)) {
      if (is.function(cell_format[[j]])) fl[[j]] <- cell_format[[j]]
    }
  } else {
    stop("`cell_format` must be a function or a list of functions.",
         call. = FALSE)
  }
  fl
}

# Internal: apply a resolved per-column format list to a data.frame's
# character columns.
.apply_cell_format <- function(df, fl) {
  for (j in seq_along(fl)) {
    f <- fl[[j]]
    if (is.function(f) && j <= ncol(df) && is.character(df[[j]])) {
      formatted <- f(df[[j]])
      if (length(formatted) != nrow(df)) {
        stop(sprintf(paste0("A `cell_format` function must return a vector the ",
                            "same length as the column (got %d, expected %d)."),
                     length(formatted), nrow(df)), call. = FALSE)
      }
      df[[j]] <- as.character(formatted)
    }
  }
  df
}
