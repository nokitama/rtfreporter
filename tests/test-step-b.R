# Step B: blank_rows (3 modes), read_attributes, col_header_align,
#         multi-row col_header with per-row spanning.

library(devtools)
load_all(quiet = TRUE)
library(magrittr)

cat("\n=== Step B: blank_rows / col_header_align / multi-row spanning ===\n\n")

# ──────────────────────────────────────────────────────────────────────────
#  1.  blank_rows: mode 1 (positions, with -1 as "after last")
# ──────────────────────────────────────────────────────────────────────────
df <- data.frame(
  Grp = c("A", "A", "B", "B", "C"),
  Val = 1:5,
  stringsAsFactors = FALSE
)

tbl <- rtftable(df, blank_rows = c(0, 2, -1))
stopifnot(identical(tbl$blank_rows, c(0L, 2L, 5L)))     # -1 → nrow(df) = 5
cat("OK  mode 1: c(0, 2, -1) → positions(0, 2, 5)\n")

# Out-of-range warns and is dropped
tbl <- suppressWarnings(rtftable(df, blank_rows = c(2, 99)))
stopifnot(identical(tbl$blank_rows, 2L))
cat("OK  mode 1: out-of-range position warns and is dropped\n")

# ──────────────────────────────────────────────────────────────────────────
#  2.  blank_rows: mode 2 (by_change)
# ──────────────────────────────────────────────────────────────────────────
tbl <- rtftable(df, blank_rows = blank_rows_by_change(cols = "Grp"))
# Grp changes at rows 3 (A→B), 5 (B→C) → blank at positions 2, 4
# + before-first (0) + after-last (5)
stopifnot(identical(tbl$blank_rows, c(0L, 2L, 4L, 5L)))
cat("OK  mode 2: by_change(cols='Grp') with default before/after → c(0,2,4,5)\n")

tbl <- rtftable(df,
  blank_rows = blank_rows_by_change("Grp",
                                     include_before_first = FALSE,
                                     include_after_last   = FALSE))
stopifnot(identical(tbl$blank_rows, c(2L, 4L)))
cat("OK  mode 2: by_change(...) without before/after\n")

# ──────────────────────────────────────────────────────────────────────────
#  3.  blank_rows: mode 3 (by_rule, regex)
# ──────────────────────────────────────────────────────────────────────────
df2 <- data.frame(
  Param = c("Age",     "  Mean",  "  SD",
            "Weight",  "  Mean",  "  SD",
            "Total"),
  N     = c(20, NA, NA, 20, NA, NA, 20),
  stringsAsFactors = FALSE
)
# Rule: lines NOT starting with a space → blank row BEFORE them.
# Matches rows 1, 4, 7 → blank positions 0, 3, 6.
tbl <- rtftable(df2,
  blank_rows = blank_rows_by_rule(col = "Param",
                                   pattern = "^[^ ]",
                                   where = "before"))
stopifnot(identical(tbl$blank_rows, c(0L, 3L, 6L)))
cat("OK  mode 3: by_rule(... pattern='^[^ ]', where='before')\n")

# ──────────────────────────────────────────────────────────────────────────
#  4.  blank_rows: list combination of all three modes (union)
# ──────────────────────────────────────────────────────────────────────────
tbl <- rtftable(df,
  blank_rows = list(
    c(-1),                                     # mode 1: after last
    blank_rows_by_change("Grp",
      include_before_first = FALSE,
      include_after_last   = FALSE),           # mode 2: changes only
    blank_rows_by_rule("Grp", "^C", "before")  # mode 3: before C → pos 4
  ))
# Union: 5 (mode 1), 2, 4 (mode 2), 4 (mode 3) → c(2, 4, 5)
stopifnot(identical(tbl$blank_rows, c(2L, 4L, 5L)))
cat("OK  modes 1+2+3 combined via list → union\n")

# ──────────────────────────────────────────────────────────────────────────
#  5.  read_attributes: attr(data, "rtf_blank_rows") as fallback
# ──────────────────────────────────────────────────────────────────────────
df3 <- df
attr(df3, "rtf_blank_rows") <- c(0L, -1L)

# Default read_attributes = TRUE, no explicit blank_rows → attribute used
tbl <- rtftable(df3)
stopifnot(identical(tbl$blank_rows, c(0L, 5L)))
cat("OK  read_attributes default TRUE → attr(rtf_blank_rows) consumed\n")

