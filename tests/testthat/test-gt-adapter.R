# Phase A GT integration: as_rtftable() + rtf_tables(read_gt = ...)
#
# All tests skip when the optional `gt` package is not installed so
# CRAN runs without gt still pass.

# ──────── .resolve_gt_tokens ──────────────────────────────────────────────

test_that(".resolve_gt_tokens(FALSE / NULL) -> empty", {
  expect_identical(rtfreporter:::.resolve_gt_tokens(FALSE), character(0))
  expect_identical(rtfreporter:::.resolve_gt_tokens(NULL),  character(0))
})

test_that(".resolve_gt_tokens(TRUE) -> every implemented token", {
  tk <- rtfreporter:::.resolve_gt_tokens(TRUE)
  # Phase A + B + C + D = 12 tokens (v0.0.42 ships Phase D: styles,
  # footnote_marks, strip_html).
  expect_setequal(tk, c("col_header", "alignment", "titles", "source_notes",
                        "spanning", "widths", "hidden",
                        "footnotes", "stub",
                        "styles", "footnote_marks", "strip_html"))
})

test_that(".resolve_gt_tokens accepts a subset", {
  tk <- rtfreporter:::.resolve_gt_tokens(c("col_header", "titles"))
  expect_setequal(tk, c("col_header", "titles"))
})

test_that(".resolve_gt_tokens accepts each token group without warnings", {
  # All 9 tokens are implemented in v0.0.40 -- none of them should warn.
  for (grp in list(
    c("col_header", "alignment", "titles", "source_notes"),  # Phase A
    c("spanning", "widths", "hidden"),                       # Phase B
    c("footnotes", "stub")                                   # Phase C
  )) {
    expect_silent(tk <- rtfreporter:::.resolve_gt_tokens(grp))
    expect_setequal(tk, grp)
  }
})

test_that(".resolve_gt_tokens errors on unknown tokens", {
  expect_error(
    rtfreporter:::.resolve_gt_tokens(c("col_header", "garbage")),
    "Unknown.*token"
  )
})

test_that(".resolve_gt_tokens errors on non-character / non-bool input", {
  expect_error(rtfreporter:::.resolve_gt_tokens(42), "must be FALSE/TRUE")
})

# ──────── .flatten_to_chr ─────────────────────────────────────────────────

test_that(".flatten_to_chr handles NULL / empty / list-of-1 / character / NA", {
  ftc <- rtfreporter:::.flatten_to_chr
  expect_true(is.na(ftc(NULL)))
  expect_true(is.na(ftc(character(0))))
  expect_true(is.na(ftc(list(NULL))))
  expect_true(is.na(ftc(list(""))))
  expect_true(is.na(ftc(NA)))
  expect_identical(ftc("X"),         "X")
  expect_identical(ftc(list("Y")),   "Y")
  expect_identical(ftc(c("Z", "W")), "Z")
})

# ──────── End-to-end with a real gt_tbl ───────────────────────────────────

# A representative gt_tbl: re-labelled columns, header title/subtitle,
# per-column alignment, and two source notes (one of them a markdown
# expression).
.mk_gt <- function() {
  gt::gt(head(mtcars, 3)[, c("mpg", "cyl", "disp")]) |>
    gt::cols_label(mpg = "MPG", cyl = "Cyl", disp = "Disp") |>
    gt::cols_align("right", columns = c(mpg, cyl, disp)) |>
    gt::tab_header(title = "Demo Table",
                   subtitle = "Selected variables") |>
    gt::tab_source_note("Source: built-in mtcars dataset.") |>
    gt::tab_source_note(gt::md("**Note:** subset only."))
}

test_that(".extract_col_labels returns the cols_label() vector", {
  skip_if_not_installed("gt")
  g <- .mk_gt()
  labs <- rtfreporter:::.extract_col_labels(g)
  expect_identical(labs, c("MPG", "Cyl", "Disp"))
})

test_that(".extract_col_align returns gt's per-column alignment", {
  skip_if_not_installed("gt")
  g <- .mk_gt()
  aln <- rtfreporter:::.extract_col_align(g)
  expect_setequal(aln, "right")
  expect_length(aln, 3L)
})

test_that(".extract_titles flattens title + subtitle (+ preheader)", {
  skip_if_not_installed("gt")
  g <- .mk_gt()
  tit <- rtfreporter:::.extract_titles(g)
  expect_identical(tit, c("Demo Table", "Selected variables"))
})

test_that(".extract_source_notes flattens character + markdown_text", {
  skip_if_not_installed("gt")
  g <- .mk_gt()
  notes <- rtfreporter:::.extract_source_notes(g)
  expect_length(notes, 2L)
  expect_identical(notes[[1L]], "Source: built-in mtcars dataset.")
  # markdown_text gets flattened to its raw source text.
  expect_identical(notes[[2L]], "**Note:** subset only.")
})

test_that(".extract_source_notes returns NULL when none are set", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 2))
  expect_null(rtfreporter:::.extract_source_notes(g))
})

