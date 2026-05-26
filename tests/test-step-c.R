# Step C: R6 rtf_border + rtf_table_style + per-column border + style sharing.

library(devtools)
load_all(quiet = TRUE)
library(magrittr)

cat("\n=== Step C: R6 rtf_border + rtf_table_style ===\n\n")

# ──────────────────────────────────────────────────────────────────────────
#  1. rtf_border is now an R6 instance but still inherits S3 "rtf_border"
# ──────────────────────────────────────────────────────────────────────────
b <- rtf_border_top()
stopifnot(inherits(b, "rtf_border"))   # S3 class preserved
stopifnot(inherits(b, "R6"))           # R6 too
stopifnot(!is.null(b$top))             # field access works
stopifnot(is.null(b$bottom))
cat("OK  rtf_border is R6 and still inherits the S3 class 'rtf_border'\n")

# ──────────────────────────────────────────────────────────────────────────
#  2. Setter methods chainable; mutate in place
# ──────────────────────────────────────────────────────────────────────────
b2 <- rtf_border()$set_top(rtf_border_side())$set_bottom(rtf_border_side("double", 20L))
stopifnot(!is.null(b2$top))
stopifnot(identical(b2$bottom$style, "double"))
stopifnot(identical(b2$bottom$width, 20L))
cat("OK  set_top()/set_bottom() chain mutates in place\n")

# ──────────────────────────────────────────────────────────────────────────
#  3. with_*() returns an independent clone (original is unaffected)
# ──────────────────────────────────────────────────────────────────────────
base <- rtf_border_top()
derived <- base$with_bottom(rtf_border_side("dot"))
stopifnot(is.null(base$bottom))               # base untouched
stopifnot(identical(derived$bottom$style, "dot"))
stopifnot(identical(derived$top$style, "single"))   # top inherited from base
cat("OK  with_*() returns an independent clone\n")

# ──────────────────────────────────────────────────────────────────────────
#  4. apply_override (mutating) vs override (non-mutating)
# ──────────────────────────────────────────────────────────────────────────
a <- rtf_border(top = rtf_border_side(), bottom = rtf_border_side("single"))
ov <- rtf_border(bottom = rtf_border_side("thick"))

c1 <- a$override(ov)
stopifnot(identical(a$bottom$style, "single"))     # a not mutated
stopifnot(identical(c1$bottom$style, "thick"))     # override produces clone
stopifnot(identical(c1$top$style,    "single"))    # top kept from a

a$apply_override(ov)
stopifnot(identical(a$bottom$style, "thick"))      # in-place mutation
cat("OK  override() vs apply_override() distinction\n")

# ──────────────────────────────────────────────────────────────────────────
#  5. rtf_table_style — shared mutable theme; clone_with() for derivation
# ──────────────────────────────────────────────────────────────────────────
sty <- rtf_table_style_tfl()
stopifnot(inherits(sty, "rtf_table_style"))
stopifnot(inherits(sty, "R6"))
stopifnot(isFALSE(sty$header_bold))

# Derive a non-mutating variant
sty2 <- sty$clone_with(header_bold = TRUE)
stopifnot(isTRUE(sty2$header_bold))
stopifnot(isFALSE(sty$header_bold))     # parent untouched

# Unknown field rejected
err <- tryCatch(sty$clone_with(nonexistent = 1L), error = function(e) e)
stopifnot(inherits(err, "error"))
cat("OK  rtf_table_style$clone_with() / unknown-field rejection\n")

# ──────────────────────────────────────────────────────────────────────────
#  6. Shared theme: mutate once, every referencing table sees it at render
# ──────────────────────────────────────────────────────────────────────────
sty <- rtf_table_style_tfl()
df <- data.frame(A = 1:2, B = c("x", "y"), stringsAsFactors = FALSE)

# Construct two tables that share the SAME style instance
t1 <- rtftable(df, style = sty)
t2 <- rtftable(df, style = sty)

# Mutate the shared theme
sty$header_bold <- TRUE

# Each table re-reads the style's *border* state from sty$as_table_border()
# at construction time (snapshotted into tbl$border).  But fields stored
# directly off the style (header_bold default for col_spec) are snapshotted
# at construction.  This test documents that distinction.
stopifnot(isFALSE(t1$col_spec[[1L]]$header_bold))   # snapshotted at $new
cat("OK  style snapshot at construction (documented behaviour)\n")

# Building a NEW table after the mutation picks the new value up.
t3 <- rtftable(df, style = sty)
stopifnot(isTRUE(t3$col_spec[[1L]]$header_bold))
cat("OK  new table built after style mutation sees the new default\n")

# ──────────────────────────────────────────────────────────────────────────
#  7. Per-column border via col_spec[[j]]$border
# ──────────────────────────────────────────────────────────────────────────
df2 <- data.frame(L = "x", N = 1L, V = 2.5)
tbl <- rtftable(df2,
  border = rtf_table_border(header = rtf_border_top()),
  col_spec = list(
    list(col = 2, border = rtf_border(top    = rtf_border_side("double", 20L),
                                       bottom = rtf_border_side("double", 20L)))
  ))
stopifnot(inherits(tbl$col_spec[[2L]]$border, "rtf_border"))
stopifnot(identical(tbl$col_spec[[2L]]$border$bottom$style, "double"))

# End-to-end RTF generation contains the per-column override
doc <- rtf_document() %>%
  rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) %>%
  rtf_tables(list(tbl))
f <- tempfile(fileext = ".rtf")
generate_rtfreport(doc, f, overwrite = TRUE)
txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
stopifnot(grepl("\\\\brdrdb", txt))   # \brdrdb = RTF "double" border command
unlink(f)
cat("OK  col_spec[[j]]$border applied per-column in header row\n")

# ──────────────────────────────────────────────────────────────────────────
#  8. Backward compat: existing border = "tfl" / rtf_table_border() still work
# ──────────────────────────────────────────────────────────────────────────
tbl1 <- rtftable(df2, border = "tfl")
stopifnot(inherits(tbl1$border, "rtf_table_border"))
stopifnot(inherits(tbl1$border$header, "rtf_border"))  # zone is R6
cat("OK  border = 'tfl' continues to produce rtf_table_border\n")

cat("\n=== ALL STEP C TESTS PASSED ===\n\n")
