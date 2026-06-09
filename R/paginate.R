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

#' Split a table object into per-page data.frames (deprecated)
#'
#' @description
#' **Deprecated.**  Use [as_rtftables()] instead, which both paginates *and*
#' reads the source table's metadata (column labels, alignment, spanning
#' headers, per-cell styles, titles, footnotes) into ready-to-render
#' [rtftable()] page objects.  `paginate()` only ever extracted the rendered
#' body, so gt metadata was silently lost when paginating a `gt_tbl`.
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
#' @param x
#'   A supported table object: a `gt_tbl` (from [gt::gt()]), a plain
#'   `data.frame` / tibble, or a `list` of either.  List names are
#'   propagated to the output (one input -> one page keeps the input
#'   name; one input -> many pages produces `name.1`, `name.2`, ...).
#'
#' @param ...
#'   Pagination controls, forwarded to the internal splitter and shared
#'   with [as_rtftables()]: `max_rows`, `split`, `split_rows`,
#'   `group_col`, `cont_label`, `blank_rows`, `blank_row_first`,
#'   `blank_row_end`, `align_count_pct`.  See [as_rtftables()] for the
#'   full description of each.
#'
#' @return
#'   A list of data.frames (tibbles if the input was a tibble or
#'   `gt_tbl`), one element per page.  Each element carries:
#'
#'   * `attr(., "rtf_blank_rows")` -- integer positions consumed by
#'     [rtftable()] when `read_attributes = TRUE`.
#'   * `attr(., "rtf_paginate_meta")` -- list with `strategy`,
#'     `page_index`, `total_pages`, `group_col`, `page_name`.
#'
#'   When `split = "by_value"` -- or when the caller passed a *named*
#'   `list` and no splitting happened -- each element ALSO carries
#'   the group label as its `names()` entry.  Pass the resulting list
#'   directly to `rtf_tables(pages, auto_section = TRUE)` to get one
#'   RTF section per page name.
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
#'
#' # -------------------------------------------------------------------------
#' # 6. split = "by_value": one page per group value, named by the value
#' # -------------------------------------------------------------------------
#' df <- data.frame(
#'   visit = c("Week 1","Week 1","Week 2","Week 2","Week 4"),
#'   val   = c(10, 11, 20, 22, 30)
#' )
#' pages <- paginate(df, split = "by_value", group_col = "visit")
#' names(pages)                 # "Week 1", "Week 2", "Week 4"
#'
#' # Hand straight to rtf_tables(auto_section = TRUE) — one RTF section
#' # per visit, with the visit name as the section heading.
#' doc <- rtf_document() |>
#'   rtf_section(secinfo = list(header = my_hdr)) |>
#'   rtf_tables(pages, auto_section = TRUE)
#'
#' # -------------------------------------------------------------------------
#' # 7. Named list input: names round-trip through paginate()
#' # -------------------------------------------------------------------------
#' pages_in <- list(
#'   "Table 14.1.1" = tibble::tibble(x = 1:3),
#'   "Table 14.2.1" = tibble::tibble(x = 4:6)
#' )
#' pages <- paginate(pages_in)              # no split, names preserved
#' names(pages)                              # "Table 14.1.1" "Table 14.2.1"
#' }
#'
#' @export
paginate <- function(x, ...) {
  .warn_paginate_deprecated()
  UseMethod("paginate")
}

# Emit the paginate() deprecation warning at most once per session (so a
# script that paginates many tables -- and the test suite -- is not flooded).
.paginate_depr_env <- new.env(parent = emptyenv())
.warn_paginate_deprecated <- function() {
  if (isTRUE(.paginate_depr_env$warned)) return(invisible())
  .paginate_depr_env$warned <- TRUE
  .Deprecated("as_rtftables", package = "rtfreporter")
  invisible()
}


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
  paginate.data.frame(.extract_gt_body(x), ...)
}


