# ============================================================================
#  format_count_pct() / realign_count_pct()
# ============================================================================
#
#  Clinical TFL cells of the form "n (xx.x)" need consistent display widths
#  so that columns line up in a monospaced renderer.  These two functions
#  produce the same output, from two different starting points:
#
#    format_count_pct(count, pct)
#        - inputs: numeric vectors `count` and `pct`
#        - output: padded "n (xx.x)" strings, equal-width
#
#    realign_count_pct(strings)
#        - inputs: character vector already containing "n (xx.x)" cells
#                  (e.g. extracted from a gt body)
#        - output: same cells re-padded for equal width.  Non-matching
#                  strings are passed through unchanged.
#
#  Width rules (port of the reference helper from Issue #2):
#
#       count = NA or 0           ->  "%3d       "           (10 wide)
#       pct  >= 100               ->  "%3d (%3d) "           (10 wide)
#       0 < pct < 10              ->  "%3d  (%3.1f)"         (10 wide)
#       10 <= pct < 100           ->  "%3d (%4.1f)"          (10 wide)
#
#  Padding spaces are converted to non-breaking spaces (U+00A0) by default
#  so RTF / Word does not collapse them.
# ============================================================================


#' Format count + percent cells to a uniform display width
#'
#' Returns each pair `(count[i], pct[i])` as a padded `"n (xx.x)"`
#' string suitable for monospaced clinical TFL alignment.  The four
#' width branches match the convention in the rtfreporter Issue \#2
#' reference helper.
#'
#' @param count Integer / numeric vector of counts.  `NA` and `0`
#'   produce the count-only branch (no parentheses).
#' @param pct   Numeric vector of percentages.  By default expressed
#'   as a *fraction* in `[0, 1]`; pass `pct_unit = "percent"` if your
#'   values are already in `[0, 100]`.  Recycled against `count` if
#'   one argument is length 1.
#' @param pct_unit Either `"fraction"` (default, `0..1`) or
#'   `"percent"` (`0..100`).
#' @param nbsp Character used to replace the padding spaces.  Default
#'   `" "` (non-breaking space) so RTF / Word does not collapse
#'   leading whitespace.  Pass `" "` (regular space) for plain-text
#'   output.
#'
#' @return Character vector the same length as `count` / `pct`.
#'
#' @examples
#' # Fractions (the default)
#' format_count_pct(c(5L, 14L, 30L), c(0.05, 0.50, 1.00))
#'
#' # Percent values
#' format_count_pct(c(5L, 14L, 30L), c(5, 50, 100), pct_unit = "percent")
#'
#' # Plain spaces if the output is going to plain text rather than RTF
#' format_count_pct(7L, 0.333, nbsp = " ")
#'
#' @seealso [realign_count_pct()] for the same widths starting from
#'   already-formatted strings.
#' @export
format_count_pct <- function(count, pct,
                              pct_unit = c("fraction", "percent"),
                              nbsp     = " ") {
  pct_unit <- match.arg(pct_unit)
  if (!is.numeric(count) || !is.numeric(pct)) {
    stop("`count` and `pct` must both be numeric.", call. = FALSE)
  }
  n_in <- max(length(count), length(pct))
  if (length(count) == 1L) count <- rep(count, n_in)
  if (length(pct)   == 1L) pct   <- rep(pct,   n_in)
  if (length(count) != length(pct)) {
    stop("`count` and `pct` must have the same length (or one of them ",
         "be length 1).", call. = FALSE)
  }
  if (pct_unit == "fraction") pct <- pct * 100

  out <- vapply(seq_len(n_in), function(i) {
    c1 <- count[i]; p <- pct[i]
    if (is.na(c1) || is.na(p) || c1 == 0) {
      raw <- sprintf("%3d       ", as.integer(c1))
    } else if (p >= 100) {
      raw <- sprintf("%3d (%3d) ",   as.integer(c1), round(p))
    } else if (p < 10) {
      raw <- sprintf("%3d  (%3.1f)", as.integer(c1), p)
    } else {
      raw <- sprintf("%3d (%4.1f)",  as.integer(c1), p)
    }
    raw
  }, character(1L))

  if (!identical(nbsp, " ")) out <- gsub(" ", nbsp, out, fixed = TRUE)
  out
}


#' Re-align existing "n (xx.x)" strings to a uniform display width
#'
#' Scans `x` for cells matching the clinical-TFL pattern `"n (xx.x)"`
#' (e.g. `"5 (33.3)"`), parses the count and percent, and reformats
#' them through [format_count_pct()] so every cell is the same width.
#' Cells that do not match are returned unchanged.
#'
#' This is the function `paginate()` invokes internally when
#' `align_count_pct = TRUE` (see [paginate()]).  It is exported so it
#' can be applied directly to a data.frame column outside of any
#' pagination context.
#'
#' @param x Character vector.  Cells that match the regex
#'   `^\\d+ \\(\\d+(\\.\\d+)?\\)$` are reformatted; all others are
#'   returned unchanged.
#' @param nbsp Padding character (see [format_count_pct()]).
#'
#' @return Character vector the same length as `x`.
#'
#' @examples
#' realign_count_pct(c("5 (33.3)", "12 (100.0)", "0 (0.0)",
#'                     "not a count", "1 (5.0)", "1 (50.0)"))
#'
#' @seealso [format_count_pct()] for the numeric → string variant.
#' @export
realign_count_pct <- function(x, nbsp = " ") {
  if (is.null(x) || length(x) == 0L) return(x)
  if (!is.character(x)) x <- as.character(x)
  out <- x
  rx  <- "^\\s*(\\d+)\\s*\\((\\d+(?:\\.\\d+)?)\\)\\s*$"
  m   <- regmatches(x, regexec(rx, x))
  for (i in seq_along(x)) {
    g <- m[[i]]
    if (length(g) == 3L && !is.na(g[1L]) && nzchar(g[1L])) {
      n   <- as.integer(g[2L])
      pct <- as.numeric(g[3L])
      out[i] <- format_count_pct(n, pct, pct_unit = "percent", nbsp = nbsp)
    }
  }
  out
}


# Internal: apply realign_count_pct() to every character column of `df`
# except the first column (which by clinical convention is the row label,
# not a count cell).  Used by paginate(align_count_pct = TRUE).
.realign_count_pct_df <- function(df, nbsp = " ") {
  if (ncol(df) < 2L) return(df)
  df[, -1L] <- lapply(df[, -1L, drop = FALSE], function(col) {
    if (is.character(col)) realign_count_pct(col, nbsp = nbsp) else col
  })
  df
}
