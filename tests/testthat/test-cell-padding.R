# Header/footer and content cells inherit the same cell padding default
# (0 twips left/right since v0.0.21); per-block overrides win.

test_that("default header/footer cells emit \\li0\\ri0 like content cells", {
  df <- data.frame(A = 1L, B = "x", stringsAsFactors = FALSE)
  doc <- rtf_document()
  doc <- rtf_section(doc, page = 1, secinfo = list(
    header = rtf_header(rows = list(c(l = "LEFT", r = "RIGHT"))),
    footer = rtf_footer(rows = list(c = "FOOT"))
  ))
  doc <- rtf_tables(doc, list(df))

  txt <- .render_to_string(doc)
  expect_match(txt, "\\\\ql\\\\li0\\\\ri0 LEFT")
  expect_match(txt, "\\\\qr\\\\li0\\\\ri0 RIGHT")
  expect_match(txt, "\\\\qc\\\\li0\\\\ri0 FOOT")
})

test_that("rtf_header(cell_padding_*_twips) overrides the defaults", {
  df <- data.frame(A = 1L, B = "x", stringsAsFactors = FALSE)
  doc <- rtf_document()
  doc <- rtf_section(doc, page = 1, secinfo = list(
    header = rtf_header(rows = list(c(l = "LEFT", r = "RIGHT")),
                        cell_padding_left_twips  = 144L,
                        cell_padding_right_twips = 36L),
    footer = NULL
  ))
  doc <- rtf_tables(doc, list(df))

  txt <- .render_to_string(doc)
  expect_match(txt, "\\\\ql\\\\li144\\\\ri36 LEFT")
  expect_match(txt, "\\\\qr\\\\li144\\\\ri36 RIGHT")
})

test_that("empty header cells still carry the cell padding", {
  df <- data.frame(A = 1L, B = "x", stringsAsFactors = FALSE)
  doc <- rtf_document()
  doc <- rtf_section(doc, page = 1, secinfo = list(
    header = rtf_header(rows = list(
      c(l = "Top"), c(c = ""), c(l = "Below")
    )),
    footer = NULL
  ))
  doc <- rtf_tables(doc, list(df))

  txt <- .render_to_string(doc)
  expect_match(txt, "\\\\ql\\\\li0\\\\ri0 Top")
  expect_match(txt, "\\\\ql\\\\li0\\\\ri0 Below")
  expect_match(txt, "\\\\qc\\\\li0\\\\ri0 \\\\cell")
})

test_that("rtftable() with explicit cell_padding_*_twips still emits the requested values", {
  df  <- data.frame(A = 1L, B = "x", stringsAsFactors = FALSE)
  tbl <- rtftable(df, cell_padding_left_twips = 72L,
                   cell_padding_right_twips  = 72L)
  doc <- rtf_document()
  doc <- rtf_section(doc, page = 1, secinfo = list(header = NULL, footer = NULL))
  doc <- rtf_tables(doc, list(tbl))
  txt <- .render_to_string(doc)
  expect_match(txt, "\\\\li72\\\\ri72")
})

test_that("resource file exposes the documented default cell-padding values", {
  defaults <- rtfreporter:::.load_rtfreporter_defaults()
  expect_identical(defaults$default_cell_padding_left_twips,  0L)
  expect_identical(defaults$default_cell_padding_right_twips, 0L)
})