# Extract a gt_tbl's rendered body as a plain tibble/data.frame with gt's
# non-breaking spaces normalised to regular spaces (so indent-based group
# detection works).  Shared by paginate.gt_tbl() and as_rtftables().
.extract_gt_body <- function(x) {
  if (!requireNamespace("gt", quietly = TRUE)) {
    stop("Reading a gt_tbl requires the `gt` package.  ",
         "Install it with `install.packages(\"gt\")`.",
         call. = FALSE)
  }
  body <- gt::extract_body(x, output = "rtf")
  body[] <- lapply(body, function(col) {
    if (is.character(col)) gsub("\u00a0", " ", col, fixed = TRUE) else col
  })
  body
}


# -- list method -- recurse + concatenate + propagate names -------------------

#' @rdname paginate
#' @export
paginate.list <- function(x, ...) {
  if (length(x) == 0L) return(list())
  in_names <- names(x)
  out <- list()
  for (i in seq_along(x)) {
    chunks <- paginate(x[[i]], ...)
    if (!is.null(in_names) && nzchar(in_names[i])) {
      base <- in_names[i]
      if (length(chunks) == 1L) {
        # No real split — input name carries through 1-to-1.
        names(chunks) <- base
      } else if (is.null(names(chunks)) ||
                  all(!nzchar(names(chunks) %||% ""))) {
        # Real split (group_force, group_safe, rows) — suffix .1 .2 ...
        names(chunks) <- paste0(base, ".", seq_along(chunks))
      } else {
        # Inner split already named chunks (e.g. by_value) — namespace
        # them under the input list name: "doc.group1", "doc.group2".
        names(chunks) <- paste0(base, ".", names(chunks))
      }
    }
    out <- c(out, chunks)
  }
  out
}


# -- data.frame method -- the core algorithm ----------------------------------

#' @rdname paginate
#' @export
paginate.data.frame <- function(x, ...) {
  .paginate_df(x, ...)
}