test_that(".extract_titles returns NULL when no header is set", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 2))
  expect_null(rtfreporter:::.extract_titles(g))
})

# ──────── .gt_to_rtftable_kwargs ──────────────────────────────────────────

test_that(".gt_to_rtftable_kwargs default tokens return all Phase-A fields", {
  skip_if_not_installed("gt")
  g <- .mk_gt()
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g)
  expect_s3_class(kw$data, "data.frame")
  expect_identical(kw$col_header, c("MPG", "Cyl", "Disp"))
  expect_length(kw$col_spec, 3L)
  expect_identical(kw$col_spec[[1L]]$align, "right")
  expect_identical(kw$titles_block,    c("Demo Table", "Selected variables"))
  expect_identical(kw$footnotes_block[[1L]],
                   "Source: built-in mtcars dataset.")
})

test_that(".gt_to_rtftable_kwargs honours a token subset", {
  skip_if_not_installed("gt")
  g <- .mk_gt()
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g,
        tokens = c("col_header", "titles"))
  expect_identical(kw$col_header, c("MPG", "Cyl", "Disp"))
  expect_identical(kw$titles_block, c("Demo Table", "Selected variables"))
  expect_null(kw$col_spec)
  expect_null(kw$footnotes_block)
})

test_that(".gt_to_rtftable_kwargs rejects non-gt input", {
  expect_error(rtfreporter:::.gt_to_rtftable_kwargs(data.frame(A = 1)),
               "must be a gt_tbl")
})

# ──────── as_rtftable() public API ────────────────────────────────────────

test_that("as_rtftable(gt, read = TRUE) returns an rtftable with gt labels + align", {
  skip_if_not_installed("gt")
  g   <- .mk_gt()
  tbl <- as_rtftable(g)
  expect_s3_class(tbl, "rtftable")
  expect_identical(unlist(tbl$col_header[[1L]]),
                   c("MPG", "Cyl", "Disp"))
  expect_identical(tbl$col_spec[[1L]]$align, "right")
})

test_that("as_rtftable(gt, read = FALSE) ignores all gt attributes", {
  skip_if_not_installed("gt")
  g   <- .mk_gt()
  tbl <- as_rtftable(g, read = FALSE)
  # No col_header set -> the slot stays NULL; the renderer later
  # falls back to names(data).
  expect_null(tbl$col_header)
  expect_identical(names(tbl$data), c("mpg", "cyl", "disp"))
  # Default per-col alignment is "left" (rtftable default), not "right".
  expect_identical(tbl$col_spec[[1L]]$align, "left")
})

test_that("as_rtftable() explicit col_header beats gt's labels", {
  skip_if_not_installed("gt")
  g   <- .mk_gt()
  tbl <- as_rtftable(g, col_header = c("A", "B", "C"))
  expect_identical(unlist(tbl$col_header[[1L]]),
                   c("A", "B", "C"))
})

test_that("as_rtftable() explicit col_spec deep-merges with gt-derived spec", {
  skip_if_not_installed("gt")
  g   <- .mk_gt()
  tbl <- as_rtftable(g,
                     col_spec = list(list(col = 1L, align = "left",
                                          bold = TRUE)))
  # Col 1: user wins for align + bold.
  expect_identical(tbl$col_spec[[1L]]$align, "left")
  expect_true(isTRUE(tbl$col_spec[[1L]]$bold))
  # Col 2 / 3: only gt's align ("right") survives.
  expect_identical(tbl$col_spec[[2L]]$align, "right")
  expect_identical(tbl$col_spec[[3L]]$align, "right")
})

test_that("as_rtftable() rejects non-gt input", {
  expect_error(as_rtftable(data.frame(A = 1)), "must be a gt_tbl")
})

# ──────── rtf_tables(read_gt = ...) end-to-end ────────────────────────────

test_that("rtf_tables accepts gt_tbl directly (read_gt = FALSE: data-only)", {
  skip_if_not_installed("gt")
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(.mk_gt()))
  expect_length(doc$contents, 1L)
  expect_s3_class(doc$contents[[1L]], "rtftable")
  # No labels propagated -> col_header slot stays NULL; the renderer
  # falls back to names(data) at render time.
  expect_null(doc$contents[[1L]]$col_header)
  expect_identical(names(doc$contents[[1L]]$data),
                   c("mpg", "cyl", "disp"))
  # No title / footnote propagated.
  expect_null(doc$titles[[1L]])
  expect_null(doc$footnotes[[1L]])
})

test_that("rtf_tables(read_gt = TRUE) pulls every Phase-A attribute through", {
  skip_if_not_installed("gt")
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(.mk_gt()), read_gt = TRUE)
  # col_header from gt
  expect_identical(unlist(doc$contents[[1L]]$col_header[[1L]]),
                   c("MPG", "Cyl", "Disp"))
  # alignment from gt
  expect_identical(doc$contents[[1L]]$col_spec[[1L]]$align, "right")
  # title block from gt
  expect_identical(doc$titles[[1L]],
                   c("Demo Table", "Selected variables"))
  # source notes -> footnotes block
  expect_identical(doc$footnotes[[1L]][[1L]],
                   "Source: built-in mtcars dataset.")
})

