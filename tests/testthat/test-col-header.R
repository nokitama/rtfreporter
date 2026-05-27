# Unified col_header API (v0.0.21+): col_cell(), rtf_col_header(),
# add_col_header_row(), and the pos = ... cell-spec format.

# ──────── col_cell() validation ───────────────────────────────────────────

test_that("col_cell() builds a tagged spec for a single column", {
  c1 <- col_cell(1, "Item")
  expect_s3_class(c1, "rtf_col_cell")
  expect_identical(c1$pos, 1L)
  expect_identical(c1$label, "Item")
})

test_that("col_cell() handles pos = c(start, end) spans", {
  c1 <- col_cell(c(2, 5), "Treatment", align = "center", underline = TRUE)
  expect_identical(c1$pos, c(2L, 5L))
  expect_identical(c1$label, "Treatment")
  expect_identical(c1$align, "center")
  expect_true(c1$underline)
})

test_that("col_cell() rejects malformed pos", {
  expect_error(col_cell("a"),       "must be a numeric")
  expect_error(col_cell(0),         "values must be >= 1")
  expect_error(col_cell(c(3, 2)),   "start must be <= end")
  expect_error(col_cell(c(1, 2, 3)), "must be a numeric")
})

test_that("col_cell() rejects malformed align", {
  expect_error(col_cell(1, "X", align = "justify"),
               "align.*must be NULL")
})

# ──────── rtf_col_header() and add_col_header_row() ───────────────────────

test_that("rtf_col_header() collects rows top-to-bottom", {
  hdr <- rtf_col_header(
    list(col_cell(1, ""), col_cell(c(2, 3), "Group")),
    c("Item", "A", "B")
  )
  expect_s3_class(hdr, "rtf_col_header")
  expect_length(hdr, 2L)
  expect_true(is.list(hdr[[1L]]))
  expect_true(is.character(hdr[[2L]]))
})

test_that("add_col_header_row() appends and prepends", {
  hdr <- rtf_col_header(c("Item", "N", "Mean", "N", "Mean"))
  hdr <- add_col_header_row(hdr,
                             list(col_cell(1, ""),
                                  col_cell(c(2, 3), "Drug A"),
                                  col_cell(c(4, 5), "Drug B")),
                             .position = "top")
  expect_length(hdr, 2L)
  expect_true(is.list(hdr[[1L]]))                   # spanning row on top
  expect_true(is.character(hdr[[2L]]))              # labels at bottom

  hdr <- add_col_header_row(hdr, c("x", "y", "z", "w", "v"))
  expect_length(hdr, 3L)
  expect_true(is.character(hdr[[3L]]))              # appended at bottom
})

test_that("add_col_header_row() promotes a non-rtf_col_header input", {
  hdr <- add_col_header_row(c("A", "B"), list(col_cell(1, ""),
                                                col_cell(2, "Group")))
  expect_s3_class(hdr, "rtf_col_header")
  expect_length(hdr, 2L)
})

# ──────── pos-spec normalisation ───────────────────────────────────────────

test_that(".pos_row_to_spans converts pos cells to spanning specs with gap-fill", {
  row <- list(col_cell(1, "Item"),
              col_cell(c(3, 4), "Group"))   # gap at col 2
  out <- rtfreporter:::.pos_row_to_spans(row, 5L)
  # Expected: cells at (1,1)="Item", (2,2)="", (3,4)="Group", (5,5)=""
  expect_length(out, 4L)
  expect_identical(out[[1L]]$from, 1L); expect_identical(out[[1L]]$to, 1L)
  expect_identical(out[[1L]]$label, "Item")
  expect_identical(out[[2L]]$from, 2L); expect_identical(out[[2L]]$to, 2L)
  expect_identical(out[[2L]]$label, "")
  expect_identical(out[[3L]]$from, 3L); expect_identical(out[[3L]]$to, 4L)
  expect_identical(out[[3L]]$label, "Group")
  expect_identical(out[[4L]]$from, 5L); expect_identical(out[[4L]]$to, 5L)
})

test_that(".pos_row_to_spans rejects overlapping cells and out-of-range pos", {
  expect_error(
    rtfreporter:::.pos_row_to_spans(
      list(col_cell(c(1, 3), "X"), col_cell(c(2, 4), "Y")), 5L),
    "overlaps")
  expect_error(
    rtfreporter:::.pos_row_to_spans(list(col_cell(6, "Z")), 5L),
    "outside data column range")
})

# ──────── End-to-end: pos format in rtftable() ────────────────────────────

