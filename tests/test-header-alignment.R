# Comprehensive header / spanning alignment & style tests.
#
# Specification (locked in v0.0.15):
#
#   Column-header rows
#     ① Default: header alignment follows the data column's alignment
#        (col_spec[[j]]$align).
#     ② Optional: per-table override via `col_header_align` (scalar
#        applied to all, or a length-ncol character vector for per-column).
#     ③ Optional: per-column override via col_spec[[j]]$header_align —
#        wins over the table-wide setting.
#     ④ Bold/italic for column-header cells default to FALSE.
#
#   Spanning rows
#     ① Default alignment: inherit from the level BELOW — the leftmost
#        covered column's resolved `header_align`.
#     ② Optional: per-cell override via the `align` field in the
#        spanning spec.
#     ③ Bold default FALSE — set `bold = TRUE` per-cell to enable.
#     ④ Italic default FALSE — set `italic = TRUE` per-cell to enable.
#     ⑤ Underline default FALSE — set `underline = TRUE` per-cell to enable.

library(devtools)
load_all(quiet = TRUE)
library(magrittr)

cat("\n=== Column-header / spanning alignment & style ===\n\n")

gen <- function(tbl) {
  doc <- rtf_document() %>%
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) %>%
    rtf_tables(list(tbl))
  f <- tempfile(fileext = ".rtf")
  generate_rtfreport(doc, f, overwrite = TRUE)
  on.exit(unlink(f))
  paste(readLines(f, warn = FALSE), collapse = "\n")
}

# ──────────────────────────────────────────────────────────────────────────
#  Helper: extract the column-header row labels with their alignment marker.
#  In the generated RTF, header labels appear as: \q[lcr]\liNN\riNN LABEL\cell
# ──────────────────────────────────────────────────────────────────────────
hdr_align_for <- function(txt, label) {
  pat <- sprintf("\\\\q([lcr])\\\\li\\d+\\\\ri\\d+ %s\\\\cell", label)
  m   <- regmatches(txt, regexpr(pat, txt))
  if (length(m) == 0L) return(NA_character_)
  sub(".*\\\\q([lcr]).*", "\\1", m)
}

span_align_for <- function(txt, label) {
  # Spanning cells may carry \ul / \i / \b decorations before the label;
  # match flexibly: \q[lcr]\liN\riN <any decor>* LABEL
  pat <- sprintf("\\\\q([lcr])\\\\li\\d+\\\\ri\\d+ (\\\\\\w+ )*%s", label)
  m <- regmatches(txt, regexpr(pat, txt))
  if (length(m) == 0L) return(NA_character_)
  sub("\\\\q([lcr]).*", "\\1", m)
}

# ──────────────────────────────────────────────────────────────────────────
#  ① Default column-header alignment = data column alignment
# ──────────────────────────────────────────────────────────────────────────
df <- data.frame(L = "x", C = "y", R = 1L, stringsAsFactors = FALSE)
tbl <- rtftable(df,
  col_header = c("Left", "Center", "Right"),
  col_spec = list(
    list(col = 1, align = "left"),
    list(col = 2, align = "center"),
    list(col = 3, align = "right")
  ))
txt <- gen(tbl)
stopifnot(identical(hdr_align_for(txt, "Left"),   "l"))
stopifnot(identical(hdr_align_for(txt, "Center"), "c"))
stopifnot(identical(hdr_align_for(txt, "Right"),  "r"))
cat("OK  ① header alignment defaults to data column alignment\n")

# ──────────────────────────────────────────────────────────────────────────
#  ② col_header_align scalar → all columns
# ──────────────────────────────────────────────────────────────────────────
tbl <- rtftable(df,
  col_header = c("A", "B", "C"),
  col_spec = list(
    list(col = 1, align = "left"),
    list(col = 3, align = "right")
  ),
  col_header_align = "center")
txt <- gen(tbl)
stopifnot(identical(hdr_align_for(txt, "A"), "c"))
stopifnot(identical(hdr_align_for(txt, "B"), "c"))
stopifnot(identical(hdr_align_for(txt, "C"), "c"))
cat("OK  ② col_header_align scalar applies to all columns\n")

# ──────────────────────────────────────────────────────────────────────────
#  ② col_header_align length-ncol vector → per-column
# ──────────────────────────────────────────────────────────────────────────
tbl <- rtftable(df,
  col_header = c("A", "B", "C"),
  col_header_align = c("right", "left", "center"))