test_that("rtf_tables(read_gt = vec) supports selective opt-in", {
  skip_if_not_installed("gt")
  # Only pull titles; leave col_header / alignment / source_notes alone.
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(.mk_gt()), read_gt = "titles")
  expect_identical(doc$titles[[1L]],
                   c("Demo Table", "Selected variables"))
  # No col_header, no source notes.
  expect_null(doc$contents[[1L]]$col_header)
  expect_null(doc$footnotes[[1L]])
})

test_that("rtf_tables explicit titles / footnotes beat gt-extracted ones", {
  skip_if_not_installed("gt")
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(.mk_gt()),
               titles    = list("Override title"),
               footnotes = list("Override footnote"),
               read_gt   = TRUE)
  expect_identical(doc$titles[[1L]],    "Override title")
  expect_identical(doc$footnotes[[1L]], "Override footnote")
})

test_that("rtf_tables mixes gt_tbl with bare data.frame in one call", {
  skip_if_not_installed("gt")
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(.mk_gt(), data.frame(X = 1:2, Y = c("a", "b"))),
               read_gt = TRUE)
  expect_length(doc$contents, 2L)
  # gt page -> custom labels.
  expect_identical(unlist(doc$contents[[1L]]$col_header[[1L]]),
                   c("MPG", "Cyl", "Disp"))
  # bare data.frame page -> no col_header set (renderer uses
  # names(data) at render time).
  expect_null(doc$contents[[2L]]$col_header)
  expect_identical(names(doc$contents[[2L]]$data), c("X", "Y"))
  # Page-level extractions apply only to the gt page.
  expect_identical(doc$titles[[1L]],
                   c("Demo Table", "Selected variables"))
  expect_null(doc$titles[[2L]])
})

test_that("rtf_tables(read_gt) generates a valid RTF file end-to-end", {
  skip_if_not_installed("gt")
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(.mk_gt()), read_gt = TRUE)
  out <- tempfile(fileext = ".rtf"); on.exit(unlink(out), add = TRUE)
  expect_invisible(generate_rtfreport(doc, out, overwrite = TRUE))
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(txt, "MPG")
  expect_match(txt, "Demo Table")
  expect_match(txt, "Source: built-in mtcars dataset")
})

# ============================================================================
# Phase B: spanning, widths, hidden
# ============================================================================

# ──────── .extract_visible_mask ───────────────────────────────────────────

test_that(".extract_visible_mask flags hidden columns FALSE", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl", "disp")]) |>
    gt::cols_hide(cyl)
  m <- rtfreporter:::.extract_visible_mask(g)
  expect_identical(m, c(TRUE, FALSE, TRUE))
})

test_that(".extract_visible_mask returns all-TRUE when no columns hidden", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl")])
  expect_identical(rtfreporter:::.extract_visible_mask(g), c(TRUE, TRUE))
})

# ──────── .parse_one_width ────────────────────────────────────────────────

test_that(".parse_one_width parses px / pct / missing / unknown forms", {
  pw <- rtfreporter:::.parse_one_width
  expect_identical(pw(list(list("100px"))), list(kind = "px",  value = 100))
  expect_identical(pw("50px"),             list(kind = "px",  value = 50))
  expect_identical(pw(" 25.5 % "),         list(kind = "pct", value = 25.5))
  expect_identical(pw(NULL)$kind,          "missing")
  expect_identical(pw("")$kind,            "missing")
  expect_identical(pw(NA)$kind,            "missing")
  expect_identical(pw("3em")$kind,         "unknown")
})

# ──────── .extract_widths ─────────────────────────────────────────────────

test_that(".extract_widths returns column_widths_twips for all-px input", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl", "disp")]) |>
    gt::cols_width(mpg ~ gt::px(100), cyl ~ gt::px(50),
                   disp ~ gt::px(150))
  w <- rtfreporter:::.extract_widths(g)
  # 1 px = 15 twips
  expect_identical(w$column_widths_twips, as.integer(c(1500, 750, 2250)))
  expect_null(w$col_rel_width)
})

test_that(".extract_widths returns col_rel_width for all-pct input", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl", "disp")]) |>
    gt::cols_width(mpg ~ gt::pct(40), cyl ~ gt::pct(20),
                   disp ~ gt::pct(40))
  w <- rtfreporter:::.extract_widths(g)
  expect_identical(w$col_rel_width, c(40, 20, 40))
})

