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

# Explicit dimensions win; orientation is inferred (#110, supersedes #106) ---

test_that("explicit dimensions are used as given; orientation is inferred (#110)", {
  # A4 *portrait* dimensions are kept as given -> a tall (portrait) page.
  rtf <- .gen(.doc_with(list(width_in = 8.27, height_in = 11.69)))
  expect_true(grepl("\\paperw11909", rtf))   #  8.27in -> width (as given)
  expect_true(grepl("\\paperh16834", rtf))   # 11.69in -> height (as given)
  expect_false(grepl("\\landscape", rtf))    # taller than wide -> portrait
})

test_that("an orientation that contradicts the dimensions warns and is ignored (#110)", {
  expect_warning(
    rtf <- .gen(.doc_with(list(orientation = "landscape",
                               width_in = 8.27, height_in = 11.69))),
    "contradicts the given dimensions"
  )
  # Dimensions are kept as given (NOT swapped): still portrait.
  expect_true(grepl("\\paperw11909", rtf))
  expect_true(grepl("\\paperh16834", rtf))
  expect_false(grepl("\\landscape", rtf))
})

# paper_size presets (#110) --------------------------------------------------

test_that("paper_size = \"A4\" gives A4 landscape in one line (#110)", {
  rtf <- .gen(.doc_with(list(paper_size = "A4")))
  expect_true(grepl("\\paperw16838", rtf))   # 11.6929in -> width (long side)
  expect_true(grepl("\\paperh11905", rtf))   #  8.2677in -> height (short side)
  expect_true(grepl("\\landscape", rtf))
})

test_that("paper_size is case-insensitive and orientation orients it (#110)", {
  rtf <- .gen(.doc_with(list(paper_size = "a4", orientation = "portrait")))
  expect_true(grepl("\\paperw11905", rtf))   #  8.2677in -> width (short side)
  expect_true(grepl("\\paperh16838", rtf))   # 11.6929in -> height (long side)
  expect_false(grepl("\\landscape", rtf))
})

test_that("an unknown paper_size is rejected (#110)", {
  expect_error(.gen(.doc_with(list(paper_size = "tabloid"))),
               "Unknown .paper_size")
})

test_that("paper_size alongside explicit dimensions is ignored with a warning (#110)", {
  expect_warning(
    rtf <- .gen(.doc_with(list(paper_size = "A4",
                               width_in = 8.5, height_in = 11))),
    "explicit dimensions take precedence"
  )
  expect_true(grepl("\\paperw12240", rtf))   # 8.5in (the explicit dims win)
  expect_true(grepl("\\paperh15840", rtf))   # 11in
})

test_that("omitted orientation is inferred from the dimensions (#110)", {
  tall <- .gen(.doc_with(list(width_in = 8.27, height_in = 11.69)))
  expect_false(grepl("\\landscape", tall))   # taller than wide -> portrait
  wide <- .gen(.doc_with(list(width_in = 11.69, height_in = 8.27)))
  expect_true(grepl("\\landscape", wide))    # wider than tall -> landscape
})

test_that("an invalid orientation is rejected (#106)", {
  expect_error(.gen(.doc_with(list(orientation = "diagonal"))),
               "must be .landscape. or .portrait.")
})
