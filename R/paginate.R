# ============================================================================
#  paginate() -- table-object -> per-page data.frame list
# ============================================================================
#
#  Single public entry point for turning a "table object" (currently
#  `gt::gt`, plain `data.frame` / tibble; rtables and others planned) into
#  a list of data.frames sized for one RTF page each.
#
#  Design notes
#  ------------
#  *  paginate() is an S3 generic.  Each supported input class gets its
#     own method; new types can be added without touching callers.
#  *  paginate.gt_tbl() is the only method that talks to `gt`.  It
#     extracts the rendered body via gt::extract_body() (gt is in
#     Suggests; the method errors with an install hint if gt is missing)
#     and delegates to paginate.data.frame().
#  *  Every method returns the same shape: a list of data.frames, each
#     with two attributes the rest of rtfreporter understands:
#         rtf_blank_rows      integer positions of blank separator rows
#         rtf_paginate_meta   list( strategy, group_col, page_index, ... )
#     so an unmodified `rtf_tables(list)` consumes the result directly.
#  *  The blank-row positions and the group / split logic are deliberately
#     pure-R / pure-data.frame -- they do not touch the renderer, the gt
#     formatting machinery, or any RTF-specific concept.  That keeps the
#     algorithm reusable for future table-object types.
#
#  Splitting strategies (selectable via `split =`)
#  ----------------------------------------------
#    "none"        return the input as one page; no row limit checked.
#    "rows"        cut at the explicit positions in `split_rows`.
#    "group_safe"  pack whole groups onto a page; spill on overflow.
#                  A group that on its own exceeds `max_rows` is
#                  force-split with (Cont.) continuation rows.
#    "group_force" cut every `max_rows`; when the cut falls inside a
#                  group, insert a (Cont.) header row at the top of the
#                  next page repeating the group label without the
#                  summary value.
#
#  Group identification
#  --------------------
#  `group_col = NULL` (default) auto-detects groups from the **first
#  column**: a row whose first column starts with a non-space character
#  opens a new group; subsequent rows starting with a space are sub-rows
#  of the same group.  This matches the standard clinical TFL convention
#  of indenting sub-rows under a parent label.
#
#  `group_col = "name"` or `group_col = 2L` treats consecutive identical
#  values of that column as a single group (RLE-based, order-preserving).
# ============================================================================


# -- Generic -----------------------------------------------------------------

