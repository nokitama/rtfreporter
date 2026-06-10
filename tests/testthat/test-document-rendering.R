# Document-level rendering contracts promised by the page-setup article:
# font_table / color_table / default font size must flow into the generated RTF.
# (Row-height cascade, named-list pagination, and orientation are covered in
# test-default-row-height.R / test-as-rtftables.R / test-page-orientation.R.)

.simple_doc <- function(...) {
  df <- data.frame(A = c("1", "2"), B = c("x", "y"), stringsAsFactors = FALSE)
  rtf_document(...) |>
    rtf_tables(as_rtftables(df))
}

test_that("a custom font_table font is written into the RTF \\fonttbl", {
  txt <- .render_to_string(.simple_doc(font_table = list(list(name = "Arial"))))
  expect_match(txt, "\\\\fonttbl")
  expect_match(txt, "Arial")
})

test_that("the default font is Courier when font_table is not set", {
  expect_match(.render_to_string(.simple_doc()), "Courier")
})

test_that("border colours are auto-collected into the RTF \\colortbl", {
  # The rendered palette is built from the BORDER colours actually used in the
  # report (the document `color_table` argument is not consumed by the
  # renderer -- see #36). A coloured border injects its colour into \colortbl.
  df  <- data.frame(A = c("1", "2"), B = c("x", "y"), stringsAsFactors = FALSE)
  hdr <- rtf_header(rows = list(c(l = "X")),
                    border = rtf_border(bottom = rtf_border_side(color = "#1F4E79")))
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = hdr, footer = NULL)) |>
    rtf_tables(as_rtftables(df))
  txt <- .render_to_string(doc)
  expect_match(txt, "\\\\colortbl")
  # #1F4E79 = rgb(31, 78, 121)
  expect_match(txt, "\\\\red31\\\\green78\\\\blue121")
})

test_that("the document font size is emitted as a document-level \\fs<n>", {
  txt22 <- .render_to_string(
    .simple_doc(default_format = list(font_size_half_points = 22L)))
  expect_match(txt22, "\\\\fs22\\b")

  # Default is 9pt = \fs18.
  expect_match(.render_to_string(.simple_doc()), "\\\\fs18\\b")
})
