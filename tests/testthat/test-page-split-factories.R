# page_split_*() strategy factories + string-alias equivalence.

.df12 <- function() {
  data.frame(
    label = c("A", " a1", " a2", " a3",
              "B", " b1", " b2", " b3",
              "C", " c1", " c2", " c3"),
    value = as.character(1:12),
    stringsAsFactors = FALSE
  )
}

# Helper: extract the row-label column of every page as a list of vectors.
.labels_of <- function(pages) lapply(pages, function(p) p$data[[1L]])

test_that("factories return functions usable directly as split=", {
  df <- .df12()
  f  <- page_split_rows(c(5L, 9L))
  expect_true(is.function(f))
  pages <- as_rtftables(df, split = f)
  expect_length(pages, 3L)               # cut at 5 and 9 -> 3 pages
  expect_equal(nrow(pages[[1L]]$data), 4L)
})

test_that("page_split_none yields a single page", {
  df <- .df12()
  pages <- as_rtftables(df, split = page_split_none())
  expect_length(pages, 1L)
  expect_equal(nrow(pages[[1L]]$data), 12L)
})

test_that("page_split_by_value names pages by group and matches the string alias", {
  df <- .df12()
  via_factory <- as_rtftables(df, split = page_split_by_value(group_col = "label"))
  via_string  <- as_rtftables(df, split = "by_value", group_col = "label")
  expect_setequal(names(via_factory), names(via_string))
  expect_identical(.labels_of(via_factory), .labels_of(via_string))
})

test_that("page_split_group_safe matches the string alias", {
  df <- .df12()
  via_factory <- as_rtftables(df,
                              split = page_split_group_safe(max_rows = 5L,
                                                            group_col = "label"))
  via_string  <- as_rtftables(df, split = "group_safe", max_rows = 5L,
                              group_col = "label")
  expect_length(via_factory, length(via_string))
  expect_identical(.labels_of(via_factory), .labels_of(via_string))
})

test_that("page_split_group_force matches the string alias", {
  df <- .df12()
  via_factory <- as_rtftables(df,
                              split = page_split_group_force(max_rows = 5L,
                                                             group_col = "label"))
  via_string  <- as_rtftables(df, split = "group_force", max_rows = 5L,
                              group_col = "label")
  expect_length(via_factory, length(via_string))
  expect_identical(.labels_of(via_factory), .labels_of(via_string))
})

test_that("factory config can be left to call-time fallback", {
  df <- .df12()
  # max_rows omitted on the factory, supplied to as_rtftables() instead.
  via_fallback <- as_rtftables(df, split = page_split_group_force(group_col = "label"),
                               max_rows = 5L)
  via_string   <- as_rtftables(df, split = "group_force", max_rows = 5L,
                               group_col = "label")
  expect_identical(.labels_of(via_fallback), .labels_of(via_string))
})

test_that("missing required config errors", {
  df <- .df12()
  expect_error(as_rtftables(df, split = page_split_group_safe(group_col = "label")),
               "max_rows")
  expect_error(as_rtftables(df, split = page_split_rows()),
               "split_rows")
})