#' Split a table object into per-page data.frames
#'
#' Single entry point that converts various supported table objects into a
#' list of data.frames, one per page, ready to be passed to [rtf_tables()]
#' (each data.frame carries an `rtf_blank_rows` attribute that
#' `rtftable(read_attributes = TRUE)` consumes automatically).
#'
#' Dispatch is by S3 class:
#' * `paginate.gt_tbl()` -- for [gt::gt()] tables.  Requires the optional
#'   `gt` package; an informative error is raised otherwise.
#' * `paginate.data.frame()` -- for plain data.frames / tibbles.  Where the
#'   real work happens; the gt method extracts a data.frame and delegates
#'   here.
#' * `paginate.list()` -- recurses into every element and concatenates the
#'   resulting pages in input order.
#'
#' New table-object types can be supported by adding another
#' `paginate.<class>()` method -- see `vignette("paginate")` for an
#' example.
#'
#' @param x A supported table object (`gt_tbl`, `data.frame`/tibble, or a
#'   `list` of those).
#' @param max_rows Integer.  Maximum body rows per page.  Required for any
#'   `split` mode other than `"none"`.
#' @param split Splitting strategy: `"none"` (default), `"rows"`,
#'   `"group_safe"`, or `"group_force"`.  See **Splitting strategies** in
#'   the package vignette.
#' @param split_rows Integer vector of 1-based row indices at which to
#'   start new pages.  Only used when `split = "rows"`.
#' @param group_col Column name or 1-based index identifying the group.
#'   `NULL` (default) auto-detects groups from **leading-space
#'   indentation** on column 1 — a row whose first column starts with
#'   a non-space character opens a new top-level group; rows whose
#'   first column starts with whitespace are sub-rows of the current
#'   group.  Sub-rows can themselves carry deeper indentation
#'   (sub-sub-rows etc.) — only the top-level rows act as group
#'   boundaries, so a multi-indent block is treated as ONE group for
#'   splitting and blank-row insertion.
#' @param cont_label Suffix appended to the group label on continuation
#'   pages (only used by group-aware splits).  Default `" (Cont.)"`.
#' @param blank_rows Blank-row specification applied *within* each
#'   page.  Resolved positions are stored as the page's
#'   `rtf_blank_rows` attribute, which `rtftable(read_attributes =
#'   TRUE)` consumes.  Accepts:
#'   * `NULL` (default) -- no blank rows added from this argument.
#'   * integer vector -- positions (`0` = before first data row;
#'     `k` = after data row `k`).
#'   * `"between_groups"` -- auto-insert a blank row at every group
#'     transition within the page (same indent-based group detection
#'     as the split modes).
#'   * `list(...)` of any of the above -- union of positions.
#' @param blank_row_first Logical, default `FALSE`.  When `TRUE`,
#'   *every* returned page also gets a blank row at the top (position
#'   `0`).  Combined with `blank_rows = "between_groups"` this gives
#'   the "blank before each group, including the first on every page"
#'   pattern that clinical TFL layouts often want.
#' @param blank_row_end Logical, default `FALSE`.  When `TRUE`,
#'   *every* returned page also gets a blank row at the bottom (after
#'   the page's last data row).  Useful when the last data row needs
#'   visual separation from the page footer.
#' @param ... Method-specific extras.
#'
#' @return A list of data.frames, one per page.  Each carries:
#'   * `attr(., "rtf_blank_rows")` -- integer positions consumed by
#'     [rtftable()] when `read_attributes = TRUE`.
#'   * `attr(., "rtf_paginate_meta")` -- list with `strategy`,
#'     `page_index`, `total_pages`, `group_col`.
#'
#' @examples
#' # -------------------------------------------------------------------------
#' # 1. Indent-based grouping (default)
#' #
#' # Column 1 carries the visual hierarchy via leading whitespace:
#' #   "Demographics"   - non-space first char -> opens group 1
#' #   "    Age"        - leading space         -> sub-row of group 1
#' #   "        Female" - deeper indent         -> still group 1
#' #   "Vital signs"    - non-space first char -> opens group 2
#' #   ... etc.
#' # No `group_col` argument is needed; the indent IS the signal.
#' # -------------------------------------------------------------------------
#' df <- data.frame(
#'   label = c(
#'     "Demographics",
#'     "    Age, mean (SD)",
#'     "    Sex, n (%)",
#'     "        Female",
#'     "        Male",
#'     "Vital signs",
#'     "    Systolic BP",
#'     "    Diastolic BP",
#'     "    Heart rate",
#'     "Lab values",
#'     "    Hemoglobin",
#'     "    Platelets"
#'   ),
#'   v = 1:12,
#'   stringsAsFactors = FALSE
#' )
#'
#' pages <- paginate(
#'   df,
#'   max_rows        = 6,                  # at most 6 body rows / page
#'   split           = "group_safe",       # never break a group across pages
#'   blank_rows      = "between_groups",   # blank row between consecutive groups
#'   blank_row_first = TRUE,               # also a blank at the page top
#'   blank_row_end   = TRUE                # also a blank at the page bottom
#' )
#'
#' length(pages)                           # 3 pages (Demo / Vital / Lab)
#' lapply(pages, function(p) p$label)
#' lapply(pages, attr, "rtf_blank_rows")   # e.g. page 1: c(0, 5)
#'
#' \dontrun{
#' # -------------------------------------------------------------------------
#' # 2. End-to-end: rtf_tables() picks up the blank-row attribute
#' # -------------------------------------------------------------------------
#' doc <- rtf_document() |>
#'   rtf_section(page = 1, secinfo = list(header = my_hdr)) |>
#'   rtf_tables(pages)         # one page per data.frame
#' generate_rtfreport(doc, "demo.rtf", overwrite = TRUE)
#'
#' # -------------------------------------------------------------------------
#' # 3. gt input — same arguments, just hand a gt_tbl in
#' # -------------------------------------------------------------------------
#' pages <- paginate(my_gt_tbl, max_rows = 20, split = "group_force")
#'
#' # -------------------------------------------------------------------------
#' # 4. List of gt tables (e.g. one per table number) — recurses and flattens
#' # -------------------------------------------------------------------------
#' all_pages <- paginate(list(t1_gt, t2_gt), max_rows = 20,
#'                       split = "group_force")
#'
#' # -------------------------------------------------------------------------
#' # 5. Explicit group_col when the grouping signal isn't column 1's indent
#' # -------------------------------------------------------------------------
#' pages <- paginate(df, max_rows = 30, split = "group_safe",
#'                    group_col = "Visit")     # RLE on the Visit column
#' }
#'
#' @export
paginate <- function(x, ...) UseMethod("paginate")


