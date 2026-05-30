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
#  Tokens recognised today (Phases A + B + C):
#    "col_header"   -- column labels         (from _boxhead$column_label)
#    "alignment"    -- per-column alignment   (from _boxhead$column_align)
#    "titles"       -- title + subtitle      (from _heading)
#    "source_notes" -- source notes          (from _source_notes)
#    "spanning"     -- multi-level spanners  (from _spanners)
#    "widths"       -- per-column widths      (from _boxhead$column_width)
#    "hidden"       -- drop hidden columns   (boxhead$type == "hidden")
#    "footnotes"    -- table-level footnotes  (from _footnotes; appended
#                                              to the page footnote block
#                                              alongside source_notes)
#    "stub"         -- groupname_col rows + stubhead label
#                       (from _stub_df, _stubhead, boxhead$type)
#
#  All markdown_text fields are flattened to their raw character form
#  via as.character() -- v0.1.0 does not translate Markdown into
#  rtfreporter's `^{...}` / `_{...}` cell markup.


# ── Tokens recognised by `read_gt = ...` ─────────────────────────────────

# Phase A: the four "shape-preserving" attributes.
.GT_TOKENS_PHASE_A <- c("col_header", "alignment", "titles", "source_notes")

# Phase B (v0.0.39): structural attributes that may change the rendered
# data shape (drop hidden columns, force absolute widths) or layer extra
# header rows (spanners).
.GT_TOKENS_PHASE_B <- c("spanning", "widths", "hidden")

# Phase C (v0.0.40): table-level footnotes and stub support.
#
# "footnotes" is table-level only -- the texts are appended to the page's
# footnote block, but no mark glyphs are injected into the body cells.
# Cell-mark injection is deferred to a later release.
#
# "stub" supports two transformations:
#   1. The groupname_col (boxhead type == "row_group") is dropped from
#      the data and group-transition rows are interleaved into the body
#      where _stub_df$group_id changes.  Each transition row carries
#      the group label in the leftmost cell.
#   2. _stubhead$label is used as the column-header label for the stub
#      column (boxhead type == "stub") when col_header is also active.
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
  if (isTRUE(read_gt))                       return(.GT_TOKENS_ALL)
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
  read_gt
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


# ── Phase B extractors ───────────────────────────────────────────────────

# Logical mask: which boxhead columns are visible (type != "hidden")?
# Length == nrow(boxhead) == ncol(as.data.frame(gt_obj)).
.extract_visible_mask <- function(gt_obj) {
  boxh <- gt_obj[["_boxhead"]]
  if (is.null(boxh) || !"type" %in% names(boxh)) return(NULL)
  as.character(boxh$type) != "hidden"
}

# Convert one gt column_width entry to (kind, value).  Returns a list
# `list(kind = "px"/"pct"/"unknown", value = double)`.  Missing widths
# return `list(kind = "missing", value = NA_real_)`.
.parse_one_width <- function(w) {
  while (is.list(w) && length(w)) w <- w[[1L]]
  if (is.null(w) || is.na(w) || !nzchar(as.character(w))) {
    return(list(kind = "missing", value = NA_real_))
  }
  s <- trimws(as.character(w))
  if (grepl("^[0-9.]+\\s*px$", s, ignore.case = TRUE)) {
    v <- as.numeric(sub("\\s*px\\s*$", "", s, ignore.case = TRUE))
    return(list(kind = "px",  value = v))
  }
  if (grepl("^[0-9.]+\\s*%$", s)) {
    v <- as.numeric(sub("\\s*%\\s*$", "", s))
    return(list(kind = "pct", value = v))
  }
  list(kind = "unknown", value = NA_real_)
}

