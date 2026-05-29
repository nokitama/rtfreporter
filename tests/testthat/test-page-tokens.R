# Page-number token semantics in the rendered RTF.
#
# Spec recap:
#   {AUTO_PAGE}        -> \chpgn          (DYNAMIC; viewer renders per page)
#   {AUTO_TOTAL_PAGES} -> NUMPAGES field  (DYNAMIC; viewer recomputes)
#   {PAGE}             -> integer literal (STATIC; baked in at render time
#                                          = section's first-page number)
#   {TOTAL_PAGES}      -> integer literal (STATIC; baked in at render time
#                                          = document total page count)

.render_doc_for_token_test <- function(rows, n_pages = 1L) {
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(
      header = rtf_header(rows = rows),
      footer = NULL
    )) |>
    rtf_tables(replicate(n_pages,
                          data.frame(A = 1L, B = "x", stringsAsFactors = FALSE),
                          simplify = FALSE))
  f <- tempfile(fileext = ".rtf")
  generate_rtfreport(doc, f, overwrite = TRUE)
  paste(readLines(f, warn = FALSE), collapse = "\n")
}

# ──────── {AUTO_PAGE} — dynamic ────────────────────────────────────────────

test_that("{AUTO_PAGE} resolves to RTF \\chpgn (dynamic per-page number)", {
  txt <- .render_doc_for_token_test(
    list(c(l = "X", r = "P {AUTO_PAGE}"))
  )
  expect_match(txt, "\\\\chpgn")
  # The literal token must NOT appear in the output
  expect_false(grepl("\\{AUTO_PAGE\\}", txt))
})

# ──────── {AUTO_TOTAL_PAGES} — dynamic NUMPAGES field ─────────────────────

test_that("{AUTO_TOTAL_PAGES} resolves to a NUMPAGES field", {
  txt <- .render_doc_for_token_test(
    list(c(l = "X", r = "P / {AUTO_TOTAL_PAGES}"))
  )
  expect_match(txt, "NUMPAGES")
  expect_false(grepl("\\{AUTO_TOTAL_PAGES\\}", txt))
})

# ──────── {PAGE} — STATIC integer (BUG FIX in v0.0.32) ─────────────────────

test_that("{PAGE} bakes the section's first-page number as a literal integer", {
  # Single section, first page = 1.  Expect literal "1" in the header text.
  txt <- .render_doc_for_token_test(
    list(c(l = "X", r = "Page {PAGE}"))
  )
  # The dynamic RTF field MUST NOT appear for this token.
  expect_false(grepl("\\\\chpgn", txt))
  # Literal "Page 1" must appear (after escaping the space is preserved
  # in the cell content of the header table).
  expect_match(txt, "Page 1")
  expect_false(grepl("\\{PAGE\\}", txt))
})

test_that("{PAGE} and {TOTAL_PAGES} produce the documented 'Page N of M' literal", {
  # 3 sub-pages -> document total = 3.  Section first-page = 1.
  txt <- .render_doc_for_token_test(
    list(c(l = "X", r = "Page {PAGE} of {TOTAL_PAGES}")),
    n_pages = 3L
  )
  expect_match(txt, "Page 1 of 3")
  # Neither token shall leave its literal text behind
  expect_false(grepl("\\{PAGE\\}",        txt))
  expect_false(grepl("\\{TOTAL_PAGES\\}", txt))
  # And no dynamic field code for these static tokens
  expect_false(grepl("\\\\chpgn",         txt))
})

# ──────── {TOTAL_PAGES} — STATIC integer ───────────────────────────────────

test_that("{TOTAL_PAGES} alone resolves to a literal integer", {
  txt <- .render_doc_for_token_test(
    list(c(l = "X", r = "Total: {TOTAL_PAGES}")),
    n_pages = 5L
  )
  expect_match(txt, "Total: 5")
})

# ──────── Side-by-side: {PAGE} static vs {AUTO_PAGE} dynamic ──────────────

test_that("{PAGE} and {AUTO_PAGE} are DIFFERENT (static vs dynamic)", {
  txt <- .render_doc_for_token_test(
    list(c(l = "X", r = "static={PAGE} auto={AUTO_PAGE}")),
    n_pages = 2L
  )
  # The static side becomes literal "static=1"
  expect_match(txt, "static=1")
  # The dynamic side becomes \chpgn (NOT a literal "1")
  # — we should see the \chpgn token somewhere right of "auto="
  # (more robustly, the dynamic field is present in the output)
  expect_match(txt, "\\\\chpgn")
})