test_that(".extract_widths returns NULL for mixed / all-missing / partial inputs", {
  skip_if_not_installed("gt")
  # No widths set at all
  g0 <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl")])
  expect_null(rtfreporter:::.extract_widths(g0))
  # Mixed: 1 px + 1 pct (no obvious twip conversion).
  g1 <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl")]) |>
    gt::cols_width(mpg ~ gt::px(100), cyl ~ gt::pct(20))
  expect_null(rtfreporter:::.extract_widths(g1))
  # Partial: only one of two columns has a width.
  g2 <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl")]) |>
    gt::cols_width(mpg ~ gt::px(100))
  expect_null(rtfreporter:::.extract_widths(g2))
})

# ──────── .extract_spanners ───────────────────────────────────────────────

test_that(".extract_spanners returns empty list when no spanners set", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl")])
  expect_identical(rtfreporter:::.extract_spanners(g), list())
})

test_that(".extract_spanners builds one row per spanner_level (descending)", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl", "disp", "hp", "drat")]) |>
    gt::tab_spanner(label = "Engine",      columns = c(cyl, disp)) |>
    gt::tab_spanner(label = "Performance", columns = c(hp, drat)) |>
    gt::tab_spanner(label = "Numeric",
                     columns = c(cyl, disp, hp, drat),
                     level = 2L)
  rows <- rtfreporter:::.extract_spanners(g)
  expect_length(rows, 2L)
  # Top row = level 2 (Numeric covers cols 2-5)
  expect_length(rows[[1L]], 1L)
  expect_s3_class(rows[[1L]][[1L]], "rtf_col_cell")
  expect_identical(rows[[1L]][[1L]]$pos,   c(2L, 5L))
  expect_identical(rows[[1L]][[1L]]$label, "Numeric")
  # Bottom row = level 1 with two spanners
  expect_length(rows[[2L]], 2L)
  expect_identical(rows[[2L]][[1L]]$pos,   c(2L, 3L))
  expect_identical(rows[[2L]][[1L]]$label, "Engine")
  expect_identical(rows[[2L]][[2L]]$pos,   c(4L, 5L))
  expect_identical(rows[[2L]][[2L]]$label, "Performance")
})

test_that(".extract_spanners respects visible_mask (skips hidden columns)", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl", "disp", "hp")]) |>
    gt::cols_hide(disp) |>
    gt::tab_spanner(label = "Engine",      columns = c(cyl, disp)) |>
    gt::tab_spanner(label = "Performance", columns = c(hp))
  mask <- rtfreporter:::.extract_visible_mask(g)
  rows <- rtfreporter:::.extract_spanners(g, visible_mask = mask)
  # Engine originally covers (cyl, disp); disp is hidden, so it
  # collapses to (cyl).  Performance covers (hp) -- still position 3
  # in the VISIBLE space (mpg, cyl, hp).
  expect_length(rows, 1L)
  expect_length(rows[[1L]], 2L)
  expect_identical(rows[[1L]][[1L]]$pos,   2L)         # Engine -> just cyl
  expect_identical(rows[[1L]][[2L]]$pos,   3L)         # Perf   -> just hp
})

# ──────── .gt_to_rtftable_kwargs Phase-B integration ──────────────────────

test_that("kwargs(hidden) drops hidden columns from data", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl", "disp")]) |>
    gt::cols_hide(cyl)
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g, tokens = "hidden")
  expect_identical(names(kw$data), c("mpg", "disp"))
  expect_identical(ncol(kw$data), 2L)
})

test_that("kwargs(widths) returns column_widths_twips at the correct length", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl")]) |>
    gt::cols_width(mpg ~ gt::px(80), cyl ~ gt::px(60))
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g, tokens = "widths")
  expect_identical(kw$column_widths_twips, as.integer(c(1200, 900)))
})

test_that("kwargs(widths) filters widths to visible columns when 'hidden' is active", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl", "disp")]) |>
    gt::cols_hide(cyl) |>
    gt::cols_width(mpg ~ gt::px(80), cyl ~ gt::px(60), disp ~ gt::px(100))
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g,
                                              tokens = c("widths", "hidden"))
  # cyl dropped from data; widths shrink to length 2.
  expect_identical(ncol(kw$data), 2L)
  expect_identical(kw$column_widths_twips, as.integer(c(1200, 1500)))
})

test_that("kwargs(spanning + col_header) stacks spanner rows above the labels", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl", "disp")]) |>
    gt::cols_label(mpg = "MPG", cyl = "Cyl", disp = "Disp") |>
    gt::tab_spanner(label = "Engine", columns = c(cyl, disp))
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g,
                                              tokens = c("col_header", "spanning"))
  # Two-row col_header: spanner row on top, label row on bottom.
  expect_length(kw$col_header, 2L)
  expect_true(is.list(kw$col_header[[1L]]))
  expect_identical(kw$col_header[[2L]], c("MPG", "Cyl", "Disp"))
})

test_that("kwargs(spanning only) falls back to data column names for the bottom row", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl", "disp")]) |>
    gt::tab_spanner(label = "Engine", columns = c(cyl, disp))
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g, tokens = "spanning")
  expect_length(kw$col_header, 2L)
  expect_identical(kw$col_header[[2L]], c("mpg", "cyl", "disp"))
})

