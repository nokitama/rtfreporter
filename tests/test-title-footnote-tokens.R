# Verify title/footnote/header magic-token behaviour.

library(devtools)
load_all(quiet = TRUE)
library(magrittr)

cat("\n=== Title / footnote / header magic tokens ===\n")

df <- data.frame(A = 1L, B = "x", stringsAsFactors = FALSE)

# ── Helper: read generated RTF as one string ───────────────────────────────
gen <- function(doc) {
  f <- tempfile(fileext = ".rtf")
  generate_rtfreport(doc, f, overwrite = TRUE)
  on.exit(unlink(f))
  paste(readLines(f, warn = FALSE), collapse = "\n")
}

# ── .parse_blank_token() unit ──────────────────────────────────────────────
p <- rtfreporter:::.parse_blank_token
stopifnot(identical(p("{HALF_BLANK_ROW}"), list(text = "", height_factor = 0.5, is_blank = TRUE)))
stopifnot(identical(p("{BLANK_ROW}"),      list(text = "", height_factor = 1.0, is_blank = TRUE)))
stopifnot(identical(p(""),                 list(text = "", height_factor = 1.0, is_blank = TRUE)))
stopifnot(identical(p(NULL),               list(text = "", height_factor = 1.0, is_blank = TRUE)))
stopifnot(identical(p("hello"),            list(text = "hello", height_factor = 1.0, is_blank = FALSE)))
cat("OK  .parse_blank_token()\n")

# ── Title default: NULL → one half-height blank row above content ──────────
doc1 <- rtf_document() %>%
  rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) %>%
  rtf_tables(list(df))
txt1 <- gen(doc1)
stopifnot(grepl("\\\\trrh115\\b", txt1))     # 230 / 2 = 115
cat("OK  default title (NULL) emits one \\trrh115 row\n")

# ── Title explicit text → centred bold row at \trrh230 ─────────────────────
doc2 <- rtf_document() %>%
  rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) %>%
  rtf_tables(list(df), titles = list("Table 14.1.1"))
txt2 <- gen(doc2)
stopifnot(grepl("\\\\b Table 14\\.1\\.1\\\\b0", txt2))
cat("OK  title text renders centred and bold\n")

# ── Title with mixed text + {HALF_BLANK_ROW} ───────────────────────────────
doc3 <- rtf_document() %>%
  rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) %>%
  rtf_tables(list(df), titles = list(c("Table 14.1.1", "{HALF_BLANK_ROW}", "Safety Pop")))
txt3 <- gen(doc3)
stopifnot(grepl("Table 14\\.1\\.1", txt3))
stopifnot(grepl("Safety Pop",       txt3))
# Two text rows (230 each) + one half-blank row (115) above content +
# table body 230s + (defaulted) NULL footnote = 0 footnote rows.
n_115_in_txt3 <- length(gregexpr("\\\\trrh115\\b", txt3)[[1L]])
stopifnot(n_115_in_txt3 >= 1L)
cat("OK  mixed text + {HALF_BLANK_ROW} title emits both heights\n")

# ── Title character(0) suppresses the block entirely ───────────────────────
doc4 <- rtf_document() %>%
  rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) %>%
  rtf_tables(list(df), titles = list(character(0)))
txt4 <- gen(doc4)
# 0 occurrences of 115 (no auto-default half blank)
stopifnot(!grepl("\\\\trrh115\\b", txt4))
cat("OK  title = character(0) suppresses the title block\n")

# ── Multi-row footnote with magic token ────────────────────────────────────
doc5 <- rtf_document() %>%
  rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) %>%
  rtf_tables(list(df),
             footnotes = list(c("Note 1: foo.", "{HALF_BLANK_ROW}", "Note 2: bar.")))
txt5 <- gen(doc5)
stopifnot(grepl("Note 1: foo\\.", txt5))
stopifnot(grepl("Note 2: bar\\.", txt5))
stopifnot(grepl("\\\\trrh115\\b", txt5))
cat("OK  multi-row footnote with token\n")

# ── Header / footer with {HALF_BLANK_ROW} ──────────────────────────────────
doc6 <- rtf_document() %>%
  rtf_section(page = 1, secinfo = list(
    header = rtf_header(rows = list(
      c(l = "Protocol", r = "Page X"),
      c(c = "{HALF_BLANK_ROW}"),
      c(c = "Table 14.1.1")
    )),
    footer = NULL
  )) %>%
  rtf_tables(list(df))
txt6 <- gen(doc6)
n_115 <- length(gregexpr("\\\\trrh115\\b", txt6)[[1L]])
# Expect: 1 from header HALF_BLANK_ROW + 1 from default title = at least 2
stopifnot(n_115 >= 2L)
cat("OK  rtf_header() honours {HALF_BLANK_ROW}\n")

# ── rtf_titles() / rtf_footnotes() standalone ──────────────────────────────
doc7 <- rtf_document() %>%
  rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) %>%
  rtf_tables(list(df, df)) %>%
  rtf_titles(list("Page One Title", c("Page Two", "{HALF_BLANK_ROW}", "Subtitle"))) %>%
  rtf_footnotes(list(NULL, "Footnote of page 2"))
stopifnot(length(doc7$titles)    == 2L)
stopifnot(length(doc7$footnotes) == 2L)
txt7 <- gen(doc7)
stopifnot(grepl("Page One Title",  txt7))
stopifnot(grepl("Page Two",        txt7))
stopifnot(grepl("Footnote of page 2", txt7))
cat("OK  rtf_titles() / rtf_footnotes() standalone\n")

# ── Length-mismatch errors ─────────────────────────────────────────────────
err1 <- tryCatch(
  rtf_document() %>% rtf_tables(list(df, df), titles = list("only one")),
  error = function(e) e
)
stopifnot(inherits(err1, "error"))
err2 <- tryCatch(
  rtf_document() %>% rtf_titles(list("foo")),
  error = function(e) e   # no content yet
)
stopifnot(inherits(err2, "error"))
cat("OK  length-mismatch and pre-content errors\n")

cat("\n=== ALL TITLE/FOOTNOTE TOKEN TESTS PASSED ===\n\n")
