## tests/testthat/test-combine-sections.R
##
## combine_sections(): assemble named rtftable page lists into one flat,
## auto_section-ready list (first page of each argument named, the rest blanked
## so they fall through into the same RTF section).

library(testthat)

# A trivial single-page rtftable.
.one <- function(v = "x") as_rtftable(data.frame(a = v, stringsAsFactors = FALSE))
# A k-"page" list of rtftables.
.pages <- function(k) lapply(seq_len(k), function(i) .one(as.character(i)))

test_that("combine_sections() names the first page and blanks the rest", {
  s <- combine_sections(Foo = .pages(3L))
  expect_length(s, 3L)
  expect_identical(names(s), c("Foo", "", ""))
  expect_true(all(vapply(s, inherits, logical(1L), "rtftable")))
})

test_that("combine_sections() concatenates several tables, one label each", {
  s <- combine_sections(A = .pages(2L), B = .one(), `C D` = .pages(2L))
  expect_length(s, 5L)
  expect_identical(names(s), c("A", "", "B", "C D", ""))
})

test_that("a bare rtftable argument is treated as a one-page section", {
  s <- combine_sections(Solo = .one())
  expect_length(s, 1L)
  expect_identical(names(s), "Solo")
})

test_that("an unnamed argument falls through (all pages blank)", {
  s <- combine_sections(A = .one(), .pages(2L))
  expect_identical(names(s), c("A", "", ""))
})

test_that("combine_sections() validates its inputs", {
  expect_error(combine_sections(A = list(1, 2)),
               "must contain only rtftable")
  expect_error(combine_sections(A = 42),
               "must be an rtftable or a list")
})

test_that("empty / zero-length arguments are handled", {
  expect_identical(combine_sections(), list())
  s <- combine_sections(A = list(), B = .one())   # empty group skipped
  expect_identical(names(s), "B")
})

test_that("the result drives auto_section: one section per argument", {
  s   <- combine_sections(Demographics = .pages(3L), `Adverse Events` = .pages(2L))
  doc <- rtf_document() |>
    rtf_section(secinfo = list(header = rtf_header(rows = list(c(l = "Study"))))) |>
    rtf_tables(s, auto_section = TRUE)
  rep <- rtfreporter:::.pipe_doc_to_rtfreport(doc)
  expect_equal(length(rep$sections), 2L)            # not 5 (one per page)
})