# Internal core: the data.frame pagination algorithm.  Non-deprecated entry
# point shared by paginate.data.frame() and as_rtftables().  Returns a list
# of per-page data.frames, each carrying `rtf_blank_rows` and
# `rtf_paginate_meta` attributes (and names() when the split is value-based).
.paginate_df <- function(x,
                                 max_rows    = NULL,
                                 split       = c("none", "rows",
                                                  "group_safe", "group_force",
                                                  "by_value"),
                                 split_rows  = NULL,
                                 group_col   = NULL,
                                 cont_label  = " (Cont.)",
                                 min_group_rows   = 2L,
                                 blank_rows       = NULL,
                                 blank_row_first  = FALSE,
                                 blank_row_end    = FALSE,
                                 align_count_pct  = FALSE,
                                 cell_format      = NULL,
                                 ...) {
  # `split` is either one of the built-in strategy names (character) or a
  # user-supplied custom function that cuts the body into per-page chunks.
  is_custom_split <- is.function(split)
  if (!is_custom_split) split <- match.arg(split)

  if (!is_custom_split) {
    if (split %in% c("group_safe", "group_force") && is.null(max_rows)) {
      stop("`max_rows` is required when split = \"", split, "\".",
           call. = FALSE)
    }
    if (split == "rows" && is.null(split_rows)) {
      stop("`split_rows` is required when split = \"rows\".", call. = FALSE)
    }
  }

  # Optional cell-format pass: rewrite the body cells column-by-column to a
  # uniform display width BEFORE splitting, so every chunk inherits the
  # cleaned-up cells.  `cell_format` (a function or list of functions) takes
  # precedence; `align_count_pct = TRUE` is the long-standing shorthand for
  # the built-in "n (xx.x)" realigner.
  if (!is.null(cell_format)) {
    fl <- .resolve_cell_format(cell_format, ncol(x))
    if (!is.null(fl)) x <- .apply_cell_format(x, fl)
  } else if (isTRUE(align_count_pct)) {
    x <- .realign_count_pct_df(x)
  }

  # Preserve the input's class chain (so a tibble in → tibbles out).
  # We re-apply this to each chunk at the end because some internal
  # operations (rbind() with mixed inputs, row-index subsetting with
  # `[`) can intermittently strip non-data.frame classes.
  input_class <- class(x)

  # Step 1: split into raw chunks.  A custom function implements only the
  # split; the shared post-processing below (blank rows, meta, and -- in
  # as_rtftables() -- per-page assembly + header/width/style replication) is
  # reused unchanged.  The function receives the (cell-formatted) body plus
  # context arguments and must return a non-empty list of data.frames; named
  # elements become page names (as with "by_value").
  if (is_custom_split) {
    chunks <- split(x, max_rows = max_rows, group_col = group_col,
                    cont_label = cont_label, min_group_rows = min_group_rows)
    if (!is.list(chunks) || length(chunks) == 0L ||
        !all(vapply(chunks, is.data.frame, logical(1L)))) {
      stop("A custom `split` function must return a non-empty list of ",
           "data.frames.", call. = FALSE)
    }
  } else {
    # The built-in string strategies are thin aliases for the exported
    # strategy factories, so both paths share exactly one implementation.
    strat_fn <- switch(split,
      none         = page_split_none(),
      rows         = page_split_rows(split_rows),
      group_safe   = page_split_group_safe (max_rows, group_col,
                                             min_group_rows, cont_label),
      group_force  = page_split_group_force(max_rows, group_col,
                                             min_group_rows, cont_label),
      by_value     = page_split_by_value   (group_col, max_rows,
                                             min_group_rows, cont_label)
    )
    chunks <- strat_fn(x)
  }
  strategy <- if (is_custom_split) "custom" else split

  # Step 2: attach blank-row positions (via the standalone helper
  # set_blank_rows()) + paginate meta on each chunk.
  n_pages     <- length(chunks)
  chunk_names <- names(chunks)        # may be NULL for non-named splits
  out <- lapply(seq_along(chunks), function(i) {
    chunk <- chunks[[i]]
    # Restore the input's class chain so tibble-ness survives.
    class(chunk) <- input_class
    rownames(chunk) <- NULL
    chunk <- set_blank_rows(chunk,
                             blank_rows      = blank_rows,
                             blank_row_first = blank_row_first,
                             blank_row_end   = blank_row_end,
                             group_col       = group_col)
    attr(chunk, "rtf_paginate_meta") <- list(
      strategy    = strategy,
      page_index  = i,
      total_pages = n_pages,
      group_col   = group_col,
      page_name   = if (!is.null(chunk_names)) chunk_names[i] else NULL
    )
    chunk
  })
  # Carry chunk names through `lapply` (which otherwise drops them).
  if (!is.null(chunk_names)) names(out) <- chunk_names
  out
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
    # A row is a group *header* when its first column starts with a
    # non-indent character.  Indentation may be encoded as a regular space,
    # a tab, or a non-breaking space (U+00A0) -- gt/tfrmt bakes row-label
    # indentation as leading NBSPs, so those must count as indent too,
    # otherwise every indented sub-row is mistaken for a new group.
    nbsp <- intToUtf8(160L)            # non-breaking space (U+00A0)
    indent_chars <- c(" ", "	", nbsp)
    is_header <- !is.na(col1) & nzchar(col1) &
                   !(first_ch %in% indent_chars)
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


#' Prepend a continuation label row to a paginated chunk
#'
#' A small helper for writing custom `split=` functions for [as_rtftables()].
#' When a group is split across pages, clinical tables repeat the group label
#' at the top of the continuation page with a `" (Cont.)"` suffix.
#' `add_cont_label()` builds that row: it prepends a blank row to `chunk` and
#' places `paste0(label, cont_label)` in column `col`, leaving every other cell
#' empty (`""` for character columns, `NA` otherwise).
#'
#' @param chunk A data.frame -- a single continuation page produced by your
#'   split function.
#' @param label Character scalar: the group label to repeat (without the
#'   continuation suffix).
#' @param cont_label Character scalar appended to `label`. Default
#'   `" (Cont.)"`, matching the built-in group strategies.
#' @param col Integer or character column where the label is placed. Default
#'   `1` (the row-label column).
#'
#' @return `chunk` with one extra row prepended.
#'
#' @seealso [as_rtftables()] for the `split=` custom-function contract.
#'
#' @examples
#' df <- data.frame(group = c("B", "B"), value = c("3", "4"))
#' add_cont_label(df, label = "Group B")
#'
#' @export
add_cont_label <- function(chunk, label, cont_label = " (Cont.)", col = 1L) {
  if (!is.data.frame(chunk)) {
    stop("`chunk` must be a data.frame.", call. = FALSE)
  }
  if (!is.character(label) || length(label) != 1L) {
    stop("`label` must be a single string.", call. = FALSE)
  }
  if (is.character(col)) {
    j <- match(col, names(chunk))
    if (is.na(j)) stop("`col` '", col, "' not found in `chunk`.", call. = FALSE)
  } else {
    j <- as.integer(col)
    if (is.na(j) || j < 1L || j > ncol(chunk)) {
      stop("`col` index ", col, " out of range (1..", ncol(chunk), ").",
           call. = FALSE)
    }
  }
  cont_row <- chunk[1L, , drop = FALSE]
  for (k in seq_len(ncol(cont_row))) {
    cont_row[1L, k] <- if (is.character(chunk[[k]])) "" else NA
  }
  cont_row[1L, j] <- paste0(label, cont_label)
  out <- rbind(cont_row, chunk)
  rownames(out) <- NULL
  out
}


# -- Pagination strategy factories -------------------------------------------

#' Built-in pagination strategies as reusable functions
#'
#' These factories return a *pagination function* suitable for the
#' `split=` argument of [as_rtftables()].  They expose the package's built-in
#' page-splitting strategies on the same footing as a hand-written custom
#' `split=` function, so you can pass a strategy directly, reuse it across
#' calls, or wrap one inside your own splitter.
#'
#' The string forms accepted by [as_rtftables()] are exact aliases:
#' `split = "group_safe"` is equivalent to
#' `split = page_split_group_safe()` with the call's `max_rows` / `group_col` /
#' `min_group_rows` / `cont_label`.
#'
#' Each returned function takes the (cell-formatted) body and returns a list of
#' data.frames -- one per page (named, for [page_split_by_value()]).  Arguments
#' set on the factory take precedence; anything left `NULL` falls back to the
#' value [as_rtftables()] passes at call time.
#'
#' @param split_rows Integer positions to cut at (for [page_split_rows()]).
#' @param max_rows Maximum data rows per page.  Required for
#'   [page_split_group_safe()] / [page_split_group_force()]; optional for
#'   [page_split_by_value()] (force-splits an over-long group when set).
#' @param group_col Group column: a name, a 1-based index, or `NULL` to
#'   auto-detect groups from leading whitespace in the first column.
#' @param min_group_rows Widow/orphan control (default `2`); see
#'   [as_rtftables()].
#' @param cont_label Continuation suffix for repeated group labels (default
#'   `" (Cont.)"`).
#'
#' @return A function `f(df, ...)` returning a list of per-page data.frames.
#'
#' @seealso [as_rtftables()] for the `split=` contract and [add_cont_label()].
#'
#' @examples
#' \dontrun{
#' as_rtftables(tbl, split = page_split_group_safe(max_rows = 20,
#'                                                  group_col = "visit"))
#' }
#'
#' @name page_split
NULL

#' @rdname page_split
#' @export
page_split_none <- function() {
  function(df, ...) list(df)
}

#' @rdname page_split
#' @export
page_split_rows <- function(split_rows = NULL) {
  cfg <- split_rows
  function(df, split_rows = NULL, ...) {
    sr <- cfg %||% split_rows
    if (is.null(sr)) {
      stop("`split_rows` is required for row-position pagination.",
           call. = FALSE)
    }
    .split_by_rows(df, sr)
  }
}

#' @rdname page_split
#' @export
page_split_group_safe <- function(max_rows = NULL, group_col = NULL,
                                  min_group_rows = 2L,
                                  cont_label = " (Cont.)") {
  cfg_mr  <- max_rows; cfg_gc <- group_col
  cfg_mgr <- min_group_rows; cfg_cl <- cont_label
  function(df, max_rows = NULL, group_col = NULL,
           cont_label = " (Cont.)", min_group_rows = 2L, ...) {
    mr  <- cfg_mr %||% max_rows
    gc  <- cfg_gc %||% group_col
    cl  <- cfg_cl %||% cont_label
    mgr <- if (!is.null(cfg_mgr)) cfg_mgr else min_group_rows
    if (is.null(mr)) {
      stop("`max_rows` is required for group_safe pagination.", call. = FALSE)
    }
    gidx <- .resolve_group_col(gc, df)
    info <- .compute_group_info(df, gidx)
    .split_group_safe(df, info, mr, cl, gidx, mgr)
  }
}

#' @rdname page_split
#' @export
page_split_group_force <- function(max_rows = NULL, group_col = NULL,
                                   min_group_rows = 2L,
                                   cont_label = " (Cont.)") {
  cfg_mr  <- max_rows; cfg_gc <- group_col
  cfg_mgr <- min_group_rows; cfg_cl <- cont_label
  function(df, max_rows = NULL, group_col = NULL,
           cont_label = " (Cont.)", min_group_rows = 2L, ...) {
    mr  <- cfg_mr %||% max_rows
    gc  <- cfg_gc %||% group_col
    cl  <- cfg_cl %||% cont_label
    mgr <- if (!is.null(cfg_mgr)) cfg_mgr else min_group_rows
    if (is.null(mr)) {
      stop("`max_rows` is required for group_force pagination.", call. = FALSE)
    }
    gidx <- .resolve_group_col(gc, df)
    info <- .compute_group_info(df, gidx)
    .split_group_force(df, info, mr, cl, gidx, mgr)
  }
}

#' @rdname page_split
#' @export
page_split_by_value <- function(group_col = NULL, max_rows = NULL,
                                min_group_rows = 2L,
                                cont_label = " (Cont.)") {
  cfg_gc  <- group_col; cfg_mr <- max_rows
  cfg_mgr <- min_group_rows; cfg_cl <- cont_label
  function(df, max_rows = NULL, group_col = NULL,
           cont_label = " (Cont.)", min_group_rows = 2L, ...) {
    gc  <- cfg_gc %||% group_col
    mr  <- cfg_mr %||% max_rows
    cl  <- cfg_cl %||% cont_label
    mgr <- if (!is.null(cfg_mgr)) cfg_mgr else min_group_rows
    gidx <- .resolve_group_col(gc, df)
    info <- .compute_group_info(df, gidx)
    .split_by_value(df, info, mr, cl, gidx, mgr)
  }
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
#
# `min_group_rows` (default 2) is widow/orphan control: if a page would end on
# a group that *starts* on that page while showing fewer than `min_group_rows`
# of the group's child rows, the whole group is pushed to the next page (the
# cut is moved to just before its header) -- this prevents a lone group header
# stranded at the foot of a page with none (or too few) of its members.  Set
# `min_group_rows = 0` to disable (the original behaviour).
.split_group_force <- function(df, info, max_rows, cont_label, group_idx,
                               min_group_rows = 2L) {
  if (nrow(df) == 0L) return(list(df))
  cont_col <- if (is.null(group_idx)) 1L else group_idx
  result <- list()
  pos <- 1L
  while (pos <= nrow(df)) {
    end <- min(pos + max_rows - 1L, nrow(df))

    # Widow/orphan control, only when the boundary group is actually being
    # split (it continues past `end`):
    #   * ORPHAN -- the group starts on this page and shows fewer than
    #     `min_group_rows` of its children -> move the whole group down.
    #   * WIDOW  -- the cut would leave fewer than `min_group_rows` rows of the
    #     group for the continuation page -> pull the cut back so the tail is
    #     at least `min_group_rows` (without leaving < `min_group_rows` here).
    if (min_group_rows > 0L && end < nrow(df)) {
      end_gid  <- info$id[end]
      next_gid <- info$id[end + 1L]
      cut_here <- !is.na(end_gid) && !is.na(next_gid) && end_gid == next_gid
      if (cut_here) {
        hpos <- end
        while (hpos > pos && !isTRUE(info$headers[hpos])) hpos <- hpos - 1L
        starts_here <- hpos > pos && isTRUE(info$headers[hpos]) &&
                       !is.na(info$id[hpos]) && info$id[hpos] == end_gid
        child_rows  <- end - hpos          # rows after the header on this page
        if (starts_here && child_rows < min_group_rows) {
          end <- hpos - 1L                 # ORPHAN: push the group to next page
        } else {
          # WIDOW: count the same-group rows that would spill past `end`.
          tail_n <- 0L; k <- end + 1L
          while (k <= nrow(df) && !is.na(info$id[k]) &&
                 info$id[k] == end_gid) { tail_n <- tail_n + 1L; k <- k + 1L }
          if (tail_n > 0L && tail_n < min_group_rows) {
            new_end <- end - (min_group_rows - tail_n)
            # First row of this group on the current page (a (Cont.) header
            # shares the group id, so this stops at `pos` for a continuation).
            gstart <- end
            while (gstart > pos && !is.na(info$id[gstart - 1L]) &&
                   info$id[gstart - 1L] == end_gid) gstart <- gstart - 1L
            if (new_end > pos && (new_end - gstart + 1L) >= min_group_rows) {
              end <- new_end
            }
          }
        }
      }
    }

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

# One chunk per detected group, NEVER packed.  Each chunk is named by
# the group's label (col-1 indent text when group_col = NULL, else the
# value of df[[group_col]]).  When a group exceeds `max_rows` (and
# max_rows is set) it is force-split with .split_group_force() and the
# resulting sub-chunks get suffixed names "<label>.1", "<label>.2", ...
.split_by_value <- function(df, info, max_rows, cont_label, group_idx,
                            min_group_rows = 2L) {
  if (nrow(df) == 0L) return(list(df))
  gid <- ifelse(is.na(info$id), 0L, info$id)
  unique_gids <- unique(gid)

  result <- list()
  for (g in unique_gids) {
    rows  <- which(gid == g)
    g_n   <- length(rows)
    chunk <- df[rows, , drop = FALSE]
    label <- info$label[rows][1L]
    if (!nzchar(label)) label <- paste0("group_", g)

    if (!is.null(max_rows) && g_n > max_rows) {
      sub_info <- list(id      = info$id[rows],
                       label   = info$label[rows],
                       headers = info$headers[rows])
      sub <- .split_group_force(chunk, sub_info, max_rows,
                                 cont_label, group_idx, min_group_rows)
      sub_names <- if (length(sub) == 1L) label
                   else paste0(label, ".", seq_along(sub))
      names(sub) <- sub_names
      result <- c(result, sub)
    } else {
      one <- list(chunk)
      names(one) <- label
      result <- c(result, one)
    }
  }
  result
}

# Pack whole groups onto each chunk; spill on overflow.  If a single
# group exceeds max_rows it is force-split via .split_group_force().
.split_group_safe <- function(df, info, max_rows, cont_label, group_idx,
                              min_group_rows = 2L) {
  if (nrow(df) == 0L) return(list(df))

  # NA group ids (rows before any header) become id = 0L so they form a
  # synthetic "preamble" group.
  gid <- ifelse(is.na(info$id), 0L, info$id)
  unique_gids <- unique(gid)

  # The page buffer is a data.frame (not row indices) so the tail of a
  # force-split group -- which contains a synthetic "(Cont.)" row not present
  # in `df` -- can stay in the buffer and have following whole groups packed
  # onto it, instead of being stranded on a near-empty page of its own.
  result <- list()
  buf     <- NULL
  flush <- function() {
    if (!is.null(buf)) { result[[length(result) + 1L]] <<- buf; buf <<- NULL }
  }

  for (g in unique_gids) {
    rows <- which(gid == g)
    g_n  <- length(rows)
    gdf  <- df[rows, , drop = FALSE]

    if (g_n > max_rows) {
      flush()
      sub_info <- list(id      = info$id[rows],
                       label   = info$label[rows],
                       headers = info$headers[rows])
      sub <- .split_group_force(gdf, sub_info, max_rows, cont_label,
                                group_idx, min_group_rows)
      # All but the last sub-chunk are full pages; keep the last (the tail)
      # in the buffer so the next group(s) can pack onto it.
      if (length(sub) > 1L) result <- c(result, sub[-length(sub)])
      buf <- sub[[length(sub)]]
    } else if (!is.null(buf) && (nrow(buf) + g_n) > max_rows) {
      flush()
      buf <- gdf
    } else {
      buf <- if (is.null(buf)) gdf else rbind(buf, gdf)
    }
  }
  flush()
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