# -- Default -- error with helpful message -----------------------------------

#' @rdname paginate
#' @export
paginate.default <- function(x, ...) {
  cls <- paste(class(x), collapse = "/")
  stop("paginate() has no method for class '", cls, "'. ",
       "Supported types: gt_tbl, data.frame / tibble, list of either.",
       call. = FALSE)
}


# -- gt method --------------------------------------------------------------

#' @rdname paginate
#' @export
paginate.gt_tbl <- function(x, ...) {
  if (!requireNamespace("gt", quietly = TRUE)) {
    stop("paginate() on a gt_tbl requires the `gt` package.  ",
         "Install it with `install.packages(\"gt\")`.",
         call. = FALSE)
  }
  # gt::extract_body() returns a tibble.  Keep it AS a tibble (do NOT
  # force as.data.frame): downstream the per-page chunks retain tibble
  # class, which matches the gt-native workflow.  paginate.data.frame()
  # dispatches on this just fine because tibble inherits from data.frame.
  body <- gt::extract_body(x, output = "rtf")
  # Non-breaking spaces from gt -> regular spaces, so indent-based
  # group detection works against the body cells.  (gt emits U+00A0
  # for padding / indenting by default.)  `[<-` preserves tibble class.
  body[] <- lapply(body, function(col) {
    if (is.character(col)) gsub("\u00a0", " ", col, fixed = TRUE) else col
  })
  paginate.data.frame(body, ...)
}


# -- list method -- recurse + concatenate -------------------------------------

#' @rdname paginate
#' @export
paginate.list <- function(x, ...) {
  if (length(x) == 0L) return(list())
  out <- list()
  for (i in seq_along(x)) {
    chunks <- paginate(x[[i]], ...)
    out <- c(out, chunks)
  }
  out
}


# -- data.frame method -- the core algorithm ----------------------------------

#' @rdname paginate
#' @export
paginate.data.frame <- function(x,
                                 max_rows    = NULL,
                                 split       = c("none", "rows",
                                                  "group_safe", "group_force"),
                                 split_rows  = NULL,
                                 group_col   = NULL,
                                 cont_label  = " (Cont.)",
                                 blank_rows       = NULL,
                                 blank_row_first  = FALSE,
                                 blank_row_end    = FALSE,
                                 ...) {
  split <- match.arg(split)

  if (split %in% c("group_safe", "group_force") && is.null(max_rows)) {
    stop("`max_rows` is required when split = \"", split, "\".",
         call. = FALSE)
  }
  if (split == "rows" && is.null(split_rows)) {
    stop("`split_rows` is required when split = \"rows\".", call. = FALSE)
  }

  group_idx <- .resolve_group_col(group_col, x)
  info      <- .compute_group_info(x, group_idx)

  # Preserve the input's class chain (so a tibble in → tibbles out).
  # We re-apply this to each chunk at the end because some internal
  # operations (rbind() with mixed inputs, row-index subsetting with
  # `[`) can intermittently strip non-data.frame classes.
  input_class <- class(x)

  # Step 1: split into raw chunks
  chunks <- switch(split,
    none         = list(x),
    rows         = .split_by_rows(x, split_rows),
    group_safe   = .split_group_safe (x, info, max_rows, cont_label, group_idx),
    group_force  = .split_group_force(x, info, max_rows, cont_label, group_idx)
  )

  # Step 2: attach blank-row positions + paginate meta to each chunk.
  # Order of position sources (all unioned, then sorted + deduped):
  #   * blank_rows = ... (integer / "between_groups" / list combination)
  #   * blank_row_first = TRUE → position 0  (blank BEFORE first data row)
  #   * blank_row_end   = TRUE → position nrow(chunk) (blank AFTER last)
  n_pages <- length(chunks)
  lapply(seq_along(chunks), function(i) {
    chunk <- chunks[[i]]
    # Restore the input's class chain so tibble-ness survives.
    class(chunk) <- input_class
    rownames(chunk) <- NULL
    pos <- .resolve_pagewise_blanks(blank_rows, chunk, group_idx)
    if (isTRUE(blank_row_first)) pos <- c(0L,             pos)
    if (isTRUE(blank_row_end))   pos <- c(pos, nrow(chunk))
    pos <- sort(unique(as.integer(pos)))
    pos <- pos[pos >= 0L & pos <= nrow(chunk)]
    if (length(pos) > 0L) attr(chunk, "rtf_blank_rows") <- pos
    attr(chunk, "rtf_paginate_meta") <- list(
      strategy    = split,
      page_index  = i,
      total_pages = n_pages,
      group_col   = group_col
    )
    chunk
  })
}


