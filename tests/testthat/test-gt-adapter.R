# Phase A GT integration: as_rtftable() + rtf_tables(read_gt = ...)
#
# All tests skip when the optional `gt` package is not installed so
# CRAN runs without gt still pass.

# ──────── .resolve_gt_tokens ──────────────────────────────────────────────

test_that(".resolve_gt_tokens(FALSE / NULL) -> empty", {
  expect_identical(rtfreporter:::.resolve_gt_tokens(FALSE), character(0))
  expect_identical(rtfreporter:::.resolve_gt_tokens(NULL),  character(0))
})

test_that(".resolve_gt_tokens(TRUE) -> the four Phase-A tokens", {
  tk <- rtfreporter:::.resolve_gt_tokens(TRUE)
  expect_setequal(tk, c("col_header", "alignment", "titles", "source_notes"))
})

test_that(".resolve_gt_tokens accepts a subset", {
  tk <- rtfreporter:::.resolve_gt_tokens(c("col_header", "titles"))
  expect_setequal(tk, c("col_header", "titles"))
})

test_that(".resolve_gt_tokens warns on Phase-B/C tokens and silently drops them", {
  expect_warning(
    tk <- rtfreporter:::.resolve_gt_tokens(c("col_header", "spanning",
                                              "footnotes")),
    "does not yet implement"
  )
  expect_setequal(tk, "col_header")
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