# ──────── as_rtftable() Phase-B end-to-end ────────────────────────────────

test_that("as_rtftable(gt, read=TRUE) honours hidden + widths together", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl", "disp")]) |>
    gt::cols_hide(cyl) |>
    gt::cols_width(mpg ~ gt::px(80), cyl ~ gt::px(60),
                   disp ~ gt::px(100))
  tbl <- as_rtftable(g, read = TRUE)
  expect_identical(names(tbl$data), c("mpg", "disp"))
  expect_identical(tbl$column_widths_twips, as.integer(c(1200, 1500)))
})

test_that("as_rtftable() user column_widths_twips beats gt's widths", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl")]) |>
    gt::cols_width(mpg ~ gt::px(80), cyl ~ gt::px(60))
  tbl <- as_rtftable(g, read = TRUE,
                     column_widths_twips = c(2000L, 3000L))
  expect_identical(tbl$column_widths_twips, c(2000L, 3000L))
})

# ──────── rtf_tables Phase-B end-to-end ───────────────────────────────────

test_that("rtf_tables(read_gt = TRUE) renders spanner + labels + hidden cols", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 2)[, c("mpg", "cyl", "disp", "hp", "drat")]) |>
    gt::cols_label(mpg = "MPG", cyl = "Cyl", disp = "Disp",
                   hp = "HP",   drat = "DR") |>
    gt::cols_hide(drat) |>
    gt::tab_spanner(label = "Engine",      columns = c(cyl, disp)) |>
    gt::tab_spanner(label = "Performance", columns = c(hp))
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(g), read_gt = TRUE)
  out <- tempfile(fileext = ".rtf"); on.exit(unlink(out), add = TRUE)
  generate_rtfreport(doc, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Spanner labels present
  expect_match(txt, "Engine")
  expect_match(txt, "Performance")
  # Visible column labels present, hidden ones absent
  for (lbl in c("MPG", "Cyl", "Disp", "HP")) expect_match(txt, lbl)
  expect_false(grepl("DR\\\\cell", txt))     # hidden column not rendered
})

test_that("rtf_tables(read_gt = 'widths') feeds the widths through", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl")]) |>
    gt::cols_width(mpg ~ gt::px(80), cyl ~ gt::px(60))
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(g), read_gt = "widths")
  expect_identical(doc$contents[[1L]]$column_widths_twips,
                   as.integer(c(1200, 900)))
})

test_that("rtf_tables explicit column_widths_twips beats gt's widths", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, c("mpg", "cyl")]) |>
    gt::cols_width(mpg ~ gt::px(80), cyl ~ gt::px(60))
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(g), read_gt = "widths",
               column_widths_twips = c(5000L, 6000L))
  expect_identical(doc$contents[[1L]]$column_widths_twips, c(5000L, 6000L))
})

# ============================================================================
# Phase C: footnotes, stub
# ============================================================================

# ──────── .extract_footnote_texts ─────────────────────────────────────────

test_that(".extract_footnote_texts returns NULL when no footnotes are set", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, "mpg", drop = FALSE])
  expect_null(rtfreporter:::.extract_footnote_texts(g))
})

test_that(".extract_footnote_texts collects every gt footnote anchor", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 2)[, c("mpg", "cyl")]) |>
    gt::tab_footnote(footnote = "Note A",
                     locations = gt::cells_column_labels(columns = mpg)) |>
    gt::tab_footnote(footnote = gt::md("**Note B**"),
                     locations = gt::cells_body(columns = cyl, rows = 1)) |>
    gt::tab_footnote(footnote = "Standalone note")
  out <- rtfreporter:::.extract_footnote_texts(g)
  expect_length(out, 3L)
  expect_true("Note A" %in% out)
  expect_true("**Note B**" %in% out)         # markdown flattened to raw
  expect_true("Standalone note" %in% out)
})

# ──────── .extract_stub_info ──────────────────────────────────────────────

test_that(".extract_stub_info returns NULL when no stub features are used", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 2)[, c("mpg", "cyl")])
  expect_null(rtfreporter:::.extract_stub_info(g))
})

test_that(".extract_stub_info captures stubhead label + groupname + stub vars", {
  skip_if_not_installed("gt")
  df <- data.frame(
    grp = c("A","A","B","B","C"),
    sub = c("x","y","x","y","x"),
    val = c(10,20,30,40,50)
  )
  g <- gt::gt(df, groupname_col = "grp", rowname_col = "sub") |>
    gt::tab_stubhead(label = "Category")
  info <- rtfreporter:::.extract_stub_info(g)
  expect_identical(info$stubhead_label, "Category")
  expect_identical(info$groupname_var,  "grp")
  expect_identical(info$stub_var,       "sub")
  expect_identical(info$group_id,       c("A","A","B","B","C"))
  expect_identical(info$group_label,    c("A","A","B","B","C"))
})

# ──────── .interleave_group_rows ──────────────────────────────────────────