# Extract per-column widths.  Returns one of:
#   list(column_widths_twips = <int vec>)  -- all widths in px
#   list(col_rel_width       = <num vec>)  -- all widths in %
#   NULL                                   -- mixed, all missing, or
#                                             unparsable
# `widths_px_to_twips`: gt's px values map to RTF twips at 1 px = 15 twips
# (CSS-style 96 dpi convention).
.extract_widths <- function(gt_obj) {
  boxh <- gt_obj[["_boxhead"]]
  if (is.null(boxh) || !"column_width" %in% names(boxh)) return(NULL)
  parsed <- lapply(boxh$column_width, .parse_one_width)
  kinds  <- vapply(parsed, function(x) x$kind, character(1L))
  vals   <- vapply(parsed, function(x) x$value, numeric(1L))

  if (all(kinds == "missing"))            return(NULL)
  if (any(kinds == "unknown"))            return(NULL)   # bail out
  if (any(kinds == "missing"))            return(NULL)   # all-or-none

  if (all(kinds == "px")) {
    return(list(column_widths_twips = as.integer(round(vals * 15))))
  }
  if (all(kinds == "pct")) {
    return(list(col_rel_width = vals))
  }
  # Mixed units -- conservative fallback (gt allows it for HTML, but
  # we can't reliably translate to twips without knowing the table
  # width).
  NULL
}

# Extract the spanning header rows.  Returns a list of rows ready to
# stack ABOVE the bottom label row inside an rtf_col_header.  Each row
# is itself a list of col_cell() values.  Empty list -> no spanners.
#
# `visible_mask` (logical, length == nrow(boxhead)): columns that will
# actually appear in the rendered table.  Spanners covering only
# hidden columns are dropped.  The pos = c(from, to) in each emitted
# col_cell is calculated against `visible_vars`, not the raw boxhead
# order.
.extract_spanners <- function(gt_obj, visible_mask = NULL) {
  spans <- gt_obj[["_spanners"]]
  if (is.null(spans) || !nrow(spans)) return(list())
  boxh <- gt_obj[["_boxhead"]]
  if (is.null(boxh)) return(list())
  if (is.null(visible_mask)) visible_mask <- rep(TRUE, nrow(boxh))
  visible_vars <- as.character(boxh$var)[visible_mask]
  if (!length(visible_vars)) return(list())

  # Group by spanner_level (descending = top-to-bottom rendering).
  levels_desc <- sort(unique(as.integer(spans$spanner_level)), decreasing = TRUE)
  rows <- list()
  for (lv in levels_desc) {
    spans_lv <- spans[as.integer(spans$spanner_level) == lv, , drop = FALSE]
    cells <- list()
    for (j in seq_len(nrow(spans_lv))) {
      vars  <- as.character(spans_lv$vars[[j]])
      vars  <- intersect(vars, visible_vars)
      if (!length(vars)) next
      idx <- match(vars, visible_vars)
      # Spanners must cover a contiguous range to be valid in rtf_col_header.
      if (any(diff(sort(idx)) != 1L)) next        # skip non-contiguous
      pos <- if (length(idx) == 1L) idx else c(min(idx), max(idx))
      label <- .flatten_to_chr(spans_lv$spanner_label[[j]])
      if (is.na(label)) label <- ""
      cells[[length(cells) + 1L]] <- col_cell(pos = pos, label = label)
    }
    if (length(cells)) rows[[length(rows) + 1L]] <- cells
  }
  rows
}


# ── Phase C extractors ───────────────────────────────────────────────────

# Extract table-level footnote texts.  Returns a character vector (or
# NULL when none are set).  All footnote anchors (column-label,
# cell-level, table-level, etc.) are flattened into a single list of
# texts -- cell-mark injection is out of scope for this release.
.extract_footnote_texts <- function(gt_obj) {
  fn <- gt_obj[["_footnotes"]]
  if (is.null(fn) || !nrow(fn)) return(NULL)
  # The `footnotes` column is a list; each entry may be character or
  # markdown_text.  Flatten and concatenate same-anchor entries with " ".
  out <- vapply(fn$footnotes, function(ft) {
    if (is.null(ft) || !length(ft)) return(NA_character_)
    v <- vapply(seq_along(ft),
                function(i) .flatten_to_chr(ft[[i]]),
                character(1L))
    v <- v[!is.na(v)]
    if (!length(v)) NA_character_ else paste(v, collapse = " ")
  }, character(1L))
  out <- out[!is.na(out)]
  if (!length(out)) return(NULL)
  unname(out)
}

