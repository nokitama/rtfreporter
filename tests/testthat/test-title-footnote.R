# Title / footnote rendering as content-width tables (one row per line), the
# rtf_titles / rtf_footnotes pipe helpers, length-1 (common) recycling, and
# per-line styling.  Legacy "{...}" tokens render literally (unchanged).

.render_with <- function(doc) .render_to_string(doc)

.doc_tbl <- function(...,
                     tables = list(data.frame(A = 1L, B = "x",
                                              stringsAsFactors = FALSE))) {
  doc <- rtf_document()
  doc <- rtf_section(doc, page = 1, secinfo = list(header = NULL, footer = NULL))
  rtf_tables(doc, tables, ...)
}

test_that("title = NULL renders one blank centred table row (the default gap)", {
  txt <- .render_with(.doc_tbl())
  # A single-cell centred blank row, not a paragraph.
  expect_match(txt, "\\\\cellx[0-9]+\\\\qc\\\\li0\\\\ri0 \\\\cell")
})

test_that("title text renders as centred bold cells, one row per line", {
  txt <- .render_with(.doc_tbl(titles = list(c("Table 14.1.1", "Safety Population"))))
  expect_match(txt, "\\\\qc\\\\li0\\\\ri0 \\\\b Table 14\\.1\\.1\\\\b0 \\\\cell")
  expect_match(txt, "\\\\qc\\\\li0\\\\ri0 \\\\b Safety Population\\\\b0 \\\\cell")
})

test_that("an empty string within a title yields a blank row", {
  txt <- .render_with(.doc_tbl(titles = list(c("Table 14.1.1", "", "Safety Population"))))
  expect_match(txt, "Table 14\\.1\\.1")
  expect_match(txt, "Safety Population")
  expect_match(txt, "\\\\qc\\\\li0\\\\ri0 \\\\cell")   # the blank middle row
})

test_that("title = character(0) suppresses the title block entirely", {
  txt <- .render_with(.doc_tbl(titles = list(character(0))))
  expect_false(grepl("\\\\qc\\\\li0\\\\ri0 \\\\cell", txt))
})

test_that("footnote: top rule on the first row only; blank rows preserved", {
  txt <- .render_with(.doc_tbl(footnotes = list(c("Note 1: foo.", "", "Note 2: bar."))))
  # First row carries the separator top rule (left-aligned, top valign).
  expect_match(txt,
    "clbrdrt\\\\brdrs\\\\brdrw15\\\\clvertalt\\\\cellx[0-9]+\\\\ql\\\\li0\\\\ri0 Note 1: foo\\.")
  # A later row has no such rule.
  expect_match(txt, "\\\\clvertalt\\\\cellx[0-9]+\\\\ql\\\\li0\\\\ri0 Note 2: bar\\.")
})

test_that("legacy magic tokens render as literal text (no expansion)", {
  txt <- .render_with(.doc_tbl(titles = list("{HALF_BLANK_ROW}")))
  expect_match(txt, "\\\\\\{HALF_BLANK_ROW\\\\\\}")
})

# -- Common (length-1) recycling --------------------------------------------

test_that("a length-1 titles list in rtf_tables() is common to all pages", {
  df <- data.frame(A = 1L, B = "x", stringsAsFactors = FALSE)
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(df, df, df), titles = list("Common Title"))
  expect_length(doc$titles, 3L)
  expect_true(all(vapply(doc$titles, identical, logical(1), "Common Title")))
})

test_that("rtf_titles()/rtf_footnotes() accept length 1 (common) or length n", {
  df <- data.frame(A = 1L, B = "x", stringsAsFactors = FALSE)
  base <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(df, df))
  d1 <- rtf_titles(base, list("One For All"))
  expect_length(d1$titles, 2L)
  expect_identical(d1$titles[[1]], d1$titles[[2]])
  d2 <- rtf_footnotes(base, list("a", "b"))
  expect_identical(d2$footnotes[[2]], "b")
  expect_error(rtf_titles(base, list("x", "y", "z")), "length 2")
})