test_that(".interleave_group_rows inserts a header row at every group change", {
  df <- data.frame(item = c("x","y","z"), val = c(1L, 2L, 3L),
                   stringsAsFactors = FALSE)
  out <- rtfreporter:::.interleave_group_rows(df,
                                               group_per_row = c("A","A","B"),
                                               group_label_per_row = c("A","A","B"))
  expect_identical(nrow(out), 5L)
  expect_identical(out$item, c("A","x","y","B","z"))
  expect_identical(out$val,  c("","1","2","","3"))    # other cols emptied
})

test_that(".interleave_group_rows is a no-op for empty input or mismatched lengths", {
  # The function now also attaches an "orig_to_new" row-mapping attribute;
  # strip it before comparing the data portion.
  strip <- function(x) { attr(x, "orig_to_new") <- NULL; x }
  df0 <- data.frame()
  expect_identical(
    strip(rtfreporter:::.interleave_group_rows(df0, character(0), character(0))),
    df0)
  df1 <- data.frame(a = 1:3, b = c("x","y","z"), stringsAsFactors = FALSE)
  expect_identical(
    strip(rtfreporter:::.interleave_group_rows(
      df1,
      group_per_row = c("A","B"),         # wrong length
      group_label_per_row = c("A","B"))),
    df1
  )
  # Identity mapping when lengths mismatch (no-op path).
  out <- rtfreporter:::.interleave_group_rows(df1, c("A","B"), c("A","B"))
  expect_identical(attr(out, "orig_to_new"), 1:3)
})

# ──────── .gt_to_rtftable_kwargs Phase-C integration ──────────────────────

test_that("kwargs('footnotes' + 'source_notes') puts footnotes ABOVE source notes", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)[, "mpg", drop = FALSE]) |>
    gt::tab_footnote(footnote = "FN1",
                     locations = gt::cells_column_labels(columns = mpg)) |>
    gt::tab_source_note("SRC1")
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g,
                                              tokens = c("footnotes",
                                                          "source_notes"))
  expect_identical(kw$footnotes_block, c("FN1", "SRC1"))
})

test_that("kwargs('footnotes' only) -> footnote texts only in block", {
  skip_if_not_installed("gt")
  g <- gt::gt(head(mtcars, 1)) |>
    gt::tab_footnote(footnote = "FN1")
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g, tokens = "footnotes")
  expect_identical(kw$footnotes_block, "FN1")
})

test_that("kwargs('stub') drops the groupname_col + interleaves group rows", {
  skip_if_not_installed("gt")
  df <- data.frame(
    grp = c("A","A","B","B","C"),
    sub = c("x","y","x","y","x"),
    val = c(10,20,30,40,50)
  )
  g <- gt::gt(df, groupname_col = "grp", rowname_col = "sub")
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g, tokens = "stub")
  # Data loses the groupname_col and gains 3 transition rows (one per
  # unique group: A, B, C).
  expect_identical(names(kw$data), c("sub", "val"))
  expect_identical(nrow(kw$data), 8L)
  expect_identical(kw$data$sub,
                   c("A", "x", "y", "B", "x", "y", "C", "x"))
})

test_that("kwargs('stub' + 'col_header') applies stubhead label to col 1", {
  skip_if_not_installed("gt")
  df <- data.frame(grp = c("A","B"), sub = c("x","y"), val = c(1,2))
  g <- gt::gt(df, groupname_col = "grp", rowname_col = "sub") |>
    gt::cols_label(sub = "S", val = "V") |>
    gt::tab_stubhead(label = "Stubhead")
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g,
                                              tokens = c("stub", "col_header"))
  expect_identical(kw$col_header, c("Stubhead", "V"))
})

test_that("kwargs('stub') stubhead survives a spanner stack as the bottom-row label", {
  skip_if_not_installed("gt")
  df <- data.frame(grp = c("A","B"), sub = c("x","y"), val = c(1,2))
  g <- gt::gt(df, groupname_col = "grp", rowname_col = "sub") |>
    gt::cols_label(sub = "S", val = "V") |>
    gt::tab_stubhead(label = "Stubhead") |>
    gt::tab_spanner(label = "Joint", columns = c(sub, val))
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g,
                                              tokens = c("stub", "col_header",
                                                          "spanning"))
  # Two-row col_header; bottom row uses the stubhead label as col 1.
  expect_length(kw$col_header, 2L)
  expect_identical(kw$col_header[[2L]], c("Stubhead", "V"))
})

test_that("kwargs('stub' + 'hidden' together) drops both row_group and hidden cols", {
  skip_if_not_installed("gt")
  df <- data.frame(grp = c("A","B"), sub = c("x","y"),
                    val = c(1,2), extra = c(99,99))
  g <- gt::gt(df, groupname_col = "grp", rowname_col = "sub") |>
    gt::cols_hide(extra)
  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g,
                                              tokens = c("stub", "hidden"))
  expect_identical(names(kw$data), c("sub", "val"))
  expect_identical(nrow(kw$data), 4L)              # 2 data + 2 group rows
})