# Extract stub-related info: stubhead label, the groupname column name
# (boxhead type == "row_group"), and per-row group_id / group_label
# vectors from _stub_df.  Returns NULL when no stub features are in use.
.extract_stub_info <- function(gt_obj) {
  boxh     <- gt_obj[["_boxhead"]]
  stubhead <- gt_obj[["_stubhead"]]
  stub_df  <- gt_obj[["_stub_df"]]

  result <- list()
  if (!is.null(stubhead) && !is.null(stubhead$label)) {
    result$stubhead_label <- .flatten_to_chr(stubhead$label)
  }
  if (!is.null(boxh) && "type" %in% names(boxh)) {
    groupname_var <- as.character(boxh$var)[boxh$type == "row_group"]
    stub_var      <- as.character(boxh$var)[boxh$type == "stub"]
    if (length(groupname_var)) result$groupname_var <- groupname_var[1L]
    if (length(stub_var))      result$stub_var      <- stub_var[1L]
  }
  if (!is.null(stub_df) && nrow(stub_df) > 0L &&
      "group_id" %in% names(stub_df)) {
    gids <- as.character(stub_df$group_id)
    if (!all(is.na(gids))) {
      result$group_id <- gids
      if ("group_label" %in% names(stub_df)) {
        result$group_label <- vapply(stub_df$group_label,
                                      .flatten_to_chr,
                                      character(1L))
      } else {
        result$group_label <- gids
      }
    }
  }
  if (length(result)) result else NULL
}

