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
#  Width rules -- every branch produces a 10-character string, and the
#  closing parenthesis lands at column 10 so it lines up across rows:
#
#       count = NA or 0           ->  "%3d       "           (no paren)
#       pct  >= 100               ->  "%3d  (%3d)"           e.g. " 30  (100)"
#       0 < pct < 10              ->  "%3d  (%3.1f)"         e.g. "  5  (5.0)"
#       10 <= pct < 100           ->  "%3d (%4.1f)"          e.g. " 14 (50.0)"
#
#  Padding spaces are converted to non-breaking spaces (U+00A0) by default
#  so RTF / Word does not collapse them.
# ============================================================================


#' Format count + percent cells to a uniform display width
#'
#' Returns each pair `(count[i], pct[i])` as a padded `"n (xx.x)"`
#' string suitable for monospaced clinical TFL alignment.  The four
#' width branches match the convention in the rtfreporter Issue #2
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
#'   is the non-breaking space (Unicode code point U+00A0) so that RTF
#'   and Word do not collapse leading whitespace.  Pass `" "` (regular
#'   space) for plain-text output.
#' @param pct_sign Logical (default `FALSE`).  When `TRUE`, a literal
#'   `%` is placed before the closing parenthesis (e.g. `" 14 (50.0%)"`)
#'   and every branch is one character wider so the `)` still aligns.
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
                              nbsp     = "\u00a0",
                              pct_sign = FALSE) {
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

  # When pct_sign = TRUE a "%" is added before the closing paren and every
  # branch is one character wider, so the ")" still aligns across cells.
  out <- vapply(seq_len(n_in), function(i) {
    c1 <- count[i]; p <- pct[i]
    if (is.na(c1) || is.na(p) || c1 == 0) {
      raw <- if (pct_sign) sprintf("%3d        ", as.integer(c1))
             else          sprintf("%3d       ",  as.integer(c1))
    } else if (p >= 100) {
      # Two spaces before '(' so the ')' aligns with the other
      # paren-bearing branches.
      raw <- if (pct_sign) sprintf("%3d  (%3d%%)", as.integer(c1), round(p))
             else          sprintf("%3d  (%3d)",   as.integer(c1), round(p))
    } else if (p < 10) {
      raw <- if (pct_sign) sprintf("%3d  (%3.1f%%)", as.integer(c1), p)
             else          sprintf("%3d  (%3.1f)",   as.integer(c1), p)
    } else {
      raw <- if (pct_sign) sprintf("%3d (%4.1f%%)", as.integer(c1), p)
             else          sprintf("%3d (%4.1f)",   as.integer(c1), p)
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
#' @seealso [format_count_pct()] for the numeric -> string variant.
#' @export
realign_count_pct <- function(x, nbsp = "\u00a0") {
  if (is.null(x) || length(x) == 0L) return(x)
  if (!is.character(x)) x <- as.character(x)
  out <- x
  # Optional trailing "%" inside the parens is captured so that cells like
  # "8 (28.6%)" (e.g. from tern::count_occurrences) are realigned WITH the
  # "%" preserved.  Cells without "%" keep the original "n (xx.x)" form.
  rx  <- "^\\s*(\\d+)\\s*\\((\\d+(?:\\.\\d+)?)(%?)\\)\\s*$"
  m   <- regmatches(x, regexec(rx, x))
  for (i in seq_along(x)) {
    g <- m[[i]]
    if (length(g) == 4L && !is.na(g[1L]) && nzchar(g[1L])) {
      n        <- as.integer(g[2L])
      pct      <- as.numeric(g[3L])
      pct_sign <- nzchar(g[4L])
      out[i] <- format_count_pct(n, pct, pct_unit = "percent",
                                 nbsp = nbsp, pct_sign = pct_sign)
    }
  }
  out
}


# Internal: apply realign_count_pct() to every character column of `df`
# except the first column (which by clinical convention is the row label,
# not a count cell).  Used by paginate(align_count_pct = TRUE).
#
# After re-padding the "n (xx.x[%])" cells, bare-integer cells in the same
# column (e.g. a lone "0" collapsed from "0 (0.0)") are right-padded to the
# column's display width too, so they line up with the count-percent cells
# instead of sitting flush-left.
#
# This padding is applied ONLY when the column actually contains count-percent
# (parenthesised) cells.  A column that is purely integers -- e.g. a plain "n"
# count column with no "n (xx.x)" cells -- is a different kind of data and must
# pass through untouched; padding it would wrongly insert leading spaces before
# values such as "3" (see issue #80).  Empty cells (group-label rows) are left
# empty.
.realign_count_pct_df <- function(df, nbsp = "\u00a0") {
  if (ncol(df) < 2L) return(df)
  df[, -1L] <- lapply(df[, -1L, drop = FALSE], function(col) {
    if (!is.character(col)) return(col)
    col <- realign_count_pct(col, nbsp = nbsp)
    has_paren <- grepl("(", col, fixed = TRUE)         # a count-percent cell
    is_int    <- grepl("^\\s*\\d+\\s*$", col)          # a lone count, no paren
    # Only align bare integers against count-percent cells when the column
    # genuinely mixes the two; never reformat an integer-only column.
    if (any(has_paren) && any(is_int)) {
      width <- max(nchar(col[nzchar(trimws(col))]), 0L)
      pad   <- if (identical(nbsp, " ")) " " else nbsp
      col[is_int] <- vapply(col[is_int], function(x) {
        x <- trimws(x)
        paste0(strrep(pad, max(width - nchar(x), 0L)), x)
      }, character(1L))
    }
    col
  })
  df
}