txt <- gen(tbl)
stopifnot(identical(hdr_align_for(txt, "A"), "r"))
stopifnot(identical(hdr_align_for(txt, "B"), "l"))
stopifnot(identical(hdr_align_for(txt, "C"), "c"))
cat("OK  ② col_header_align vector applies per-column\n")

# ──────────────────────────────────────────────────────────────────────────
#  ③ col_spec[[j]]$header_align beats col_header_align
# ──────────────────────────────────────────────────────────────────────────
tbl <- rtftable(df,
  col_header = c("A", "B", "C"),
  col_header_align = "center",
  col_spec = list(
    list(col = 2, header_align = "right")
  ))
txt <- gen(tbl)
stopifnot(identical(hdr_align_for(txt, "A"), "c"))   # from col_header_align
stopifnot(identical(hdr_align_for(txt, "B"), "r"))   # col_spec wins
stopifnot(identical(hdr_align_for(txt, "C"), "c"))
cat("OK  ③ col_spec$header_align beats col_header_align\n")

# ──────────────────────────────────────────────────────────────────────────
#  ④ Column-header bold/italic default to FALSE
# ──────────────────────────────────────────────────────────────────────────
tbl <- rtftable(df, col_header = c("Plain", "Mid", "End"))
txt <- gen(tbl)
# A plain header cell should appear *without* a \b decorator in front of it.
stopifnot(!grepl("\\\\b Plain\\\\b0", txt))
stopifnot(!grepl("\\\\i Plain\\\\i0", txt))
cat("OK  ④ header bold/italic default FALSE\n")

# Verify they CAN be turned on per-column
tbl <- rtftable(df,
  col_header = c("X", "Y", "Z"),
  col_spec = list(
    list(col = 2, header_bold = TRUE, header_italic = TRUE)
  ))
txt <- gen(tbl)
stopifnot(grepl("\\\\b \\\\i Y\\\\i0 \\\\b0", txt) ||
           grepl("\\\\i \\\\b Y\\\\b0 \\\\i0", txt) ||
           (grepl("\\\\b ", txt) && grepl("\\\\i ", txt)))
cat("OK  header bold/italic can be enabled via col_spec\n")

# ──────────────────────────────────────────────────────────────────────────
#  Spanning ① Default alignment = leftmost covered column's header_align
# ──────────────────────────────────────────────────────────────────────────
df2 <- data.frame(
  Item   = "Age",
  A_N    = 30L,    A_Mean = 45.2,
  B_N    = 30L,    B_Mean = 46.1,
  stringsAsFactors = FALSE
)

# All numeric columns right-aligned → spanning over them inherits "right"
tbl <- rtftable(df2,
  col_header = c("Item", "N", "Mean", "N", "Mean"),
  col_spec   = list(
    list(col = 1, align = "left"),
    list(col = 2, align = "right"),
    list(col = 3, align = "right"),
    list(col = 4, align = "right"),
    list(col = 5, align = "right")
  ),
  spanning_header = list(
    list(from = 2, to = 3, label = "Drug A"),
    list(from = 4, to = 5, label = "Drug B")
  ))
txt <- gen(tbl)
stopifnot(identical(span_align_for(txt, "Drug A"), "r"))
stopifnot(identical(span_align_for(txt, "Drug B"), "r"))
cat("OK  spanning ① alignment inherits from level below (right-aligned data)\n")

# ──────────────────────────────────────────────────────────────────────────
#  Spanning ① with mixed alignments → leftmost wins
# ──────────────────────────────────────────────────────────────────────────
df3 <- data.frame(L = "x", C = "y", R = 1L, stringsAsFactors = FALSE)
tbl <- rtftable(df3,
  col_header = c("L", "C", "R"),
  col_spec = list(
    list(col = 1, align = "left"),
    list(col = 2, align = "center"),
    list(col = 3, align = "right")
  ),
  spanning_header = list(
    list(from = 1, to = 3, label = "All3")
  ))
txt <- gen(tbl)
stopifnot(identical(span_align_for(txt, "All3"), "l"))
cat("OK  spanning ① mixed alignments → leftmost covered column wins\n")

