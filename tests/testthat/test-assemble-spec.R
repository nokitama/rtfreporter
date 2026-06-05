# Helpers around assemble_rtf(): assemble_files / _spec / _toc / _from_spec /
# _folder.

# A minimal rtfreporter RTF whose header carries a "Table N  <title>" line.
.make_tbl_rtf <- function(dir, file, table_no, title) {
  doc <- rtf_document()
  doc <- rtf_section(doc, page = 1, secinfo = list(
    header = rtf_header(rows = list(
      c(l = "Co", r = "Page {PAGE} of {TOTAL_PAGES}"),
      c(c = paste0("Table ", table_no)),
      c(c = title))),
    footer = rtf_footer(c(c = "Confidential"))))
  doc <- rtf_tables(doc, list(
    data.frame(A = 1:2, B = c("x", "y"), stringsAsFactors = FALSE)))
  f <- file.path(dir, file)
  generate_rtfreport(doc, f, overwrite = TRUE)
  f
}

.demo_dir <- function() {
  d <- tempfile("asm"); dir.create(d)
  .make_tbl_rtf(d, "t_14_3_1.rtf", "14.3.1", "Adverse Events")
  .make_tbl_rtf(d, "t_14_1_1.rtf", "14.1.1", "Demographics")
  d
}

test_that("assemble_files lists rtf files in natural order", {
  d <- .demo_dir()
  files <- assemble_files(d)
  expect_length(files, 2L)
  expect_true(all(grepl("[.]rtf$", files)))
})

test_that("assemble_spec reads table number + title from the header, ordered by table", {
  d <- .demo_dir()
  sp <- assemble_spec(d)
  expect_s3_class(sp, "data.frame")
  expect_setequal(c("order", "file", "table", "heading", "label", "level", "pages"),
                  names(sp))
  # default order is by table number: 14.1.1 before 14.3.1
  expect_equal(sp$table, c("14.1.1", "14.3.1"))
  expect_match(sp$label[1L], "Table 14.1.1  Demographics")
  expect_equal(sp$pages, c(1L, 1L))
})

test_that("assemble_toc builds toc_entry objects from files", {
  d <- .demo_dir()
  toc <- assemble_toc(files = assemble_files(d))
  expect_true(all(vapply(toc, inherits, logical(1L), "rtf_toc_entry")))
  expect_length(toc, 2L)
})

test_that("assemble_spec headings become toc_heading() rows", {
  d <- .demo_dir()
  sp <- assemble_spec(d)
  sp$heading <- ifelse(grepl("^14[.]1", sp$table), "DEMOG", "SAFETY")
  toc <- rtfreporter:::.spec_to_toc(sp)
  kinds <- vapply(toc, function(e) class(e)[1L], character(1L))
  expect_identical(kinds,
                   c("rtf_toc_heading", "rtf_toc_entry",
                     "rtf_toc_heading", "rtf_toc_entry"))
})

test_that("assemble_from_spec writes an assembled file with a TOC", {
  d   <- .demo_dir()
  sp  <- assemble_spec(d)
  out <- tempfile(fileext = ".rtf")
  assemble_from_spec(sp, out, overwrite = TRUE)
  expect_true(file.exists(out))
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(txt, "Table of Contents")
  expect_match(txt, "PAGEREF")
})

test_that("assemble_folder does the whole thing and can save a CSV spec", {
  d   <- .demo_dir()
  out <- tempfile(fileext = ".rtf")
  sf  <- tempfile(fileext = ".csv")
  res <- assemble_folder(d, out, spec_file = sf, overwrite = TRUE)
  expect_true(file.exists(out))
  expect_true(file.exists(sf))
  expect_s3_class(res$spec, "data.frame")
  expect_equal(nrow(res$spec), 2L)
  # without spec_file the spec stays in memory only
  out2 <- tempfile(fileext = ".rtf")
  res2 <- assemble_folder(d, out2, overwrite = TRUE)
  expect_true(file.exists(out2))
})