test_that("rtftable() accepts a bare list of cell specs as a single row", {
  df <- data.frame(A = 1, B = "x", C = 2.5, D = 1L, E = 2L)
  tbl <- rtftable(df, col_header = list(
    col_cell(1, "Item"),
    col_cell(c(2, 5), "Other")
  ))
  expect_length(tbl$col_header, 1L)
  expect_true(is.list(tbl$col_header[[1L]]))
  # Verify gap-fill at col 1 is NOT needed (cell 1 starts at pos 1)
  cells <- tbl$col_header[[1L]]
  expect_identical(cells[[1L]]$from, 1L)
  expect_identical(cells[[1L]]$to,   1L)
  expect_identical(cells[[2L]]$from, 2L)
  expect_identical(cells[[2L]]$to,   5L)
})

test_that("rtftable() accepts a multi-row pos-style col_header", {
  df <- data.frame(Item = "x",
                   A_N = 1L, A_M = 2.5,
                   B_N = 3L, B_M = 4.5,
                   stringsAsFactors = FALSE)
  hdr <- rtf_col_header(
    list(col_cell(1, ""), col_cell(c(2, 5), "Treatment")),
    list(col_cell(1, ""),
         col_cell(c(2, 3), "Drug A"),
         col_cell(c(4, 5), "Drug B")),
    c("Item", "N", "Mean", "N", "Mean")
  )
  tbl <- rtftable(df, col_header = hdr)
  expect_length(tbl$col_header, 3L)

  # End-to-end render should contain all labels.
  doc <- rtf_document()
  doc <- rtf_section(doc, page = 1, secinfo = list(header = NULL, footer = NULL))
  doc <- rtf_tables(doc, list(tbl))
  txt <- .render_to_string(doc)
  expect_match(txt, "Treatment")
  expect_match(txt, "Drug A")
  expect_match(txt, "Drug B")
})

test_that("first-level spanning via pos format now works (previously needed spanning_header)", {
  df <- data.frame(Item = "x", A = 1, B = 2)
  tbl <- rtftable(df, col_header = rtf_col_header(
    list(col_cell(1, ""), col_cell(c(2, 3), "M (SD)"))
  ))
  doc <- rtf_document()
  doc <- rtf_section(doc, page = 1, secinfo = list(header = NULL, footer = NULL))
  doc <- rtf_tables(doc, list(tbl))
  txt <- .render_to_string(doc)
  expect_match(txt, "M \\(SD\\)")
})

# ──────── Backward compatibility ───────────────────────────────────────────

test_that("legacy character col_header still works", {
  tbl <- rtftable(data.frame(A = 1, B = 2, C = 3),
                   col_header = c("X", "Y", "Z"))
  expect_length(tbl$col_header, 1L)
  expect_identical(tbl$col_header[[1L]], c("X", "Y", "Z"))
})

test_that("legacy list(spanning_spec_row) col_header still works", {
  tbl <- rtftable(data.frame(A = 1, B = 2, C = 3, D = 4),
    col_header = list(
      list(list(from = 1, to = 2, label = "G1"),
           list(from = 3, to = 4, label = "G2")),
      c("a", "b", "c", "d")
    ))
  expect_length(tbl$col_header, 2L)
  expect_true(is.list(tbl$col_header[[1L]]))
  expect_identical(tbl$col_header[[2L]], c("a", "b", "c", "d"))
})

test_that("legacy spanning_header argument still works", {
  df <- data.frame(Item = "x", A = 1L, B = 2L)
  tbl <- rtftable(df,
    spanning_header = list(
      list(from = 2, to = 3, label = "Group", underline = TRUE)
    ))
  doc <- rtf_document()
  doc <- rtf_section(doc, page = 1, secinfo = list(header = NULL, footer = NULL))
  doc <- rtf_tables(doc, list(tbl))
  txt <- .render_to_string(doc)
  expect_match(txt, "Group")
})

# ──────── Builder-style incremental API ───────────────────────────────────

test_that("incremental builder produces the same internal shape as one-shot constructor", {
  one_shot <- rtf_col_header(
    list(col_cell(1, ""), col_cell(c(2, 5), "Trt")),
    list(col_cell(1, ""),
         col_cell(c(2, 3), "A"),
         col_cell(c(4, 5), "B")),
    c("Item", "N", "M", "N", "M")
  )
  built <- rtf_col_header() |>
    add_col_header_row(list(col_cell(1, ""), col_cell(c(2, 5), "Trt"))) |>
    add_col_header_row(list(col_cell(1, ""),
                             col_cell(c(2, 3), "A"),
                             col_cell(c(4, 5), "B"))) |>
    add_col_header_row(c("Item", "N", "M", "N", "M"))
  expect_identical(unclass(one_shot), unclass(built))
})