# ──────── as_rtftable() Phase-C end-to-end ────────────────────────────────

test_that("as_rtftable() with read=TRUE materialises stub group rows into data", {
  skip_if_not_installed("gt")
  df <- data.frame(grp = c("A","A","B"), sub = c("x","y","z"), val = c(1,2,3))
  g  <- gt::gt(df, groupname_col = "grp", rowname_col = "sub")
  tbl <- as_rtftable(g, read = TRUE)
  expect_identical(names(tbl$data), c("sub", "val"))
  expect_identical(nrow(tbl$data), 5L)
})

# ──────── rtf_tables() Phase-C end-to-end ─────────────────────────────────

test_that("rtf_tables(read_gt=TRUE) renders stub group rows + footnote block", {
  skip_if_not_installed("gt")
  df <- data.frame(grp = c("Grp1","Grp1","Grp2"),
                    sub = c("Sub A","Sub B","Sub C"),
                    val = c(10,20,30))
  g <- gt::gt(df, groupname_col = "grp", rowname_col = "sub") |>
    gt::cols_label(sub = "Stub", val = "Value") |>
    gt::tab_stubhead(label = "Category") |>
    gt::tab_footnote(footnote = "Footnote text") |>
    gt::tab_source_note("Source text")

  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(g), read_gt = TRUE)

  # col_header[1] = stubhead label
  expect_identical(unlist(doc$contents[[1L]]$col_header[[1L]]),
                   c("Category", "Value"))
  # data has both group rows interleaved
  expect_identical(doc$contents[[1L]]$data$sub,
                   c("Grp1", "Sub A", "Sub B", "Grp2", "Sub C"))
  # footnote block = (footnote text, then source text)
  expect_identical(doc$footnotes[[1L]], c("Footnote text", "Source text"))

  # End-to-end render and grep the body for the labels.
  out <- tempfile(fileext = ".rtf"); on.exit(unlink(out), add = TRUE)
  generate_rtfreport(doc, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(txt, "Category")
  expect_match(txt, "Grp1")
  expect_match(txt, "Sub A")
  expect_match(txt, "Footnote text")
  expect_match(txt, "Source text")
})


# ──────── Phase D: styles / footnote_marks / strip_html ──────────────────────

test_that("Phase D: cell_styles extracted from _styles (bold + indent)", {
  skip_if_not_installed("gt")
  df <- data.frame(a = c("x", "y", "z"), b = c(1L, 2L, 3L),
                   stringsAsFactors = FALSE)
  g <- gt::gt(df) |>
    gt::tab_style(style = gt::cell_text(weight = "bold"),
                  locations = gt::cells_body(rows = 1)) |>
    gt::tab_style(style = gt::cell_text(indent = gt::px(20)),
                  locations = gt::cells_body(rows = 2))

  tbl <- as_rtftable(g, read = TRUE)
  cs  <- tbl$cell_styles

  expect_false(is.null(cs))
  # Row 1: bold should be TRUE for all columns
  expect_true(all(isTRUE(cs[[1L]]$bold[1L]),
                  isTRUE(cs[[1L]]$bold[2L])))
  # Row 2: indent should be 20px * 15 = 300 twips for all columns
  expect_equal(cs[[2L]]$indent_twips[1L], 300L)
  expect_equal(cs[[2L]]$indent_twips[2L], 300L)
  # Row 3: no override (NULL)
  expect_null(cs[[3L]])
})

test_that("Phase D: cell_styles applied -- bold row generates \b in RTF", {
  skip_if_not_installed("gt")
  df <- data.frame(x = c("hello", "world"), stringsAsFactors = FALSE)
  g  <- gt::gt(df) |>
    gt::tab_style(style = gt::cell_text(weight = "bold"),
                  locations = gt::cells_body(rows = 1))

  tbl <- as_rtftable(g, read = TRUE)
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(tbl))

  out <- tempfile(fileext = ".rtf"); on.exit(unlink(out), add = TRUE)
  generate_rtfreport(doc, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "")
  # Bold markup must appear somewhere in the output
  expect_match(txt, "\\\\b ")
})

test_that("Phase D: indent applied -- \\\\li > baseline in RTF", {
  skip_if_not_installed("gt")
  df <- data.frame(x = c("flat", "indented"), stringsAsFactors = FALSE)
  g  <- gt::gt(df) |>
    gt::tab_style(style = gt::cell_text(indent = gt::px(20)),
                  locations = gt::cells_body(rows = 2))

  tbl <- as_rtftable(g, read = TRUE)
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(tbl))

  out <- tempfile(fileext = ".rtf"); on.exit(unlink(out), add = TRUE)
  generate_rtfreport(doc, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "")
  # \li300 or higher (300 = 20px * 15 twips/px) must appear for the indented row
  expect_match(txt, "\\li[3-9][0-9]{2,}")
})

