## tests/testthat/test-sort-by.R
##
## as_rtftables(sort_by=, sort_desc=): order body rows before pagination.
## Covers single / multi-key sorts, direction, stability, NA placement, the
## sort-key-carrier pattern (sort_by + drop_cols), feeding grouping, and
## validation.

library(testthat)

df4 <- function() {
  data.frame(
    grp   = c("B", "A", "B", "A"),
    ord   = c(2, 1, 1, 2),
    Label = c("b2", "a1", "b1", "a2"),
    N     = c("20", "10", "30", "40"),
    stringsAsFactors = FALSE
  )
}

# ── basic ordering ────────────────────────────────────────────────────────────

test_that("sort_by orders rows ascending by a single column", {
  res <- as_rtftables(df4(), sort_by = "Label")[[1L]]
  expect_identical(res$data$Label, c("a1", "a2", "b1", "b2"))
})

test_that("sort_by accepts an integer column index", {
  res <- as_rtftables(df4(), sort_by = 3L)[[1L]]      # Label
  expect_identical(res$data$Label, c("a1", "a2", "b1", "b2"))
})

test_that("sort_desc = TRUE sorts descending", {
  res <- as_rtftables(df4(), sort_by = "N", sort_desc = TRUE)[[1L]]
  expect_identical(res$data$N, c("40", "30", "20", "10"))
})

test_that("multi-key sort applies keys in priority order with per-key direction", {
  res <- as_rtftables(df4(), sort_by = c("grp", "ord"),
                      sort_desc = c(FALSE, TRUE))[[1L]]
  expect_identical(paste0(res$data$grp, res$data$ord),
                   c("A2", "A1", "B2", "B1"))
})

test_that("a list mixes name and index sort keys", {
  res <- as_rtftables(df4(), sort_by = list("grp", 2L))[[1L]]
  expect_identical(paste0(res$data$grp, res$data$ord),
                   c("A1", "A2", "B1", "B2"))
})

# ── stability + NA ────────────────────────────────────────────────────────────

test_that("sort is stable: equal keys keep input order", {
  df <- data.frame(k = c("x", "x", "x"),
                   v = c("first", "second", "third"),
                   stringsAsFactors = FALSE)
  res <- as_rtftables(df, sort_by = "k")[[1L]]
  expect_identical(res$data$v, c("first", "second", "third"))
})

test_that("NA keys sort last (ascending and descending)", {
  df <- data.frame(k = c("b", NA, "a"), v = c("B", "X", "A"),
                   stringsAsFactors = FALSE)
  expect_identical(as_rtftables(df, sort_by = "k")[[1L]]$data$v,
                   c("A", "B", "X"))
  expect_identical(
    as_rtftables(df, sort_by = "k", sort_desc = TRUE)[[1L]]$data$v,
    c("B", "A", "X"))
})

# ── interaction with drop_cols / grouping ─────────────────────────────────────

test_that("sort on a hidden carrier column (sort_by + drop_cols)", {
  res <- as_rtftables(df4(), sort_by = "ord", drop_cols = "ord")[[1L]]
  expect_false("ord" %in% names(res$data))
  # ord = c(2,1,1,2); stable asc -> rows with ord 1 first (a1,b1), then ord 2
  expect_identical(res$data$Label, c("a1", "b1", "b2", "a2"))
})

test_that("sort feeds group detection / by_value pagination", {
  res <- as_rtftables(df4(), split = "by_value", group_col = "grp",
                      sort_by = "grp", drop_cols = "grp")
  expect_identical(names(res), c("A", "B"))
  expect_identical(res[["A"]]$data$Label, c("a1", "a2"))
})

test_that("cell_styles follow the sorted row order", {
  cs <- list(
    list(bold = c(TRUE,  FALSE, FALSE, FALSE)),   # row1 (Label b2)
    list(bold = c(FALSE, TRUE,  FALSE, FALSE)),   # row2 (Label a1)
    list(bold = c(FALSE, FALSE, TRUE,  FALSE)),   # row3 (Label b1)
    list(bold = c(FALSE, FALSE, FALSE, TRUE))     # row4 (Label a2)
  )
  res <- as_rtftables(df4(), sort_by = "Label", cell_styles = cs)[[1L]]
  # sorted order a1,a2,b1,b2 -> original rows 2,4,3,1
  expect_identical(res$data$Label, c("a1", "a2", "b1", "b2"))
  expect_identical(res$cell_styles[[1L]]$bold, c(FALSE, TRUE, FALSE, FALSE))
  expect_identical(res$cell_styles[[2L]]$bold, c(FALSE, FALSE, FALSE, TRUE))
})

# ── no-op + validation ────────────────────────────────────────────────────────

test_that("sort_by = NULL keeps the input order", {
  res <- as_rtftables(df4(), sort_by = NULL)[[1L]]
  expect_identical(res$data$Label, c("b2", "a1", "b1", "a2"))
})

test_that("sort_by is honoured through a list input", {
  res <- as_rtftables(list(t1 = df4()), sort_by = "Label")
  expect_identical(res[[1L]]$data$Label, c("a1", "a2", "b1", "b2"))
})

test_that("as_rtftable() inherits sort_by", {
  rt <- as_rtftable(df4(), sort_by = "Label")
  expect_identical(rt$data$Label, c("a1", "a2", "b1", "b2"))
})

test_that("sort_by rejects unknown names and out-of-range indices", {
  expect_error(as_rtftables(df4(), sort_by = "nope"), "not found")
  expect_error(as_rtftables(df4(), sort_by = 99L), "out of range")
})

test_that("sort_desc length must be 1 or length(sort_by)", {
  expect_error(
    as_rtftables(df4(), sort_by = c("grp", "ord"),
                 sort_desc = c(TRUE, FALSE, TRUE)),
    "length 1 or 2")
})
