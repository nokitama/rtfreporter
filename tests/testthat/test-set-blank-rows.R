# set_blank_rows() — standalone blank-row attribute helper.

# ──────── Basic positioning ───────────────────────────────────────────────

test_that("integer positions land in rtf_blank_rows", {
  df  <- data.frame(a = 1:5)
  out <- set_blank_rows(df, blank_rows = c(1L, 3L))
  expect_identical(attr(out, "rtf_blank_rows"), c(1L, 3L))
})

test_that("blank_row_first = TRUE prepends position 0", {
  df  <- data.frame(a = 1:5)
  out <- set_blank_rows(df, blank_row_first = TRUE)
  expect_identical(attr(out, "rtf_blank_rows"), 0L)
})

test_that("blank_row_end = TRUE appends position nrow(df)", {
  df  <- data.frame(a = 1:5)
  out <- set_blank_rows(df, blank_row_end = TRUE)
  expect_identical(attr(out, "rtf_blank_rows"), 5L)
})

test_that("between_groups detects indent-based group transitions", {
  df  <- data.frame(
    label = c("A", "  a1", "  a2", "B", "  b1", "  b2"),
    v = 1:6,
    stringsAsFactors = FALSE
  )
  out <- set_blank_rows(df, blank_rows = "between_groups")
  # Group boundary is between rows 3 and 4 → blank position = 3
  expect_identical(attr(out, "rtf_blank_rows"), 3L)
})

test_that("explicit group_col overrides indent detection", {
  df <- data.frame(
    visit = c("Wk1", "Wk1", "Wk2", "Wk2", "Wk4"),
    v     = 1:5,
    stringsAsFactors = FALSE
  )
  out <- set_blank_rows(df, blank_rows = "between_groups",
                         group_col = "visit")
  expect_identical(attr(out, "rtf_blank_rows"), c(2L, 4L))
})

# ──────── Union of multiple specs ─────────────────────────────────────────

test_that("blank_rows + blank_row_first + blank_row_end union as expected", {
  df  <- data.frame(
    label = c("A", "  a1", "  a2", "B", "  b1"),
    v = 1:5,
    stringsAsFactors = FALSE
  )
  out <- set_blank_rows(df,
                         blank_rows      = "between_groups",
                         blank_row_first = TRUE,
                         blank_row_end   = TRUE)
  # Positions: 0 (first), 3 (between groups), 5 (end)
  expect_identical(attr(out, "rtf_blank_rows"), c(0L, 3L, 5L))
})

test_that("out-of-range positions are silently clipped", {
  df  <- data.frame(a = 1:3)
  out <- set_blank_rows(df, blank_rows = c(0L, 99L))
  expect_identical(attr(out, "rtf_blank_rows"), 0L)
})

test_that("empty spec leaves the attribute absent", {
  df  <- data.frame(a = 1:3)
  out <- set_blank_rows(df)
  expect_null(attr(out, "rtf_blank_rows"))
})

# ──────── End-to-end: rtftable() picks it up ──────────────────────────────

test_that("rtftable(read_attributes = TRUE) consumes set_blank_rows() output", {
  df  <- data.frame(
    label = c("A", "  a1", "  a2", "B", "  b1"),
    v = 1:5,
    stringsAsFactors = FALSE
  )
  out <- set_blank_rows(df,
                         blank_rows      = "between_groups",
                         blank_row_first = TRUE,
                         blank_row_end   = TRUE)
  tbl <- rtftable(out)
  expect_identical(tbl$blank_rows, c(0L, 3L, 5L))
})

# ──────── Tibble class is preserved ───────────────────────────────────────

test_that("set_blank_rows() preserves tibble class", {
  skip_if_not_installed("tibble")
  tb  <- tibble::tibble(a = 1:3)
  out <- set_blank_rows(tb, blank_row_first = TRUE)
  expect_s3_class(out, "tbl_df")
})
