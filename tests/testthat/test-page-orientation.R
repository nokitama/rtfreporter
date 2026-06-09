# Page orientation: the document-level \landscape must follow the orientation
# setting (regression test for the hardcoded \landscape, issue #31).

.gen <- function(doc) {
  f <- tempfile(fileext = ".rtf")
  on.exit(unlink(f), add = TRUE)
  generate_rtfreport(doc, f, overwrite = TRUE)
  paste(readLines(f, warn = FALSE), collapse = "\n")
}

.doc_with <- function(page) {
  rtf_document(page = page) |>
    rtf_tables(as_rtftables(data.frame(a = "1", b = "2",
                                       stringsAsFactors = FALSE)))
}

test_that("the default (landscape) document emits \\landscape", {
  expect_true(grepl("\\\\landscape", .gen(.doc_with(NULL))))
})

test_that("a portrait document emits no document-level \\landscape", {
  rtf <- .gen(.doc_with(list(
    orientation = "portrait",
    width_in = 8.5, height_in = 11,
    margin_top_in = 1, margin_bottom_in = 1,
    margin_left_in = 1, margin_right_in = 1
  )))
  expect_false(grepl("\\\\landscape", rtf))
  # Portrait page dimensions are still written.
  expect_true(grepl("\\\\paperw12240", rtf))   # 8.5in
  expect_true(grepl("\\\\paperh15840", rtf))   # 11in
})

test_that("an explicit landscape document still emits \\landscape", {
  rtf <- .gen(.doc_with(list(orientation = "landscape")))
  expect_true(grepl("\\\\landscape", rtf))
})
