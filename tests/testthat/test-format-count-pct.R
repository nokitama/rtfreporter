# format_count_pct() / realign_count_pct() — uniform "n (xx.x)" widths.

# ──────── format_count_pct: numeric inputs ───────────────────────────────

test_that("format_count_pct() produces 10-char-wide strings (NBSP padded)", {
  # Fractions (default)
  out <- format_count_pct(c(5L, 14L, 30L), c(0.053, 0.500, 1.000))
  expect_identical(nchar(out), c(10L, 10L, 10L))
})

test_that("format_count_pct() respects pct_unit = 'percent'", {
  out <- format_count_pct(c(5L, 14L, 30L), c(5, 50, 100),
                           pct_unit = "percent")
  expect_identical(nchar(out), c(10L, 10L, 10L))
  expect_match(out[3L], "100")             # 100% rendered without decimals
})

test_that("format_count_pct() handles count = 0 / NA (count-only branch)", {
  out_0  <- format_count_pct(0L,        0.0)
  out_na <- format_count_pct(NA_integer_, NA_real_)
  expect_identical(nchar(out_0), 10L)
  expect_identical(nchar(out_na), 10L)
  # No parenthesis on the zero / NA branch
  expect_false(grepl("\\(", out_0))
})

test_that("format_count_pct() picks the < 10 vs >= 10 branch correctly", {
  small <- format_count_pct(1L, 5,    pct_unit = "percent")
  big   <- format_count_pct(7L, 33.3, pct_unit = "percent")
  expect_match(small, "\\(5\\.0\\)")        # one-digit pct -> X.Y
  expect_match(big,   "\\(33\\.3\\)")        # two-digit pct -> XX.Y
})

test_that("format_count_pct() supports plain spaces via nbsp = ' '", {
  out <- format_count_pct(7L, 0.333, nbsp = " ")
  expect_match(out, "  7 \\(33\\.3\\)")     # padding is regular spaces
})

test_that("format_count_pct() recycles length-1 against the other vector", {
  out <- format_count_pct(c(1L, 2L, 3L), 0.5)        # pct recycled
  expect_length(out, 3L)
  out <- format_count_pct(2L, c(0.10, 0.50, 0.95))   # count recycled
  expect_length(out, 3L)
})

test_that("format_count_pct() rejects mismatched non-recyclable lengths", {
  expect_error(format_count_pct(1:3, c(0.1, 0.2)), "same length")
})

# ──────── realign_count_pct: string inputs ────────────────────────────────

test_that("realign_count_pct() reformats matching cells; passes through others", {
  inp <- c("5 (33.3)", "12 (100.0)", "0 (0.0)", "not a count", "1 (5.0)")
  out <- realign_count_pct(inp)
  # Lengths uniform for matching cells
  matching_idx <- c(1L, 2L, 3L, 5L)
  expect_identical(nchar(out[matching_idx]),
                   rep(10L, length(matching_idx)))
  # Non-matching cell passes through
  expect_identical(out[4L], "not a count")
})

test_that("realign_count_pct() handles empty / NULL / non-character input gracefully", {
  expect_identical(realign_count_pct(character(0)), character(0))
  expect_null(realign_count_pct(NULL))
  # Numeric input is coerced
  expect_identical(realign_count_pct(c(1L, 2L)), c("1", "2"))
})

# ──────── paginate(align_count_pct = TRUE) integration ────────────────────

test_that("paginate(align_count_pct = TRUE) realigns columns 2..N", {
  df <- data.frame(
    label = c("Sex", "  Female", "  Male"),
    a     = c("",        "16 (53.3)",  "14 (46.7)"),
    b     = c("",        "1 (5.0)",    "12 (100.0)"),
    stringsAsFactors = FALSE
  )
  pages <- paginate(df, align_count_pct = TRUE)
  out_a <- pages[[1L]]$a
  # All non-empty cells now have width 10 (uniform with NBSP padding)
  non_empty <- nzchar(out_a)
  expect_true(all(nchar(out_a[non_empty]) == 10L))
})

test_that("paginate(align_count_pct = FALSE) leaves columns untouched (default)", {
  df <- data.frame(
    label = c("Sex", "  F"),
    a     = c("",    "5 (33.3)"),
    stringsAsFactors = FALSE
  )
  pages <- paginate(df)                    # default = FALSE
  expect_identical(pages[[1L]]$a[2L], "5 (33.3)")
})
