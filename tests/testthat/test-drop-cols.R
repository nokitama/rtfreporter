## tests/testthat/test-drop-cols.R
##
## as_rtftables(drop_cols=): hide a column from the printed pages while still
## using it for pagination / grouping.  Covers the core hide behaviour, the
## metadata reindexing (col_header flat + spanning, col_spec, widths,
## col_header_align, row_title, cell_styles), and validation.

library(testthat)

df4 <- function() {
  data.frame(
    grp   = c("A", "A", "B", "B"),
    Label = c("x1", "x2", "y1", "y2"),
    N     = c("1", "2", "3", "4"),
    Pct   = c("10", "20", "30", "40"),
    stringsAsFactors = FALSE
  )
}

# ── core: hide a grouping column ──────────────────────────────────────────────

test_that("drop_cols removes the named column from every page", {
  res <- as_rtftables(df4(), drop_cols = "grp")
  expect_length(res, 1L)
  expect_identical(names(res[[1L]]$data), c("Label", "N", "Pct"))
})

test_that("drop_cols accepts an integer index", {
  res <- as_rtftables(df4(), drop_cols = 2L)        # drop "Label"
  expect_identical(names(res[[1L]]$data), c("grp", "N", "Pct"))
})

test_that("drop_cols accepts several columns (a list mixing names + indices)", {
  res <- as_rtftables(df4(), drop_cols = list("grp", 3L))
  expect_identical(names(res[[1L]]$data), c("Label", "Pct"))
})

test_that("a hidden column still drives by_value pagination + page names", {
  res <- as_rtftables(df4(), split = "by_value", group_col = "grp",
                      drop_cols = "grp")
  expect_length(res, 2L)
  expect_identical(names(res), c("A", "B"))
  # grp gone from the rendered pages, the rest kept
  expect_identical(names(res[[1L]]$data), c("Label", "N", "Pct"))
  expect_identical(res[[1L]]$data$Label, c("x1", "x2"))
})

test_that("a hidden carrier column still drives group_force pagination", {
  res <- as_rtftables(df4(), split = "group_force", group_col = 1L,
                      max_rows = 2L, drop_cols = 1L)
  expect_length(res, 2L)
  expect_false("grp" %in% names(res[[1L]]$data))
})

test_that("drop_cols is honoured through a list input", {
  res <- as_rtftables(list(t1 = df4(), t2 = df4()), drop_cols = "grp")
  expect_length(res, 2L)
  expect_identical(names(res[[1L]]$data), c("Label", "N", "Pct"))
  expect_identical(names(res[[2L]]$data), c("Label", "N", "Pct"))
})

test_that("as_rtftable() inherits drop_cols", {
  rt <- as_rtftable(df4(), drop_cols = "grp")
  expect_s3_class(rt, "rtftable")
  expect_identical(names(rt$data), c("Label", "N", "Pct"))
})

# ── metadata reindexing ───────────────────────────────────────────────────────

test_that("flat col_header / widths / col_header_align reindex to kept columns", {
  rt <- as_rtftables(
    df4(), drop_cols = "grp",
    col_header       = c("GRP", "Subject", "Count", "Percent"),
    col_rel_width    = c(1, 3, 2, 2),
    col_header_align = c("left", "left", "center", "center")
  )[[1L]]
  expect_identical(unlist(rt$col_header), c("Subject", "Count", "Percent"))
  expect_identical(rt$col_rel_width, c(3, 2, 2))
  expect_identical(ncol(rt$data), 3L)
})

test_that("col_spec reindexes: integer remapped, dropped entry removed, name kept", {
  rt <- as_rtftables(
    df4(), drop_cols = 2L,                      # drop "Label"
    col_spec = list(
      list(col = 1L,    align = "left"),        # grp  -> kept, remap to 1
      list(col = 2L,    align = "right"),       # Label-> dropped, entry gone
      list(col = "Pct", align = "right")        # by name, survives
    )
  )[[1L]]
  # normalized col_spec is positional, one entry per kept column
  expect_length(rt$col_spec, 3L)
  aligns <- vapply(rt$col_spec, function(s) s$align, character(1L))
  expect_identical(aligns, c("left", "center", "right"))  # grp, N(default), Pct
})

test_that("spanning header positions reindex when a column is dropped", {
  sph <- list(
    list(col_cell(pos = c(3, 4), label = "Stats")),
    c("grp", "Label", "N", "Pct")
  )
  rt <- as_rtftables(df4(), drop_cols = "grp", col_header = sph)[[1L]]
  # leaf row shrank
  expect_identical(rt$col_header[[2L]], c("Label", "N", "Pct"))
  # the span over N,Pct shifted from cols 3-4 to cols 2-3
  span <- Filter(function(c) identical(c$label, "Stats"), rt$col_header[[1L]])
  expect_length(span, 1L)
  expect_identical(c(span[[1L]]$from, span[[1L]]$to), c(2L, 3L))
})

test_that("a spanning cell fully inside the dropped columns is removed", {
  sph <- list(
    list(col_cell(pos = c(1, 2), label = "Hidden"),
         col_cell(pos = c(3, 4), label = "Stats")),
    c("grp", "Label", "N", "Pct")
  )
  rt <- as_rtftables(df4(), drop_cols = c(1L, 2L), col_header = sph)[[1L]]
  labels <- vapply(rt$col_header[[1L]], function(c) c$label %||% "", character(1L))
  expect_false("Hidden" %in% labels)
  expect_true("Stats" %in% labels)
})

test_that("cell_styles per-column vectors reindex to kept columns", {
  cs <- replicate(4, list(bold = c(TRUE, FALSE, FALSE, TRUE)),
                  simplify = FALSE)
  rt <- as_rtftables(df4(), drop_cols = 1L, cell_styles = cs)[[1L]]
  expect_identical(length(rt$cell_styles[[1L]]$bold), 3L)
  expect_identical(rt$cell_styles[[1L]]$bold, c(FALSE, FALSE, TRUE))
})

test_that("row_title reindexes; dropped names fall away", {
  # row_title names grp + Label; grp is dropped, Label remains the heading col
  rt <- as_rtftables(df4(), drop_cols = "grp",
                     row_title = c("grp", "Label"))[[1L]]
  # Label is now column 1 and left-aligned (row-heading default)
  expect_identical(rt$col_spec[[1L]]$align, "left")
})

# ── validation ────────────────────────────────────────────────────────────────

test_that("drop_cols cannot remove every column", {
  expect_error(as_rtftables(df4(), drop_cols = c(1L, 2L, 3L, 4L)),
               "leave at least one column")
})

test_that("drop_cols rejects unknown names and out-of-range indices", {
  expect_error(as_rtftables(df4(), drop_cols = "nope"), "not found")
  expect_error(as_rtftables(df4(), drop_cols = 99L), "out of range")
})

test_that("drop_cols = NULL is a no-op", {
  res <- as_rtftables(df4(), drop_cols = NULL)
  expect_identical(names(res[[1L]]$data), c("grp", "Label", "N", "Pct"))
})