# Insert group-transition rows into a data.frame.  Whenever
# `group_per_row[i] != group_per_row[i-1]` (or i == 1), a fresh row is
# inserted with `group_label_per_row[i]` in the first column and
# empty strings (or NA cast to "") in every other column.
.interleave_group_rows <- function(df, group_per_row, group_label_per_row) {
  if (nrow(df) == 0L) return(df)
  if (length(group_per_row) != nrow(df)) return(df)
  prev <- NA_character_
  pieces <- list()
  for (i in seq_len(nrow(df))) {
    g <- group_per_row[[i]]
    if (!identical(g, prev)) {
      header_row <- df[i, , drop = FALSE]
      # First column gets the group label, every other column blanks.
      for (j in seq_len(ncol(header_row))) {
        header_row[1L, j] <- if (j == 1L) group_label_per_row[[i]] else ""
      }
      pieces[[length(pieces) + 1L]] <- header_row
    }
    pieces[[length(pieces) + 1L]] <- df[i, , drop = FALSE]
    prev <- g
  }
  out <- do.call(rbind, pieces)
  rownames(out) <- NULL
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
  # Always pull the rendered body -- this is the baseline data.frame.
  out$data <- as.data.frame(gt_obj, stringsAsFactors = FALSE)

  # ---- "hidden" and "stub": compute the effective visible mask ------
  # gt's `as.data.frame()` keeps every column (including hidden ones
  # and the groupname_col).  We compute a single visible mask that
  # honours both tokens:
  #
  #   "hidden" active -> drop boxhead.type == "hidden"
  #   "stub"   active -> drop boxhead.type == "row_group" (becomes
  #                       interleaved group-transition rows; see below)
  #
  # The same mask is used by every downstream extractor so the
  # extracted col_header / alignment / widths / spanner positions all
  # align with the final, visible-only column space.
  hidden_active <- "hidden" %in% tokens
  stub_active   <- "stub"   %in% tokens
  boxh          <- gt_obj[["_boxhead"]]
  raw_mask      <- .extract_visible_mask(gt_obj)
  if (is.null(raw_mask)) raw_mask <- rep(TRUE, ncol(out$data))

  drop_mask <- rep(FALSE, length(raw_mask))
  if (hidden_active)                drop_mask <- drop_mask | !raw_mask
  if (stub_active && !is.null(boxh) && "type" %in% names(boxh)) {
    drop_mask <- drop_mask | (as.character(boxh$type) == "row_group")
  }
  visible_mask <- !drop_mask

  if (any(drop_mask)) {
    keep_vars   <- as.character(boxh$var)[visible_mask]
    keep_in_df  <- intersect(keep_vars, names(out$data))
    out$data    <- out$data[, keep_in_df, drop = FALSE]
  }

  # ---- "col_header": column labels (filtered by visible_mask) -------
  if ("col_header" %in% tokens) {
    labs <- .extract_col_labels(gt_obj)
    if (!is.null(labs) && length(labs) == length(visible_mask)) {
      labs_v <- labs[visible_mask]
      if (length(labs_v) == ncol(out$data)) out$col_header <- labs_v
    }
  }

  # ---- "alignment": per-column align (filtered by visible_mask) -----
  if ("alignment" %in% tokens) {
    aln <- .extract_col_align(gt_obj)
    if (!is.null(aln) && length(aln) == length(visible_mask)) {
      aln_v <- aln[visible_mask]
      if (length(aln_v) == ncol(out$data)) {
        out$col_spec <- lapply(seq_along(aln_v), function(j) {
          list(col = j, align = aln_v[[j]])
        })
      }
    }
  }

  # ---- "widths": column widths -> column_widths_twips or col_rel_width
  if ("widths" %in% tokens) {
    w <- .extract_widths(gt_obj)
    if (!is.null(w)) {
      # If hidden columns are dropped, filter the width vector too.
      if (!is.null(w$column_widths_twips)) {
        v <- w$column_widths_twips[visible_mask]
        if (length(v) == ncol(out$data)) out$column_widths_twips <- v
      } else if (!is.null(w$col_rel_width)) {
        v <- w$col_rel_width[visible_mask]
        if (length(v) == ncol(out$data)) out$col_rel_width <- v
      }
    }
  }

  # ---- "spanning": multi-level spanner rows above the labels --------
  # Built into a multi-row `col_header` argument so the renderer treats
  # it as a stacked header.  Combines with the bottom-row labels:
  #   * If "col_header" was already extracted, use it as bottom row.
  #   * Else fall back to the visible data column names.
  if ("spanning" %in% tokens) {
    span_rows <- .extract_spanners(gt_obj, visible_mask = visible_mask)
    if (length(span_rows)) {
      bottom_row <- if (!is.null(out$col_header))
                      out$col_header
                    else
                      names(out$data)
      # Replace the flat character vector with a multi-row list.
      out$col_header <- c(span_rows, list(bottom_row))
    }
  }

  # ---- "stub": apply the stubhead label + interleave group rows -----
  if (stub_active) {
    stub <- .extract_stub_info(gt_obj)
    if (!is.null(stub)) {
      # (a) stubhead label -> first column header (only when we have
      #     a col_header to override; we do not invent one).
      if (!is.null(stub$stubhead_label) &&
          !is.null(out$col_header)) {
        if (is.character(out$col_header) && length(out$col_header) >= 1L) {
          out$col_header[1L] <- stub$stubhead_label
        } else if (is.list(out$col_header) && length(out$col_header) >= 1L) {
          # Multi-row header (spanner case): the bottom row is the
          # label vector.
          bot <- out$col_header[[length(out$col_header)]]
          if (is.character(bot) && length(bot) >= 1L) {
            bot[1L] <- stub$stubhead_label
            out$col_header[[length(out$col_header)]] <- bot
          }
        }
      }
      # (b) Interleave group-transition rows when _stub_df has a
      #     non-NA group_id sequence.
      if (!is.null(stub$group_id) &&
          length(stub$group_id) == nrow(out$data)) {
        out$data <- .interleave_group_rows(
          out$data, stub$group_id, stub$group_label
        )
      }
    }
  }

  # ---- "titles" / "source_notes" / "footnotes": page-level blocks ----
  if ("titles" %in% tokens) {
    out$titles_block <- .extract_titles(gt_obj)
  }
  src_notes <- if ("source_notes" %in% tokens)
                 .extract_source_notes(gt_obj) else NULL
  fn_texts  <- if ("footnotes" %in% tokens)
                 .extract_footnote_texts(gt_obj) else NULL
  if (!is.null(src_notes) || !is.null(fn_texts)) {
    # Convention: footnote anchors come ABOVE source notes, matching
    # gt's vertical layout (footnotes are typeset just under the
    # table body; source notes appear lower).
    out$footnotes_block <- c(fn_texts, src_notes)
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