# -- Per-line styling -------------------------------------------------------

test_that("per-line styling sets align / bold / colour", {
  df <- data.frame(A = 1L, B = "x", stringsAsFactors = FALSE)
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(df), titles = list(list(
      list(text = "Left red", align = "left", bold = FALSE, color = "#C00000")
    )))
  txt <- .render_with(doc)
  # Left aligned, not bold, coloured (\cf with a non-reserved index >= 3).
  expect_match(txt, "\\\\ql\\\\li0\\\\ri0 \\\\cf[3-9][0-9]* Left red\\\\cf1")
  expect_false(grepl("\\\\b Left red", txt))   # not bold
})

test_that("a footnote row border overrides the default separator rule", {
  df <- data.frame(A = 1L, B = "x", stringsAsFactors = FALSE)
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(df), footnotes = list(list(
      list(text = "No rule", border = rtf_border())   # explicit empty border
    )))
  txt <- .render_with(doc)
  expect_match(txt, "\\\\clvertalt\\\\cellx[0-9]+\\\\ql\\\\li0\\\\ri0 No rule")
  expect_false(grepl(
    "clbrdrt\\\\brdrs\\\\brdrw15\\\\clvertalt\\\\cellx[0-9]+\\\\ql\\\\li0\\\\ri0 No rule",
    txt))
})

# -- Content-width matching -------------------------------------------------

test_that(".content_width_twips equals the table column total", {
  tbl   <- rtftable(data.frame(A = 1L, B = "x", C = "y", stringsAsFactors = FALSE))
  W     <- rtfreporter:::.in_to_twips(9)
  cw    <- rtfreporter:::.content_width_twips(tbl, W)
  cellx <- rtfreporter:::.compute_cellx(3L, W, tbl)
  expect_identical(cw, as.integer(cellx[3L]))
})

# -- col_spec default (kept) -------------------------------------------------

test_that("rtftable col_spec header_bold defaults to FALSE", {
  tbl <- rtftable(data.frame(A = 1L, B = "x", stringsAsFactors = FALSE))
  expect_false(tbl$col_spec[[1L]]$header_bold)
  expect_false(tbl$col_spec[[2L]]$header_bold)
})

test_that("rtf_header() rows treat legacy tokens as literal text", {
  df  <- data.frame(A = 1L, B = "x", stringsAsFactors = FALSE)
  doc <- rtf_document()
  doc <- rtf_section(doc, page = 1, secinfo = list(
    header = rtf_header(rows = list(
      c(l = "Protocol"),
      c(c = "{HALF_BLANK_ROW}"),
      c(l = "Below")
    )),
    footer = NULL
  ))
  doc <- rtf_tables(doc, list(df))
  txt <- .render_with(doc)
  expect_match(txt, "\\\\\\{HALF_BLANK_ROW\\\\\\}")
  expect_gte(length(gregexpr("\\\\trrh230\\b", txt)[[1L]]), 3L)
})

test_that("rtf_titles() and rtf_footnotes() set per-page titles/footnotes", {
  df  <- data.frame(A = 1L, B = "x", stringsAsFactors = FALSE)
  doc <- rtf_document()
  doc <- rtf_section(doc, page = 1, secinfo = list(header = NULL, footer = NULL))
  doc <- rtf_tables(doc, list(df, df))
  doc <- rtf_titles(doc, list("Page One", c("Page Two", "", "Subtitle")))
  doc <- rtf_footnotes(doc, list(NULL, "Footnote of page 2"))

  expect_length(doc$titles,    2L)
  expect_length(doc$footnotes, 2L)
  txt <- .render_with(doc)
  expect_match(txt, "Page One")
  expect_match(txt, "Page Two")
  expect_match(txt, "Footnote of page 2")
})
