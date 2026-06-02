## tests/testthat/test-gt-adapter.R
##
## gt adapter (v0.0.46+): the body comes from gt::extract_body(output="html")
## and only render-relevant metadata is read.  All tests skip when gt is
## absent.

library(testthat)

# ── detection & token resolution ──────────────────────────────────────────────

test_that(".is_gt_tbl() detects gt tables", {
  skip_if_not_installed("gt")
  expect_true(rtfreporter:::.is_gt_tbl(gt::gt(head(mtcars, 1))))
  expect_false(rtfreporter:::.is_gt_tbl(data.frame(a = 1)))
})

test_that(".resolve_gt_tokens() handles TRUE / FALSE / vector / bad token", {
  all <- rtfreporter:::.GT_META_TOKENS
  expect_identical(rtfreporter:::.resolve_gt_tokens(TRUE),  all)
  expect_identical(rtfreporter:::.resolve_gt_tokens(FALSE), character(0))
  expect_identical(rtfreporter:::.resolve_gt_tokens(c("titles")), "titles")
  expect_error(rtfreporter:::.resolve_gt_tokens("nope"), "Unknown")
})

# ── clean body ────────────────────────────────────────────────────────────────

test_that(".gt_to_rtftable_kwargs() body keeps only visible columns", {
  skip_if_not_installed("gt")
  g  <- gt::gt(data.frame(a = c("x", "y"), b = 1:2, stringsAsFactors = FALSE)) |>
    gt::cols_hide(a)
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g)
  expect_equal(ncol(kw$data), 1L)           # hidden column dropped
})

test_that(".gt_to_rtftable_kwargs() body has no stray newlines", {
  skip_if_not_installed("gt")
  skip_if_not_installed("tfrmt")
  dat <- data.frame(group = c("Age", "Age"), label = c("Mean", "SD"),
                    column = "Trt A", value = c(45.1, 5.2),
                    param = c("mean", "sd"), stringsAsFactors = FALSE)
  tf <- tfrmt::tfrmt(
    group = group, label = label, column = column, param = param, value = value,
    body_plan = tfrmt::body_plan(
      tfrmt::frmt_structure(".default", ".default", tfrmt::frmt("xx.x"))))
  g  <- tfrmt::print_to_gt(tf, dat)
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g)
  # tfrmt's helper column (..tfrmt_row_grp_lbl) is gone, and the group-label
  # rows are genuinely empty (no "<br />" -> "\n").
  expect_false(any(grepl("tfrmt", names(kw$data))))
  expect_false(any(grepl("\n", as.matrix(kw$data), fixed = TRUE)))
})

# ── metadata: labels / alignment / spanning / widths / titles / footnotes ─────

test_that("col_header + alignment are read from a gt_tbl", {
  skip_if_not_installed("gt")
  g  <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl")]) |>
    gt::cols_label(mpg = "MPG", cyl = "Cyl") |>
    gt::cols_align("right", columns = c(mpg, cyl))
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g)
  expect_identical(kw$col_header, c("MPG", "Cyl"))
  expect_identical(vapply(kw$col_spec, function(s) s$align, ""), c("right", "right"))
})

test_that("spanning headers become a stacked multi-row col_header", {
  skip_if_not_installed("gt")
  g  <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl", "disp")]) |>
    gt::tab_spanner(label = "Engine", columns = c(cyl, disp))
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g)
  expect_true(is.list(kw$col_header))
  # last row is the leaf labels; an upper row carries the spanner cell.
  bottom <- kw$col_header[[length(kw$col_header)]]
  expect_true(is.character(bottom))
})

test_that("px widths -> column_widths_twips; pct -> col_rel_width", {
  skip_if_not_installed("gt")
  gpx <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl")]) |>
    gt::cols_width(mpg ~ gt::px(100), cyl ~ gt::px(50))
  kpx <- rtfreporter:::.gt_to_rtftable_kwargs(gpx)
  expect_identical(kpx$column_widths_twips, c(1500L, 750L))   # 1px = 15 twips
})

test_that("titles + source notes become page-level blocks", {
  skip_if_not_installed("gt")
  g  <- gt::gt(head(mtcars, 1)[, "mpg", drop = FALSE]) |>
    gt::tab_header(title = "T", subtitle = "Sub") |>
    gt::tab_source_note("Source: x")
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g)
  expect_identical(kw$titles_block, c("T", "Sub"))
  expect_true("Source: x" %in% kw$footnotes_block)
})

# ── footnote marks ────────────────────────────────────────────────────────────

test_that(".convert_footnote_marks() rewrites gt's <sup> marks to ^{N}", {
  df <- data.frame(
    a = c('<span class="gt_footnote_marks"><sup>1</sup></span> 21', "x"),
    stringsAsFactors = FALSE)
  out <- rtfreporter:::.convert_footnote_marks(df)
  expect_match(out$a[1L], "\\^\\{1\\}")
  expect_false(grepl("gt_footnote_marks|<sup>", out$a[1L]))
  expect_identical(out$a[2L], "x")
})

test_that("gt in-cell footnote marks survive as ^{N} through the adapter", {
  skip_if_not_installed("gt")
  g  <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl")]) |>
    gt::tab_footnote("note", gt::cells_body(rows = 1, columns = mpg))
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g)
  expect_match(kw$data[[1L]][1L], "\\^\\{1\\}")
})

# ── read_meta semantics ───────────────────────────────────────────────────────

test_that("read_meta = FALSE yields a clean body but no metadata", {
  skip_if_not_installed("gt")
  g  <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl")]) |>
    gt::cols_label(mpg = "MPG") |>
    gt::tab_header(title = "T")
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g, tokens = character(0))
  expect_false(is.null(kw$data))
  expect_null(kw$col_header)
  expect_null(kw$col_spec)
  expect_null(kw$titles_block)
})

# ── end-to-end ────────────────────────────────────────────────────────────────

test_that("as_rtftable(gt) returns an rtftable with gt labels + align", {
  skip_if_not_installed("gt")
  g  <- gt::gt(head(mtcars, 2)[, c("mpg", "cyl")]) |>
    gt::cols_label(mpg = "MPG", cyl = "Cyl") |>
    gt::cols_align("right")
  tbl <- as_rtftable(g)
  expect_s3_class(tbl, "rtftable")
  expect_identical(unlist(tbl$col_header[[1L]]), c("MPG", "Cyl"))
  expect_identical(tbl$col_spec[[1L]]$align, "right")
})

test_that("as_rtftable(gt, read_meta = FALSE) ignores gt metadata", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 2)[, c("mpg", "cyl")]) |>
    gt::cols_label(mpg = "MPG") |>
    gt::tab_header(title = "T")
  tbl <- as_rtftable(g, read_meta = FALSE)
  expect_null(tbl$col_header)
  expect_null(attr(tbl, "rtf_titles"))
})

test_that("explicit args win over gt-extracted values", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, "mpg", drop = FALSE]) |>
    gt::cols_label(mpg = "MPG")
  tbl <- as_rtftable(g, col_header = "Override")
  expect_identical(tbl$col_header[[1L]], "Override")
})
