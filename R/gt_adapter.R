# ============================================================================
#  gt_adapter -- read configuration from a gt::gt_tbl object
# ============================================================================
#
#  This module bridges gt (Posit's display-table package) and rtfreporter.
#  Users typically build a clinical table with gt's friendly API
#  (`cols_label()`, `tab_header()`, `tab_source_note()`, `cols_align()`,
#  ...) and then want the same metadata to flow into the rtfreporter
#  output without re-stating it.
#
#  Public entry points (declared elsewhere -- this file holds the
#  extraction helpers and the central `.gt_to_rtftable_kwargs()`
#  function used by both):
#
#    * as_rtftable()        -- R/as_rtftable.R
#    * rtf_tables(read_gt=) -- R/pipe-composition.R
#
#  Design notes
#  ------------
#  gt stores every component in a fixed-name slot accessible via the
#  plain `[[` operator: `gt_obj[["_boxhead"]]`, `gt_obj[["_heading"]]`,
#  etc.  We never call gt's internal `dt_*_get()` functions -- the slot
#  contract is stable and public-enough.
#
#  Phase A (this commit) reads four attributes:
#    "col_header"   -- column labels  (from _boxhead$column_label)
#    "alignment"    -- per-column align (from _boxhead$column_align)
#    "titles"       -- title + subtitle (from _heading)
#    "source_notes" -- source notes  (from _source_notes)
#
#  Phase B will add: spanning, widths, hidden.
#  Phase C will add: footnotes (table-level), stub.
#
#  All markdown_text fields are flattened to their raw character form
#  via as.character() -- v0.1.0 does not translate Markdown into
#  rtfreporter's `^{...}` / `_{...}` cell markup.


# ── Tokens recognised by `read_gt = ...` ─────────────────────────────────

# Phase A: the four "shape-preserving" attributes.
.GT_TOKENS_PHASE_A <- c("col_header", "alignment", "titles", "source_notes")

# Future phases (declared here so users can pass them today and get a
# clean "not yet implemented in this rtfreporter version" message rather
# than an unrecognised-token error).
.GT_TOKENS_PHASE_B <- c("spanning", "widths", "hidden")
.GT_TOKENS_PHASE_C <- c("footnotes", "stub")
.GT_TOKENS_ALL     <- c(.GT_TOKENS_PHASE_A,
                        .GT_TOKENS_PHASE_B,
                        .GT_TOKENS_PHASE_C)


# ── Helpers ──────────────────────────────────────────────────────────────

# Is `x` a gt_tbl?  Cheap class check; does not import gt.
.is_gt_tbl <- function(x) inherits(x, "gt_tbl")

# Resolve a `read_gt` argument to a character vector of recognised
# tokens.  Returns character(0) when nothing is requested.
.resolve_gt_tokens <- function(read_gt) {
  if (is.null(read_gt) || isFALSE(read_gt)) return(character(0))
  if (isTRUE(read_gt))                       return(.GT_TOKENS_PHASE_A)
  if (!is.character(read_gt)) {
    stop("`read_gt` must be FALSE/TRUE or a character vector of tokens.",
         call. = FALSE)
  }
  bad <- setdiff(read_gt, .GT_TOKENS_ALL)
  if (length(bad)) {
    stop(sprintf("Unknown `read_gt` token(s): %s.  Allowed: %s",
                 paste(sQuote(bad), collapse = ", "),
                 paste(sQuote(.GT_TOKENS_ALL), collapse = ", ")),
         call. = FALSE)
  }
  not_yet <- intersect(read_gt, c(.GT_TOKENS_PHASE_B, .GT_TOKENS_PHASE_C))
  if (length(not_yet)) {
    warning(sprintf(
      "rtfreporter v0.0.x does not yet implement `read_gt` token(s): %s.  ",
      paste(sQuote(not_yet), collapse = ", ")),
      "These will be ignored for now.  Track at github.com/ichirio/rtfreporter.",
      call. = FALSE)
  }
  intersect(read_gt, .GT_TOKENS_PHASE_A)
}

# Convert a value that might be markdown_text, list-of-1, or NULL into a
# plain character string.  Returns NA_character_ when nothing usable.
.flatten_to_chr <- function(x) {
  if (is.null(x)) return(NA_character_)
  if (length(x) == 0L) return(NA_character_)
  if (is.list(x))  x <- x[[1L]]
  if (is.null(x)) return(NA_character_)
  v <- as.character(x)[1L]
  if (is.na(v) || !nzchar(v)) return(NA_character_)
  v
}


# ── Per-attribute extractors ─────────────────────────────────────────────