# -- Internal: group identification ------------------------------------------

# Resolve a user-supplied group_col (name, integer, or NULL) to an integer
# column index -- or NULL for "auto-detect from leading whitespace".
.resolve_group_col <- function(group_col, df) {
  if (is.null(group_col)) return(NULL)
  if (is.character(group_col)) {
    idx <- match(group_col, names(df))
    if (is.na(idx)) {
      stop(sprintf("`group_col` '%s' not found in the table.", group_col),
           call. = FALSE)
    }
    return(idx)
  }
  idx <- as.integer(group_col)
  if (is.na(idx) || idx < 1L || idx > ncol(df)) {
    stop(sprintf("`group_col` index %s out of range (1..%d).",
                 group_col, ncol(df)), call. = FALSE)
  }
  idx
}

# Compute per-row group id + label, used by all group-aware split modes.
# Returns list(id, label, headers) all length nrow(df).
#
# When group_idx is NULL: auto-detect from col 1.  A row whose first
# column starts with a non-space character is a group header; subsequent
# rows whose first column starts with whitespace are sub-rows of that
# group.  Rows before the first header have id = NA.
#
# When group_idx is supplied: each maximal run of consecutive identical
# values in df[[group_idx]] is one group; the first row of each run is
# the header.
.compute_group_info <- function(df, group_idx) {
  n <- nrow(df)
  if (n == 0L) {
    return(list(id = integer(0), label = character(0), headers = logical(0)))
  }

  if (is.null(group_idx)) {
    col1 <- as.character(df[[1L]])
    first_ch <- substr(col1, 1L, 1L)
    is_header <- !is.na(col1) & nzchar(col1) &
                   first_ch != " " & first_ch != "\t"
    raw_id <- cumsum(is_header)
    id <- ifelse(raw_id == 0L, NA_integer_, as.integer(raw_id))
    labels <- character(n)
    current <- ""
    for (i in seq_len(n)) {
      if (isTRUE(is_header[i])) current <- col1[i]
      labels[i] <- current
    }
    return(list(id = id, label = labels, headers = is_header))
  }

  col <- as.character(df[[group_idx]])
  rl  <- rle(col)
  id  <- as.integer(rep(seq_along(rl$lengths), rl$lengths))
  labels <- rep(rl$values, rl$lengths)
  headers <- c(TRUE, id[-1L] != id[-n])
  list(id = id, label = labels, headers = headers)
}


# -- Internal: split helpers -------------------------------------------------

.split_by_rows <- function(df, split_rows) {
  n <- nrow(df)
  if (n == 0L) return(list(df))
  positions <- sort(unique(as.integer(split_rows)))
  positions <- positions[positions >= 2L & positions <= n]
  if (length(positions) == 0L) return(list(df))
  starts <- c(1L, positions)
  ends   <- c(positions - 1L, n)
  lapply(seq_along(starts),
         function(i) df[starts[i]:ends[i], , drop = FALSE])
}

