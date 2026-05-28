# assemble_rtf.R -- concatenate multiple rtfreporter-generated RTFs.

.write_demo_rtf <- function(title) {
  doc <- rtf_document()
  doc <- rtf_section(doc, page = 1, secinfo = list(
    header = rtf_header(rows = list(
      c(l = "Protocol RTF-101", r = "Page {AUTO_PAGE} of {AUTO_TOTAL_PAGES}")
    )),
    footer = rtf_footer(c(c = "Confidential"))
  ))
  doc <- rtf_tables(doc, list(
    data.frame(A = 1:2, B = c("x", "y"), stringsAsFactors = FALSE)
  ), titles = list(c(title)))
  f <- tempfile(fileext = ".rtf")
  generate_rtfreport(doc, f, overwrite = TRUE)
  f
}

test_that("assemble_rtf() concatenates 2 files into one document with \\sect breaks", {
  f1 <- .write_demo_rtf("Table 14.1.1")
  f2 <- .write_demo_rtf("Table 14.2.1")
  on.exit({ unlink(c(f1, f2)) }, add = TRUE)

  out <- tempfile(fileext = ".rtf")
  on.exit(unlink(out), add = TRUE)

  expect_invisible(assemble_rtf(c(f1, f2), out, overwrite = TRUE))
  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 0L)

  lines <- readLines(out, warn = FALSE)
  joined <- paste(lines, collapse = "\n")
  # Both source titles appear in the assembled output
  expect_match(joined, "Table 14\\.1\\.1")
  expect_match(joined, "Table 14\\.2\\.1")
  # Exactly one inter-section break (between the two source files)
  expect_identical(sum(grepl("^\\\\sect$", lines)), 1L)
  # Document still ends with a single closing "}"
  expect_identical(trimws(tail(lines, 1)), "}")
})

test_that("assemble_rtf() concatenates more than 2 files", {
  fs <- vapply(1:3, function(i) .write_demo_rtf(sprintf("T %d", i)),
               character(1L))
  on.exit(unlink(fs), add = TRUE)
  out <- tempfile(fileext = ".rtf"); on.exit(unlink(out), add = TRUE)
  assemble_rtf(fs, out, overwrite = TRUE)
  lines <- readLines(out, warn = FALSE)
  # N - 1 section breaks between N source files
  expect_identical(sum(grepl("^\\\\sect$", lines)), 2L)
})

test_that("assemble_rtf() requires at least 2 input files", {
  expect_error(assemble_rtf(character(0), tempfile()),
               "at least 2")
  expect_error(assemble_rtf("only_one.rtf", tempfile()),
               "at least 2")
})

test_that("assemble_rtf() errors if any input file does not exist", {
  f1 <- .write_demo_rtf("X"); on.exit(unlink(f1), add = TRUE)
  expect_error(
    assemble_rtf(c(f1, "/no/such/file.rtf"), tempfile()),
    "not found")
})

test_that("assemble_rtf() refuses to overwrite without overwrite = TRUE", {
  f1 <- .write_demo_rtf("A"); f2 <- .write_demo_rtf("B")
  on.exit(unlink(c(f1, f2)), add = TRUE)
  out <- tempfile(fileext = ".rtf"); on.exit(unlink(out), add = TRUE)
  assemble_rtf(c(f1, f2), out, overwrite = TRUE)
  expect_error(assemble_rtf(c(f1, f2), out), "already exists")
})

test_that("assemble_rtf() refuses non-rtfreporter RTFs (missing \\sectd)", {
  fake <- tempfile(fileext = ".rtf"); on.exit(unlink(fake), add = TRUE)
  writeLines(c("{\\rtf1\\ansi", "Hello world.", "}"), fake)
  f1  <- .write_demo_rtf("Real");  on.exit(unlink(f1), add = TRUE)
  out <- tempfile(fileext = ".rtf"); on.exit(unlink(out), add = TRUE)
  expect_error(assemble_rtf(c(f1, fake), out, overwrite = TRUE),
               "sectd")
})
