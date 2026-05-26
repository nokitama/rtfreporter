# Verify font-size-aware default row height is applied uniformly across all
# table-shaped elements (RTF header, footer, table body, footnote).

library(devtools)
load_all(quiet = TRUE)
library(magrittr)

cat("\n=== Default row-height unification ===\n")

# ── Helper resolution ───────────────────────────────────────────────────────
stopifnot(rtfreporter:::.default_row_height_twips(18L) == 230L)  # 9pt
stopifnot(rtfreporter:::.default_row_height_twips(24L) == 290L)  # 12pt
# Out-of-table → linear fallback + min clamp
stopifnot(rtfreporter:::.default_row_height_twips(40L) == round(40 * 12.8))
# Below the min → clamped
stopifnot(rtfreporter:::.default_row_height_twips(2L)  == 180L)
cat("OK  .default_row_height_twips() lookup, fallback, and clamp\n")

# ── End-to-end RTF generation: header, body, footnote all use 230 ───────────
df <- data.frame(A = 1:2, B = c("x", "y"), stringsAsFactors = FALSE)

doc <- rtf_document() %>%                      # 9pt default font
  rtf_section(page = 1, secinfo = list(
    header = rtf_header(rows = list(c(l = "TITLE", r = "Page {AUTO_PAGE}"))),
    footer = rtf_footer(rows = list(c(c = "FOOTER")))
  )) %>%
  rtf_tables(list(df))                          # no explicit row_height_twips

# Attach a footnote to page 1 by reaching into the report:
r6 <- rtfreporter:::.pipe_doc_to_r6_report(doc)
r6$set_page_footnote(1L, "Note: example.")

tmp <- tempfile(fileext = ".rtf")
generate_rtfreport(r6, tmp, overwrite = TRUE)

txt <- paste(readLines(tmp, warn = FALSE), collapse = "\n")

# Count occurrences of "\trrh230" — header row, footer row, table rows,
# footnote row should ALL emit it.
n_230 <- length(gregexpr("\\\\trrh230\\b", txt)[[1L]])
stopifnot(n_230 >= 4L)   # at least 1 header + 1 footer + 2 body + 1 footnote
cat(sprintf("OK  generated RTF contains %d occurrences of \\trrh230\n", n_230))

# No occurrence of the old 360 default.
stopifnot(!grepl("\\\\trrh360\\b", txt))
cat("OK  no stale \\trrh360 in output\n")

unlink(tmp)

# ── Per-element override still works ────────────────────────────────────────
doc2 <- rtf_document() %>%
  rtf_section(page = 1, secinfo = list(
    header = rtf_header(rows = list(c(l = "T")), row_height_twips = 500L),
    footer = rtf_footer(rows = list(c(l = "F")), row_height_twips = 400L)
  )) %>%
  rtf_tables(list(df), row_height_twips = 320L)

tmp2 <- tempfile(fileext = ".rtf")
generate_rtfreport(doc2, tmp2, overwrite = TRUE)
txt2 <- paste(readLines(tmp2, warn = FALSE), collapse = "\n")

stopifnot(grepl("\\\\trrh500\\b", txt2))
stopifnot(grepl("\\\\trrh400\\b", txt2))
stopifnot(grepl("\\\\trrh320\\b", txt2))
cat("OK  per-element overrides emitted (500 header, 400 footer, 320 body)\n")
unlink(tmp2)

# ── Larger font size shifts the default upward ──────────────────────────────
doc3 <- rtf_document(default_format = list(font_size_half_points = 24L)) %>%
  rtf_section(page = 1, secinfo = list(
    header = rtf_header(rows = list(c(l = "T")))
  )) %>%
  rtf_tables(list(df))

tmp3 <- tempfile(fileext = ".rtf")
generate_rtfreport(doc3, tmp3, overwrite = TRUE)
txt3 <- paste(readLines(tmp3, warn = FALSE), collapse = "\n")

stopifnot(grepl("\\\\trrh290\\b", txt3))   # 12pt → 290
stopifnot(!grepl("\\\\trrh230\\b", txt3))  # no leftover 9pt default
cat("OK  font_size 24 (12pt) shifts default to 290 across all elements\n")
unlink(tmp3)

cat("\n=== ALL DEFAULT-ROW-HEIGHT TESTS PASSED ===\n\n")