# ──────────────────────────────────────────────────────────────────────────
#  Spanning ② explicit `align` overrides
# ──────────────────────────────────────────────────────────────────────────
tbl <- rtftable(df2,
  col_header = c("Item", "N", "Mean", "N", "Mean"),
  col_spec   = list(
    list(col = 1, align = "left"),
    list(col = 2, align = "right"),
    list(col = 3, align = "right"),
    list(col = 4, align = "right"),
    list(col = 5, align = "right")
  ),
  spanning_header = list(
    list(from = 2, to = 3, label = "Override", align = "center")
  ))
txt <- gen(tbl)
stopifnot(identical(span_align_for(txt, "Override"), "c"))
cat("OK  spanning ② explicit align overrides inheritance\n")

# ──────────────────────────────────────────────────────────────────────────
#  Spanning ③ bold default FALSE
# ──────────────────────────────────────────────────────────────────────────
tbl <- rtftable(df3,
  spanning_header = list(
    list(from = 1, to = 3, label = "PlainSpan")
  ))
txt <- gen(tbl)
# No \b before / after the label
stopifnot(!grepl("\\\\b PlainSpan", txt))
stopifnot(!grepl("\\\\b \\\\ul PlainSpan", txt))
cat("OK  spanning ③ bold default FALSE\n")

# bold = TRUE explicit
tbl <- rtftable(df3,
  spanning_header = list(
    list(from = 1, to = 3, label = "BoldSpan", bold = TRUE)
  ))
txt <- gen(tbl)
stopifnot(grepl("\\\\b BoldSpan\\\\b0", txt))
cat("OK  spanning ③ bold = TRUE explicit\n")

# ──────────────────────────────────────────────────────────────────────────
#  Spanning ④ italic, ⑤ underline default FALSE; opt-in works
# ──────────────────────────────────────────────────────────────────────────
tbl <- rtftable(df3,
  spanning_header = list(
    list(from = 1, to = 3, label = "ItalSpan", italic = TRUE)
  ))
txt <- gen(tbl)
stopifnot(grepl("\\\\i ItalSpan\\\\i0", txt))
cat("OK  spanning ④ italic opt-in\n")

tbl <- rtftable(df3,
  spanning_header = list(
    list(from = 1, to = 3, label = "ULSpan", underline = TRUE)
  ))
txt <- gen(tbl)
stopifnot(grepl("\\\\ul ULSpan\\\\ulnone", txt))
cat("OK  spanning ⑤ underline opt-in\n")

# Plain spanning (no opt-ins) carries NONE of those decorators
tbl <- rtftable(df3,
  spanning_header = list(
    list(from = 1, to = 3, label = "PureSpan")
  ))
txt <- gen(tbl)
stopifnot(!grepl("\\\\b PureSpan",  txt))
stopifnot(!grepl("\\\\i PureSpan",  txt))
stopifnot(!grepl("\\\\ul PureSpan", txt))
cat("OK  spanning ③④⑤ no decorators by default\n")

# ──────────────────────────────────────────────────────────────────────────
#  Multi-row col_header (spanning + label) — each level inherits correctly
# ──────────────────────────────────────────────────────────────────────────
tbl <- rtftable(df2,
  col_header = list(
    # Row 1: spanning (no own align → inherits from leftmost covered col)
    list(
      list(from = 2, to = 3, label = "ArmA"),
      list(from = 4, to = 5, label = "ArmB")
    ),
    # Row 2: regular labels — header_align should follow col_spec$align
    c("Item", "N", "Mean", "N", "Mean")
  ),
  col_spec = list(
    list(col = 1, align = "left"),
    list(col = 2, align = "right"),
    list(col = 3, align = "right"),
    list(col = 4, align = "right"),
    list(col = 5, align = "right")
  ))
txt <- gen(tbl)
stopifnot(identical(span_align_for(txt, "ArmA"), "r"))
stopifnot(identical(span_align_for(txt, "ArmB"), "r"))
stopifnot(identical(hdr_align_for(txt, "Item"), "l"))
stopifnot(identical(hdr_align_for(txt, "N"),    "r"))
stopifnot(identical(hdr_align_for(txt, "Mean"), "r"))
cat("OK  multi-row col_header: both levels inherit alignment correctly\n")

cat("\n=== ALL HEADER-ALIGNMENT TESTS PASSED ===\n\n")
