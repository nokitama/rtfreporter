# Pluggable cell-format functions: fmt_right_align(), fmt_count_paren(),
# and the as_rtftables(cell_format = ) wiring.

NBSP <- intToUtf8(160L)
unbsp <- function(x) gsub(NBSP, " ", x, fixed = TRUE)   # nbsp -> space for asserts

test_that("fmt_right_align right-justifies non-empty cells, leaves blanks", {
  out <- fmt_right_align(c("5", "120", "7", ""))
  expect_identical(unbsp(out), c("  5", "120", "  7", ""))
  expect_length(out, 4L)
})

test_that("fmt_count_paren aligns counts and parentheticals, incl. a lone 0", {
  out <- unbsp(fmt_count_paren(c("1 (1.2%)", "0", "11 (3.6%)", "108 (35.3%)")))
  # counts right-justified in a 3-wide field; lone 0 sits in the same field
  expect_identical(out, c("  1 (1.2%) ", "  0        ",
                          " 11 (3.6%) ", "108 (35.3%)"))
  # the "0" cell is the same width as the widest cell (so it aligns)
  expect_true(all(nchar(out) == nchar(out[1L])))
})

test_that("fmt_count_paren copes with mixed tfrmt notations", {
  out <- unbsp(fmt_count_paren(c("2 ( 2.8%)", "0", "70 (100%)", "3 (<1%)")))
  expect_true(all(nchar(out) == nchar(out[1L])))   # equal width -> aligned
  expect_match(out[2L], "^ *0 *$")                 # lone 0, padded
})

test_that("fmt_count_paren leaves non-count cells unchanged", {
  expect_identical(fmt_count_paren(c("Mean (SD)", "n/a", "")),
                   c("Mean (SD)", "n/a", ""))
})

test_that("as_rtftables(cell_format = fn) applies to data columns only", {
  df <- data.frame(lab = c("A", "B"), x = c("1 (1.2%)", "0"),
                   stringsAsFactors = FALSE)
  p <- as_rtftables(df, cell_format = fmt_count_paren)[[1L]]
  expect_identical(p$data[[1L]], c("A", "B"))            # col 1 untouched
  expect_true(all(nchar(p$data[[2L]]) == nchar(p$data[[2L]][1L])))
})

test_that("as_rtftables(cell_format = list(...)) targets columns positionally", {
  df <- data.frame(a = c("1 (1.2%)", "0"), b = c("5", "120"),
                   stringsAsFactors = FALSE)
  p <- as_rtftables(df, cell_format = list(NULL, fmt_right_align))[[1L]]
  expect_identical(p$data[[1L]], c("1 (1.2%)", "0"))     # col 1 untouched
  expect_identical(unbsp(p$data[[2L]]), c("  5", "120")) # col 2 right-aligned
})

test_that("cell_format takes precedence over align_count_pct", {
  df <- data.frame(lab = c("A"), x = c("5 (5.0)"), stringsAsFactors = FALSE)
  p <- as_rtftables(df, align_count_pct = TRUE,
                    cell_format = fmt_right_align)[[1L]]
  # fmt_right_align keeps the content (just nbsp-pads); the count-pct realigner
  # would have widened it.  So the un-nbsp'd value is the original.
  expect_identical(unbsp(p$data[[2L]]), "5 (5.0)")
})

test_that("cell_format function returning wrong length errors", {
  df <- data.frame(lab = "A", x = "1", stringsAsFactors = FALSE)
  expect_error(as_rtftables(df, cell_format = function(x) character(0)),
               "same length")
})
