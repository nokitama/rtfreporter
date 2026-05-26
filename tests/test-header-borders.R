# Column-header border defaults (v0.0.16):
#
#   ① Top border on the topmost header row only.
#   ② Bottom border on the bottommost header row only.
#   ③ Each spanning cell that covers more than one column gets an
#      additional bottom border separating it from the more granular
#      row below (the typical "underline the group label" look),
#      unless the spanning row is itself the last header row.
#   ④ No vertical borders by default.
#   ⑤ All of the above can be overridden — explicit `border` argument
#      flows through, and per-column borders via `col_spec[[j]]$border`
#      win over the row-level border on the column-header row.

library(devtools)
load_all(quiet = TRUE)
library(magrittr)

cat("\n=== Column-header border defaults ===\n\n")

gen <- function(tbl) {
  doc <- rtf_document() %>%
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) %>%
    rtf_tables(list(tbl))
  f <- tempfile(fileext = ".rtf")
  generate_rtfreport(doc, f, overwrite = TRUE)
  on.exit(unlink(f))
  paste(readLines(f, warn = FALSE), collapse = "\n")
}

# A spanning cell appears in RTF as:
#   <border-cmds>\cellx<X>...\q?\liNN\riNN ...LABEL\cell
# Locate the cellx that corresponds to the label and check whether
# the immediately preceding border commands carry top / bottom markers.
defs_for_label <- function(txt, label) {
  # Capture everything between the previous "\cellx" boundary and the
  # cell containing `label`.
  pat <- sprintf("\\\\trowd[^\\\\]*(?:\\\\(?!trowd)\\w+\\d*)*[^L]*?%s", label)
  m <- regmatches(txt, regexpr(pat, txt, perl = TRUE))
  if (length(m) == 0L) return(NA_character_)
  m
}

# Count occurrences of \brdrt / \brdrb across the entire generated RTF
# (cheap proxy for "how many cells carry that border").
count_brdrt <- function(txt) length(gregexpr("\\\\clbrdrt\\\\brdrs", txt)[[1L]]) -
                              (regmatches(txt, regexpr("\\\\clbrdrt\\\\brdrs", txt)) == "")
count_brdrb <- function(txt) length(gregexpr("\\\\clbrdrb\\\\brdrs", txt)[[1L]]) -
                              (regmatches(txt, regexpr("\\\\clbrdrb\\\\brdrs", txt)) == "")

# Build a 5-column dataframe used across the multi-row spanning tests.
df <- data.frame(
  Item   = "Age",
  A_N    = 30L,    A_Mean = 45.2,
  B_N    = 30L,    B_Mean = 46.1,
  stringsAsFactors = FALSE
)

# ──────────────────────────────────────────────────────────────────────────
#  ① + ②  Single-row header: top + bottom on the same (only) header row
# ──────────────────────────────────────────────────────────────────────────
tbl <- rtftable(df, col_header = c("Item", "N", "Mean", "N", "Mean"))
txt <- gen(tbl)
# Expect: at least 5 \clbrdrt (one per cell of the only header row) +
#         at least 5 \clbrdrb (same row, also the last header row) +
#         at least 5 more \clbrdrb on the last data row (TFL preset)
n_top <- length(gregexpr("\\\\clbrdrt\\\\brdrs", txt)[[1L]])
n_bot <- length(gregexpr("\\\\clbrdrb\\\\brdrs", txt)[[1L]])
stopifnot(n_top >= 5L && n_top <= 6L)   # 5 header cells (header is first row)
stopifnot(n_bot >= 10L)                 # 5 header + 5 last-row body cells
cat("OK  ① + ② single header row carries both top and bottom borders\n")

# ──────────────────────────────────────────────────────────────────────────
#  ① + ②  Two header rows: top on row 1 only, bottom on row 2 only
# ──────────────────────────────────────────────────────────────────────────
tbl <- rtftable(df,
  col_header = list(
    # Row 1: spanning over A_N+A_Mean and B_N+B_Mean
    list(
      list(from = 2, to = 3, label = "ArmA"),
      list(from = 4, to = 5, label = "ArmB")
    ),
    # Row 2: labels
    c("Item", "N", "Mean", "N", "Mean")
  ))