# Extract column labels in render order.  Returns a character vector of
# length ncol(as.data.frame(gt_obj)).
.extract_col_labels <- function(gt_obj) {
  boxh <- gt_obj[["_boxhead"]]
  if (is.null(boxh)) return(NULL)
  # Render order: rows in _boxhead are stored in render order already.
  # Hidden columns are NOT dropped in Phase A (that requires `read_gt =
  # "hidden"`, which is Phase B).
  vapply(boxh$column_label, .flatten_to_chr, character(1L))
}

# Extract per-column alignment.  Returns a character vector with values
# "left" / "center" / "right" (gt's only legal values) of length
# ncol(as.data.frame(gt_obj)).
.extract_col_align <- function(gt_obj) {
  boxh <- gt_obj[["_boxhead"]]
  if (is.null(boxh) || !"column_align" %in% names(boxh)) return(NULL)
  as.character(boxh$column_align)
}

# Extract title + subtitle as a character vector suitable for use as
# `titles[[i]]`.  Order: title, subtitle, preheader -- matching gt's
# rendered top-to-bottom order.  Empty / NULL fields are dropped.
.extract_titles <- function(gt_obj) {
  heading <- gt_obj[["_heading"]]
  if (is.null(heading)) return(NULL)
  rows <- c(
    .flatten_to_chr(heading$title),
    .flatten_to_chr(heading$subtitle),
    .flatten_to_chr(heading$preheader)
  )
  rows <- rows[!is.na(rows)]
  if (!length(rows)) return(NULL)
  rows
}

# Extract source notes as a character vector suitable for use as
# `footnotes[[i]]`.  Markdown is flattened to its raw text.
.extract_source_notes <- function(gt_obj) {
  notes <- gt_obj[["_source_notes"]]
  if (is.null(notes) || !length(notes)) return(NULL)
  out <- vapply(notes, .flatten_to_chr, character(1L))
  out <- out[!is.na(out)]
  if (!length(out)) return(NULL)
  out
}


# ── Central mapping: gt_tbl + tokens -> list of rtftable kwargs +
#    page-level titles / footnotes ─────────────────────────────────────

# Returns a list with up to four named elements:
#   * data           -- the data.frame extracted via as.data.frame()
#   * col_header     -- character vector or NULL
#   * col_spec       -- list compatible with `rtftable(col_spec = ...)`
#   * titles_block   -- character vector or NULL (for page title block)
#   * footnotes_block-- character vector or NULL (for page footnote block)
#
# The caller is responsible for merging these with any explicit user
# arguments (explicit always wins).
.gt_to_rtftable_kwargs <- function(gt_obj, tokens = .GT_TOKENS_PHASE_A) {
  if (!.is_gt_tbl(gt_obj)) {
    stop("`gt_obj` must be a gt_tbl.", call. = FALSE)
  }
  if (!requireNamespace("gt", quietly = TRUE)) {
    stop("Reading from a gt_tbl requires the `gt` package.  Install it ",
         "with install.packages(\"gt\").", call. = FALSE)
  }

  out <- list()
  # Always pull the rendered body -- this is what we ALWAYS pass as the
  # data.frame regardless of which extraction tokens are active.
  out$data <- as.data.frame(gt_obj, stringsAsFactors = FALSE)

  if ("col_header" %in% tokens) {
    labs <- .extract_col_labels(gt_obj)
    if (!is.null(labs) && length(labs) == ncol(out$data)) {
      out$col_header <- labs
    }
  }

  if ("alignment" %in% tokens) {
    aln <- .extract_col_align(gt_obj)
    if (!is.null(aln) && length(aln) == ncol(out$data)) {
      # Build a per-column col_spec list.  Each entry is
      # list(col = j, align = aln[j]).  rtftable() merges this with
      # any user-supplied col_spec (explicit wins).
      out$col_spec <- lapply(seq_along(aln), function(j) {
        list(col = j, align = aln[[j]])
      })
    }
  }

  if ("titles" %in% tokens) {
    out$titles_block <- .extract_titles(gt_obj)
  }
  if ("source_notes" %in% tokens) {
    out$footnotes_block <- .extract_source_notes(gt_obj)
  }

  out
}


# ── Internal helper used by rtf_tables(): merge per-page extracted
#    titles / footnotes with the user-supplied ones (user wins) ──────────

# Both arguments may be NULL.  Returns a single character vector or NULL.
.merge_gt_block <- function(user_block, gt_block) {
  if (!is.null(user_block)) return(user_block)   # user wins
  gt_block                                       # else fall back to gt
}
