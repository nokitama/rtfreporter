# Spanning-row alignment inherits from the level below.
#
# Resolution order for a spanning cell covering columns from..to:
#   1. sp$align                              (explicit override)
#   2. col_spec[[sp$from]]$header_align       (the level immediately below)
#   3. "center"                              (fallback)

library(devtools)
load_all(quiet = TRUE)
library(magrittr)

cat("\n=== spanning_header alignment inheritance ===\n\n")

df <- data.frame(
  Item   = "Age",
  A_N    = 30L,
  A_Mean = 45.2,
  B_N    = 30L,
  B_Mean = 46.1,
  stringsAsFactors = FALSE
)

gen <- function(tbl) {
  doc <- rtf_document() %>%
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) %>%
    rtf_tables(list(tbl))
  f <- tempfile(fileext = ".rtf")
  generate_rtfreport(doc, f, overwrite = TRUE)
  on.exit(unlink(f))
  paste(readLines(f, warn = FALSE), collapse = "\n")
}

# ── 1. Standalone spanning_header inherits from col_header (via col_spec) ──
# All numeric columns are right-aligned; the spanning cells over them should
# also be right-aligned by default.
tbl1 <- rtftable(df,
  col_header = c("Item", "N", "Mean", "N", "Mean"),
  col_spec   = list(
    list(col = 1, align = "left"),
    list(col = 2, align = "right"),
    list(col = 3, align = "right"),
    list(col = 4, align = "right"),
    list(col = 5, align = "right")
  ),
  spanning_header = list(
    list(from = 2, to = 3, label = "Drug A (N=30)", underline = TRUE),
    list(from = 4, to = 5, label = "Drug B (N=30)", underline = TRUE)
  ))
txt1 <- gen(tbl1)
# Spanning labels should be \qr (right) by inheritance
stopifnot(grepl("\\\\qr\\\\li72\\\\ri72 \\\\ul Drug A \\(N=30\\)", txt1))
stopifnot(grepl("\\\\qr\\\\li72\\\\ri72 \\\\ul Drug B \\(N=30\\)", txt1))
cat("OK  standalone spanning_header inherits right alignment from col_spec\n")

# ── 2. Spanning row inline inside col_header — same inheritance rule ──────
tbl2 <- rtftable(df,
  col_header = list(
    list(
      list(from = 2, to = 3, label = "Drug A", underline = TRUE),
      list(from = 4, to = 5, label = "Drug B", underline = TRUE)
    ),
    c("Item", "N", "Mean", "N", "Mean")
  ),
  col_spec = list(
    list(col = 1, align = "left"),
    list(col = 2, align = "right"),
    list(col = 3, align = "right"),
    list(col = 4, align = "right"),
    list(col = 5, align = "right")
  ))
txt2 <- gen(tbl2)
stopifnot(grepl("\\\\qr\\\\li72\\\\ri72 \\\\ul Drug A", txt2))
stopifnot(grepl("\\\\qr\\\\li72\\\\ri72 \\\\ul Drug B", txt2))
cat("OK  inline spanning row inside col_header inherits alignment\n")

# ── 3. Mixed alignments under one span → leftmost column wins ─────────────
df3 <- data.frame(Item = "X", L = "a", C = "b", R = 1L, stringsAsFactors = FALSE)
tbl3 <- rtftable(df3,
  col_header = c("Item", "L", "C", "R"),
  col_spec = list(
    list(col = 2, align = "left"),
    list(col = 3, align = "center"),
    list(col = 4, align = "right")
  ),
  spanning_header = list(
    list(from = 2, to = 4, label = "Mixed", underline = TRUE)
  ))
txt3 <- gen(tbl3)
# from = 2 → col_spec[[2]]$header_align = "left" (inherited from align)
stopifnot(grepl("\\\\ql\\\\li72\\\\ri72 \\\\ul Mixed", txt3))
cat("OK  spanning cell takes leftmost covered column's alignment\n")

# ── 4. Explicit sp$align overrides inheritance ────────────────────────────
tbl4 <- rtftable(df,
  col_header = c("Item", "N", "Mean", "N", "Mean"),
  col_spec   = list(
    list(col = 1, align = "left"),
    list(col = 2, align = "right"),
    list(col = 3, align = "right"),
    list(col = 4, align = "right"),
    list(col = 5, align = "right")
  ),
  spanning_header = list(
    list(from = 2, to = 3, label = "Forced Center", underline = TRUE,
         align = "center")
  ))
txt4 <- gen(tbl4)
stopifnot(grepl("\\\\qc\\\\li72\\\\ri72 \\\\ul Forced Center", txt4))
cat("OK  explicit sp$align overrides inheritance\n")

# ── 5. Fallback to center when col_spec is empty / NULL ───────────────────
df5 <- data.frame(a = 1L, b = 2L, c = 3L)
tbl5 <- rtftable(df5,
  spanning_header = list(
    list(from = 1, to = 3, label = "All", underline = TRUE)
  ))
# col_spec defaults to left align for all, header_align inherits → "left"
txt5 <- gen(tbl5)
stopifnot(grepl("\\\\ql\\\\li72\\\\ri72 \\\\ul All", txt5))
cat("OK  spanning inherits even when col_spec is not user-supplied\n")

cat("\n=== ALL SPANNING-ALIGN TESTS PASSED ===\n\n")
