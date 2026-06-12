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

# Orientation normalizes the page dimensions (#106) -------------------------

test_that("orientation = landscape puts the long side on the width (#106)", {
  # A4 *portrait* dimensions passed with orientation = "landscape" should yield
  # a landscape (wide) page, not a tall one.
  rtf <- .gen(.doc_with(list(orientation = "landscape",
                             width_in = 8.27, height_in = 11.69)))
  expect_true(grepl("\\paperw16834", rtf))   # 11.69in -> width (long side)
  expect_true(grepl("\\paperh11909", rtf))   #  8.27in -> height (short side)
  expect_true(grepl("\\landscape", rtf))
})

test_that("orientation = portrait puts the long side on the height (#106)", {
  rtf <- .gen(.doc_with(list(orientation = "portrait",
                             width_in = 11.69, height_in = 8.27)))
  expect_true(grepl("\\paperw11909", rtf))   #  8.27in -> width (short side)
  expect_true(grepl("\\paperh16834", rtf))   # 11.69in -> height (long side)
  expect_false(grepl("\\landscape", rtf))
})

test_that("omitted orientation is inferred from the dimensions (#106)", {
  tall <- .gen(.doc_with(list(width_in = 8.27, height_in = 11.69)))
  expect_false(grepl("\\landscape", tall))   # taller than wide -> portrait
  wide <- .gen(.doc_with(list(width_in = 11.69, height_in = 8.27)))
  expect_true(grepl("\\landscape", wide))    # wider than tall -> landscape
})

test_that("an invalid orientation is rejected (#106)", {
  expect_error(.gen(.doc_with(list(orientation = "diagonal"))),
               "must be .landscape. or .portrait.")
})
