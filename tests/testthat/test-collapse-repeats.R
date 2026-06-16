# as_rtftables(collapse_repeats=): blank consecutive repeated values, per page,
# after the split (#131).

test_that("single column: consecutive repeats become NA, first kept (issue example)", {
  df <- data.frame(
    C = c("All", "All", "BORC", "BORC", "BORC", "BORC",
          "HOGE", "HAGE", "HOGE", "HAGE", "HAGE"),
    stringsAsFactors = FALSE)
  pg <- as_rtftables(df, collapse_repeats = "C")[[1L]]
  expect_equal(
    pg$data$C,
    c("All", NA, "BORC", NA, NA, NA, "HOGE", "HAGE", "HOGE", "HAGE", NA))
})

test_that("an integer column index is equivalent to the column name", {
  df <- data.frame(C = c("a", "a", "b", "b"), stringsAsFactors = FALSE)
  by_name <- as_rtftables(df, collapse_repeats = "C")[[1L]]
  by_idx  <- as_rtftables(df, collapse_repeats = 1L)[[1L]]
  expect_equal(by_idx$data$C, c("a", NA, "b", NA))
  expect_identical(by_idx$data$C, by_name$data$C)
})

test_that("multiple columns suppress repeats hierarchically (lower col resets on higher change)", {
  df <- data.frame(
    g = c("A", "A", "A", "B", "B"),
    s = c("x", "x", "y", "x", "x"),
    stringsAsFactors = FALSE)
  pg <- as_rtftables(df, collapse_repeats = c("g", "s"))[[1L]]
  # g: collapsed on its own value.
  expect_equal(pg$data$g, c("A", NA, NA, "B", NA))
  # s: collapsed on the (g, s) combination -- row 3 keeps "y" (combo A,x -> A,y)
  #    and row 4 keeps "x" (combo A,y -> B,x).
  expect_equal(pg$data$s, c("x", NA, "y", "x", NA))
})

test_that("the first listed column is collapsed on itself only, not the combination", {
  df <- data.frame(
    g = c("A", "B", "A"),    # not consecutive repeats -> nothing blanked
    s = c("x", "x", "x"),
    stringsAsFactors = FALSE)
  pg <- as_rtftables(df, collapse_repeats = c("g", "s"))[[1L]]
  expect_equal(pg$data$g, c("A", "B", "A"))
  # s never repeats within a constant (g) run here, so all three kept.
  expect_equal(pg$data$s, c("x", "x", "x"))
})

test_that("collapse is per page: a continued group repeats its label at the top of the next page", {
  df <- data.frame(grp = rep("A", 4L), val = as.character(1:4),
                   stringsAsFactors = FALSE)
  # split = "rows" cuts at position 2 -> page1 = row 1, page2 = rows 2..4.
  pages <- as_rtftables(df, split = "rows", split_rows = 2L,
                        collapse_repeats = "grp")
  expect_length(pages, 2L)
  expect_equal(pages[[1L]]$data$grp, "A")
  # Page 2 restarts suppression: first row shows "A" again, rest blanked.
  expect_equal(pages[[2L]]$data$grp, c("A", NA, NA))
})

test_that("group_safe page boundaries stay correct while each page is collapsed", {
  df <- data.frame(
    grp = c("A", "A", "B", "B", "C", "C"),
    val = as.character(1:6), stringsAsFactors = FALSE)
  pages <- as_rtftables(df, split = "group_safe", max_rows = 2,
                        group_col = "grp", group_by = "value",
                        collapse_repeats = "grp")
  expect_length(pages, 3L)
  # Each page keeps its first label and blanks the repeat.
  for (pg in pages) expect_equal(pg$data$grp, c(pg$data$grp[1L], NA))
})

test_that("as_rtftable() forwards collapse_repeats through ...", {
  df <- data.frame(C = c("a", "a", "b"), stringsAsFactors = FALSE)
  rt <- as_rtftable(df, collapse_repeats = "C")
  expect_equal(rt$data$C, c("a", NA, "b"))
})

test_that("collapse_repeats = NULL (default) leaves the body unchanged", {
  df <- data.frame(C = c("a", "a", "b"), stringsAsFactors = FALSE)
  pg <- as_rtftables(df)[[1L]]
  expect_equal(pg$data$C, c("a", "a", "b"))
})

test_that("an unknown collapse_repeats column name errors", {
  df <- data.frame(C = c("a", "a"), stringsAsFactors = FALSE)
  expect_error(as_rtftables(df, collapse_repeats = "nope"),
               "not found", fixed = FALSE)
})