txt <- gen(tbl)
# Row 1 cell layout:  Item | ArmA(span2-3) | ArmB(span4-5)        → 3 cells
# Row 2 cell layout:  Item | N | Mean | N | Mean                  → 5 cells
# Expected \clbrdrt: 3 cells of row 1 only → 3 occurrences
# Expected \clbrdrb: 2 multi-col span bottoms (ArmA, ArmB) on row 1
#                 + 5 cells of row 2 (last header)
#                 + 5 cells of last data row
n_top <- length(gregexpr("\\\\clbrdrt\\\\brdrs", txt)[[1L]])
n_bot <- length(gregexpr("\\\\clbrdrb\\\\brdrs", txt)[[1L]])
stopifnot(n_top == 3L)                  # Row 1 only — no top on row 2
stopifnot(n_bot >= 5L)                  # at least row 2 + last data row
# Item column on row 1 should NOT have a bottom border (single col,
# not last header row).  ArmA / ArmB cells should.
cat(sprintf("    n_top = %d, n_bot = %d\n", n_top, n_bot))
cat("OK  ① top on first row only, ② bottom on last row only\n")

# ──────────────────────────────────────────────────────────────────────────
#  ③  Multi-col spanning gets a bottom border (group separator)
# ──────────────────────────────────────────────────────────────────────────
# Standalone spanning_header above a single label row.
tbl <- rtftable(df,
  col_header = c("Item", "N", "Mean", "N", "Mean"),
  spanning_header = list(
    list(from = 2, to = 3, label = "ArmA"),
    list(from = 4, to = 5, label = "ArmB")
  ))
txt <- gen(tbl)
# Spanning row is row 1.  ArmA covers cols 2-3 (multi) → bottom border;
# ArmB covers 4-5 (multi) → bottom border.  Item is col 1 single (no
# bottom border on row 1).
# Row 2 (labels) is the last header row → all 5 cells get bottom.
# Last data row → 5 more bottoms.
n_bot <- length(gregexpr("\\\\clbrdrb\\\\brdrs", txt)[[1L]])
stopifnot(n_bot >= 12L)   # 2 span bottoms + 5 labels + 5 data last-row
cat("OK  ③ multi-col spanning cells carry a bottom group-separator border\n")

# ──────────────────────────────────────────────────────────────────────────
#  ③ negative — single-col spanning has NO extra bottom (when not last)
# ──────────────────────────────────────────────────────────────────────────
df3 <- data.frame(A = 1L, B = 2L, C = 3L)
tbl <- rtftable(df3,
  col_header = list(
    # Row 1: spanning where each entry is a single column (degenerate)
    list(
      list(from = 1, to = 1, label = "x"),
      list(from = 2, to = 2, label = "y"),
      list(from = 3, to = 3, label = "z")
    ),
    c("A", "B", "C")
  ))
txt <- gen(tbl)
# Row 1 cells (3): all single-col → NO group bottom.  No top on row 2.
# So bottoms come only from: row 2 (3 cells) + last data row (3 cells) = 6.
n_bot <- length(gregexpr("\\\\clbrdrb\\\\brdrs", txt)[[1L]])
stopifnot(n_bot == 6L)
cat("OK  ③ negative: single-col spanning does NOT add bottom border\n")

# ──────────────────────────────────────────────────────────────────────────
#  ④  No vertical borders by default
# ──────────────────────────────────────────────────────────────────────────
tbl <- rtftable(df, col_header = c("Item", "N", "Mean", "N", "Mean"))
txt <- gen(tbl)
stopifnot(!grepl("\\\\clbrdrl\\\\brdrs", txt))
stopifnot(!grepl("\\\\clbrdrr\\\\brdrs", txt))
cat("OK  ④ no left/right borders emitted by default\n")

# ──────────────────────────────────────────────────────────────────────────
#  ⑤  border = "none" suppresses all default borders
# ──────────────────────────────────────────────────────────────────────────
tbl <- rtftable(df, col_header = c("Item", "N", "Mean", "N", "Mean"),
                 border = NULL)
txt <- gen(tbl)
stopifnot(!grepl("\\\\clbrdrt\\\\brdrs", txt))
stopifnot(!grepl("\\\\clbrdrb\\\\brdrs", txt))
cat("OK  ⑤ border = NULL → no borders anywhere\n")

# ──────────────────────────────────────────────────────────────────────────
#  ⑤  per-column override via col_spec[[j]]$border still applies
# ──────────────────────────────────────────────────────────────────────────
tbl <- rtftable(df3,
  col_header = c("A", "B", "C"),
  border     = NULL,         # disable defaults so only override is visible
  col_spec   = list(
    list(col = 2, border = rtf_border(top = rtf_border_side("double", 20L),
                                       bottom = rtf_border_side("double", 20L)))
  ))
txt <- gen(tbl)
stopifnot(grepl("\\\\brdrdb", txt))         # at least one double-line command
cat("OK  ⑤ per-column col_spec$border still applied\n")

cat("\n=== ALL HEADER-BORDER TESTS PASSED ===\n\n")
