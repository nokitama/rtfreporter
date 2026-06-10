# count_blank_rows = TRUE: blank separator rows count toward max_rows during
# pagination (materialise-then-collapse), default FALSE keeps current behaviour.

.df9 <- function() {
  data.frame(
    label = c("Group A", "  a1", "  a2", "Group B", "  b1", "  b2",
              "Group C", "  c1", "  c2"),
    v = as.character(1:9), stringsAsFactors = FALSE
  )
}

.total <- function(page) nrow(page$data) + length(page$blank_rows)

test_that("default (FALSE) does not count blanks: a page can exceed max_rows", {
  pages <- as_rtftables(.df9(), split = "group_safe", max_rows = 6,
                        blank_rows = "between_groups")
  # group_safe packs A+B (6 data) on page 1, plus a between-group blank -> 7.
  expect_equal(nrow(pages[[1L]]$data), 6L)
  expect_true(.total(pages[[1L]]) > 6L)        # overflows the visual budget
})

test_that("count_blank_rows = TRUE keeps every page within max_rows", {
  pages <- as_rtftables(.df9(), split = "group_safe", max_rows = 6,
                        blank_rows = "between_groups", count_blank_rows = TRUE)
  for (p in pages) expect_lte(.total(p), 6L)   # data + blanks <= max_rows
  # The blanks are still present (as attributes), just counted.
  expect_true(any(vapply(pages, function(p) length(p$blank_rows) > 0L,
                         logical(1L))))
})

test_that("count_blank_rows counts an existing rtf_blank_rows attribute", {
  df <- set_blank_rows(.df9(), blank_rows = "between_groups")
  expect_false(is.null(attr(df, "rtf_blank_rows")))
  pages <- as_rtftables(df, split = "group_safe", max_rows = 6,
                        count_blank_rows = TRUE)   # no blank_rows arg
  for (p in pages) expect_lte(.total(p), 6L)
})

test_that("a leading blank is suppressed at the top of a page", {
  # Position 0 (before first row) must never appear as a page's first row.
  pages <- as_rtftables(.df9(), split = "group_force", max_rows = 4,
                        blank_rows = c(0L, 3L), count_blank_rows = TRUE)
  for (p in pages) expect_false(0L %in% p$blank_rows)
})

test_that("the marker column never leaks into the rendered table", {
  pages <- as_rtftables(.df9(), split = "group_safe", max_rows = 6,
                        blank_rows = "between_groups", count_blank_rows = TRUE)
  for (p in pages) expect_false(".__rtf_blank__" %in% names(p$data))
  # And it renders end-to-end.
  doc <- rtf_document() |> rtf_tables(pages)
  f <- tempfile(fileext = ".rtf"); on.exit(unlink(f), add = TRUE)
  generate_rtfreport(doc, f, overwrite = TRUE)
  expect_gt(file.info(f)$size, 0)
})

test_that("count_blank_rows with no blanks behaves like the default", {
  a <- as_rtftables(.df9(), split = "group_safe", max_rows = 6)
  b <- as_rtftables(.df9(), split = "group_safe", max_rows = 6,
                    count_blank_rows = TRUE)
  expect_equal(length(a), length(b))
  expect_identical(lapply(a, function(p) p$data),
                   lapply(b, function(p) p$data))
})