test_that("Phase D: footnote_marks converts gt's HTML marks to superscript", {
  skip_if_not_installed("gt")
  df <- data.frame(a = c("x", "y"), b = c(1L, 2L), stringsAsFactors = FALSE)
  g  <- gt::gt(df) |>
    gt::tab_footnote(footnote = "Note one",
                     locations = gt::cells_body(rows = 1, columns = a))

  tbl <- as_rtftable(g, read = c("col_header", "footnote_marks"))
  # gt embeds <sup>1</sup>; we convert it to ^{1} markup (single mark only).
  expect_match(tbl$data$a[1L], "\\^\\{1\\}", fixed = FALSE)
  # No residual HTML span/sup tags left behind.
  expect_false(grepl("<sup>|gt_footnote_marks", tbl$data$a[1L]))
  # The mark must not be duplicated.
  expect_equal(lengths(regmatches(tbl$data$a[1L],
                                  gregexpr("\\^\\{", tbl$data$a[1L]))), 1L)
  # Other cells unchanged.
  expect_false(grepl("^{", tbl$data$a[2L], fixed = TRUE))
})

test_that("Phase D regression: styles land on correct row after stub interleave", {
  skip_if_not_installed("gt")
  df <- data.frame(grp = c("G1", "G1", "G2", "G2"),
                   sub = c("a", "b", "c", "d"),
                   val = c(10, 20, 30, 40), stringsAsFactors = FALSE)
  g <- gt::gt(df, groupname_col = "grp", rowname_col = "sub") |>
    gt::tab_style(style = gt::cell_text(weight = "bold"),
                  locations = gt::cells_body(rows = 4))  # original row 4 = "d"

  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g,
          tokens = rtfreporter:::.GT_TOKENS_ALL)
  # After interleaving group-header rows, "d" sits at physical row 6.
  d_row <- which(kw$data$sub == "d")
  expect_equal(d_row, 6L)
  # Bold must be on physical row 6, NOT on the inserted "G2" header (row 4).
  expect_true(isTRUE(kw$cell_styles[[6L]]$bold[2L]))
  expect_null(kw$cell_styles[[4L]])
})

test_that("Phase D regression: footnote mark lands on correct row after stub", {
  skip_if_not_installed("gt")
  df <- data.frame(grp = c("G1", "G1", "G2", "G2"),
                   sub = c("a", "b", "c", "d"),
                   val = c(10, 20, 30, 40), stringsAsFactors = FALSE)
  g <- gt::gt(df, groupname_col = "grp", rowname_col = "sub") |>
    gt::tab_footnote("Note X",
                     locations = gt::cells_body(rows = 4, columns = val))

  kw <- rtfreporter:::.gt_to_rtftable_kwargs(g,
          tokens = rtfreporter:::.GT_TOKENS_ALL)
  d_row <- which(kw$data$sub == "d")
  expect_match(kw$data$val[d_row], "\\^\\{1\\}")
  # The inserted G2 header row (4) must NOT carry the mark.
  expect_false(grepl("\\^\\{", kw$data$val[4L]))
})

test_that("Phase D: .strip_html_from_df removes tags, converts <br> to newline", {
  # Test the helper directly -- no gt object needed.
  df  <- data.frame(a = c("<b>bold</b>", "plain", "<br/>line2",
                           "<span style='color:red'>red</span>"),
                    b = c(1L, 2L, 3L, 4L),   # integer column: must be untouched
                    stringsAsFactors = FALSE)
  out <- rtfreporter:::.strip_html_from_df(df)
  expect_equal(out$a[1L], "bold")
  expect_equal(out$a[2L], "plain")
  expect_equal(out$a[3L], "\nline2")
  expect_equal(out$a[4L], "red")
  # Integer column unchanged
  expect_equal(out$b, c(1L, 2L, 3L, 4L))
})

test_that("Phase D: cell_styles NULL when read = FALSE", {
  skip_if_not_installed("gt")
  df <- data.frame(x = 1:3)
  g  <- gt::gt(df) |>
    gt::tab_style(style = gt::cell_text(weight = "bold"),
                  locations = gt::cells_body(rows = 1))
  tbl <- as_rtftable(g, read = FALSE)
  expect_null(tbl$cell_styles)
})

test_that("Phase D: rtftable() cell_styles argument wires through to renderer", {
  df <- data.frame(a = c("row1", "row2"), b = c(10L, 20L))
  cs <- list(
    list(bold = c(TRUE, FALSE), italic = c(NA, NA),
         underline = c(NA, NA), indent_twips = c(NA_integer_, NA_integer_)),
    NULL
  )
  tbl <- rtftable(df, cell_styles = cs)
  expect_equal(tbl$cell_styles, cs)

  # Render and verify \b appears for row 1 col 1
  doc <- rtf_document() |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(list(tbl))
  out <- tempfile(fileext = ".rtf"); on.exit(unlink(out), add = TRUE)
  generate_rtfreport(doc, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "")
  expect_match(txt, "\\b ")
})