# Force-split at every `max_rows` rows; when the cut falls inside a group,
# insert a Cont. row at the top of the next chunk that repeats the group
# label without any of the summary-value cells.
.split_group_force <- function(df, info, max_rows, cont_label, group_idx) {
  if (nrow(df) == 0L) return(list(df))
  cont_col <- if (is.null(group_idx)) 1L else group_idx
  result <- list()
  pos <- 1L
  while (pos <= nrow(df)) {
    end <- min(pos + max_rows - 1L, nrow(df))
    result[[length(result) + 1L]] <- df[pos:end, , drop = FALSE]

    # Mid-group cut?  Inject a Cont. header row before end+1.
    if (end < nrow(df)) {
      end_gid  <- info$id[end]
      next_gid <- info$id[end + 1L]
      if (!is.na(end_gid) && !is.na(next_gid) && end_gid == next_gid) {
        label <- info$label[end]
        cont_row <- df[end + 1L, , drop = FALSE]
        # Zero-out every cell, then place the (Cont.) label in cont_col.
        for (j in seq_len(ncol(cont_row))) {
          cont_row[1L, j] <- if (is.character(df[[j]])) "" else NA
        }
        cont_row[1L, cont_col] <- paste0(label, cont_label)
        df <- rbind(df[1:end, , drop = FALSE], cont_row,
                     df[(end + 1L):nrow(df), , drop = FALSE])
        info$id      <- append(info$id,      end_gid, after = end)
        info$label   <- append(info$label,   label,   after = end)
        info$headers <- append(info$headers, TRUE,    after = end)
      }
    }
    pos <- end + 1L
  }
  result
}

# Pack whole groups onto each chunk; spill on overflow.  If a single
# group exceeds max_rows it is force-split via .split_group_force().
.split_group_safe <- function(df, info, max_rows, cont_label, group_idx) {
  if (nrow(df) == 0L) return(list(df))

  # NA group ids (rows before any header) become id = 0L so they form a
  # synthetic "preamble" group.
  gid <- ifelse(is.na(info$id), 0L, info$id)
  unique_gids <- unique(gid)
  result <- list()
  buf <- integer(0)

  for (g in unique_gids) {
    rows <- which(gid == g)
    g_n  <- length(rows)

    if (g_n > max_rows) {
      if (length(buf) > 0L) {
        result[[length(result) + 1L]] <- df[buf, , drop = FALSE]
        buf <- integer(0)
      }
      sub_info <- list(id      = info$id[rows],
                       label   = info$label[rows],
                       headers = info$headers[rows])
      result <- c(result,
                  .split_group_force(df[rows, , drop = FALSE],
                                     sub_info, max_rows, cont_label,
                                     group_idx))
    } else if (length(buf) + g_n > max_rows) {
      result[[length(result) + 1L]] <- df[buf, , drop = FALSE]
      buf <- rows
    } else {
      buf <- c(buf, rows)
    }
  }
  if (length(buf) > 0L) {
    result[[length(result) + 1L]] <- df[buf, , drop = FALSE]
  }
  result
}


# -- Internal: blank-row spec resolution per page ---------------------------

# Resolve the user's blank_rows spec into an integer vector of positions
# valid for ONE page (a chunk).  Accepts:
#   NULL                 -> integer(0)
#   integer / numeric    -> positions (passed through, clipped to chunk)
#   "between_groups"     -> auto-fill between detected group transitions
#   list                 -> union of any of the above
.resolve_pagewise_blanks <- function(spec, chunk, group_idx) {
  if (is.null(spec) || length(spec) == 0L) return(integer(0))

  one <- function(s) {
    if (is.numeric(s) && !is.list(s)) {
      return(as.integer(s))
    }
    if (is.character(s) && length(s) == 1L && s == "between_groups") {
      info <- .compute_group_info(chunk, group_idx)
      if (length(info$id) <= 1L) return(integer(0))
      # Find rows where id changes from previous row.  Skip the first row
      # (that is the start of the chunk, not a transition).
      changes <- which(c(FALSE, info$id[-1L] != info$id[-length(info$id)]))
      # blank position = row index BEFORE the change row, so a blank is
      # inserted after that row.
      return(as.integer(changes - 1L))
    }
    stop("Unrecognised `blank_rows` entry: ", paste(s, collapse = " "),
         call. = FALSE)
  }

  positions <- if (is.list(spec)) {
    unlist(lapply(spec, one))
  } else {
    one(spec)
  }
  positions <- positions[!is.na(positions)]
  positions <- positions[positions >= 0L & positions <= nrow(chunk)]
  sort(unique(as.integer(positions)))
}