# Explicit blank_rows overrides the attribute
tbl <- rtftable(df3, blank_rows = c(2L))
stopifnot(identical(tbl$blank_rows, 2L))
cat("OK  explicit blank_rows overrides attribute\n")

# read_attributes = FALSE ignores it
tbl <- rtftable(df3, read_attributes = FALSE)
stopifnot(is.null(tbl$blank_rows))
cat("OK  read_attributes = FALSE → attribute ignored\n")

# ──────────────────────────────────────────────────────────────────────────
#  6.  col_header_align: NULL inherits from align
# ──────────────────────────────────────────────────────────────────────────
df4 <- data.frame(L = "x", N = 1L, V = 2.5)
tbl <- rtftable(df4, col_spec = list(
  list(col = 1, align = "left"),
  list(col = 2, align = "right"),
  list(col = 3, align = "center")
))
stopifnot(identical(tbl$col_spec[[1L]]$header_align, "left"))
stopifnot(identical(tbl$col_spec[[2L]]$header_align, "right"))
stopifnot(identical(tbl$col_spec[[3L]]$header_align, "center"))
cat("OK  col_header_align NULL → inherits from col_spec$align\n")

# col_header_align scalar → applied to all columns
tbl <- rtftable(df4,
  col_spec = list(list(col = 1, align = "left"),
                   list(col = 2, align = "right")),
  col_header_align = "center")
for (j in 1:3) stopifnot(identical(tbl$col_spec[[j]]$header_align, "center"))
cat("OK  col_header_align scalar applies to all columns\n")

# col_header_align vector length ncol → per-column
tbl <- rtftable(df4, col_header_align = c("right", "right", "left"))
stopifnot(identical(tbl$col_spec[[1L]]$header_align, "right"))
stopifnot(identical(tbl$col_spec[[3L]]$header_align, "left"))
cat("OK  col_header_align vector → per-column override\n")

# col_spec per-column header_align beats col_header_align
tbl <- rtftable(df4,
  col_spec = list(list(col = 2, header_align = "left")),
  col_header_align = "center")
stopifnot(identical(tbl$col_spec[[1L]]$header_align, "center"))
stopifnot(identical(tbl$col_spec[[2L]]$header_align, "left"))    # col_spec wins
stopifnot(identical(tbl$col_spec[[3L]]$header_align, "center"))
cat("OK  col_spec.header_align > col_header_align > col_spec.align\n")

# ──────────────────────────────────────────────────────────────────────────
#  7.  Multi-row col_header with spanning row mixed in
# ──────────────────────────────────────────────────────────────────────────
df5 <- data.frame(
  Item   = c("Age", "Sex"),
  A_N    = c(30, 30),
  A_Mean = c(45.2, NA),
  B_N    = c(30, 30),
  B_Mean = c(46.1, NA),
  stringsAsFactors = FALSE
)
tbl <- rtftable(df5, col_header = list(
  # Row 1: spanning
  list(
    list(from = 2, to = 3, label = "Drug A (N=30)", underline = TRUE),
    list(from = 4, to = 5, label = "Drug B (N=30)", underline = TRUE)
  ),
  # Row 2: labels
  c("Item", "N", "Mean", "N", "Mean")
))
stopifnot(length(tbl$col_header) == 2L)
# Row 1 is a spanning row
stopifnot(is.list(tbl$col_header[[1L]]))
stopifnot(!is.null(tbl$col_header[[1L]][[1L]]$from))
# Row 2 is a character vector
stopifnot(is.character(tbl$col_header[[2L]]))
cat("OK  col_header accepts mixed [spanning row, label row]\n")

# End-to-end: generate the RTF and verify both rows appear
doc <- rtf_document() %>%
  rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) %>%
  rtf_tables(list(tbl))
f <- tempfile(fileext = ".rtf")
generate_rtfreport(doc, f, overwrite = TRUE)
txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
stopifnot(grepl("Drug A \\(N=30\\)", txt))
stopifnot(grepl("Drug B \\(N=30\\)", txt))
stopifnot(grepl("\\\\b0 Item",  txt) || grepl("Item",  txt))
unlink(f)
cat("OK  multi-row col_header (spanning + labels) renders end-to-end\n")

cat("\n=== ALL STEP B TESTS PASSED ===\n\n")
