# Internal: writable width (twips) of rtfreporter's default page -- landscape
# Letter (11in) with the default 0.6in left/right margins.  Used as the cap for
# `auto_width` so an over-wide table is scaled to fit the page by default.
.default_writable_twips <- function() as.integer((11 - 2 * 0.6) * 1440)

# Internal: flatten a (possibly multi-row, possibly spanning) col_header into a
# plain character vector of length `ncols`, where each element is the LONGEST
# label seen at that column across every header row.  Used by `auto_width` so
# that column sizing accounts for the column headers, not just the data.
#
# Accepts the same shapes the rtftable col_header may take:
#   * a character vector            -> a single header row
#   * a list of header rows, each of which is either a character vector or a
#     list of cells with `$label` and a position (`$pos`, or `$from`/`$to`).
# Spanning cells (from != to) are ignored for width purposes (they do not force
# any single column to be wide).
.flatten_col_header_labels <- function(col_header, ncols) {
  if (is.null(col_header) || ncols < 1L) return(NULL)
  rows <- if (is.character(col_header)) list(col_header) else col_header
  best <- rep("", ncols)
  bump <- function(j, lab) {
    if (!is.null(j) && !is.na(j) && j >= 1L && j <= ncols &&
        nchar(lab) > nchar(best[j])) best[j] <<- lab
  }
  for (row in rows) {
    if (is.character(row)) {
      for (j in seq_len(min(length(row), ncols))) bump(j, row[j] %||% "")
    } else if (is.list(row)) {
      for (cell in row) {
        if (!is.list(cell)) next
        lab <- as.character(cell$label %||% "")
        pos <- cell$pos
        if (is.null(pos)) {
          f <- cell$from; t <- cell$to
          if (!is.null(f) && !is.null(t) && length(f) && length(t) && f == t)
            pos <- f
        }
        bump(pos, lab)
      }
    }
  }
  best
}

#' Convert a table object into rtfreporter table pages
#'
#' `as_rtftables()` is the single entry point for turning a *table object*
#' into a list of [rtftable()] objects -- one per RTF page -- ready to hand
#' straight to [rtf_tables()].  It unifies two jobs that used to be split
#' across `paginate()` (page splitting) and `rtf_tables(read_gt = )`
#' (metadata extraction):
#'
#' 1. **Read the table's metadata** (only the parts the RTF renderer can use;
#'    see *What is carried* below).
#' 2. **Paginate.**  The rendered body is split into per-page chunks using
#'    the same strategies the old `paginate()` offered (`split`, `max_rows`,
#'    `group_col`, blank-row controls, ...).  The shared header / width /
#'    spanning metadata is replicated onto every page.
#'
#' The page-level title / source-note blocks travel with each returned
#' rtftable as the attributes `rtf_titles` / `rtf_footnotes`, which
#' [rtf_tables()] consumes automatically.
#'
#' Supported inputs: `gt_tbl`, gtsummary tables, rtables/tern `VTableTree`
#' tables, `flextable` tables, `huxtable` tables, plain `data.frame` / tibble,
#' or a `list` of any of these (the list is flattened, names propagated as
#' `name`, `name.1`, `name.2`, ...).  Figures are out of scope -- use
#' [rtf_figures()] for those.
#'
#' @section What is carried, by source:
#'
#' The body is always the table's *rendered* body -- for gt/gtsummary via
#' `gt::extract_body()`, for rtables/tern via `formatters::matrix_form()`.
#' Only visible columns appear (hidden / helper columns such as tfrmt's
#' `..tfrmt_row_grp_lbl` are dropped), row-group / stub rows are already
#' interleaved, and indentation is rendered into the label text.  On top of
#' that body the following *metadata* is read:
#'
#' \tabular{lllll}{
#'   **Metadata** \tab **gt / gtsummary** \tab **rtables / tern** \tab **flextable** \tab **huxtable** \cr
#'   Column (leaf) labels        \tab yes \tab yes \tab yes \tab yes \cr
#'   Per-column alignment        \tab yes \tab yes \tab yes \tab yes \cr
#'   Spanning headers            \tab yes \tab yes \tab yes \tab yes \cr
#'   Column widths               \tab yes (px/pct) \tab -- \tab -- \tab -- \cr
#'   Title + subtitle            \tab yes \tab yes \tab yes (caption) \tab yes (caption) \cr
#'   Footnotes / source notes    \tab yes \tab yes \tab yes (footer) \tab -- \cr
#'   In-cell footnote marks      \tab yes (superscript) \tab yes (superscript) \tab -- \tab -- \cr
#'   Row-group rows + indent     \tab yes (rendered) \tab yes (rendered) \tab yes (rendered) \tab yes (rendered) \cr
#' }
#'
#' For flextable the *displayed* text is read (header labels set via
#' `set_header_labels()` and `colformat_*()` formatting included), not the raw
#' `$body$dataset`.  Cells composed of images / equations and `footnote()`
#' reference marks are not carried.  For huxtable the displayed text is likewise
#' read (its `number_format` applied); huxtable has no footnote concept, so only
#' the caption (a page title) is carried.
#'
#' **Not carried** (RTF cannot reproduce these, so they are intentionally
#' ignored): per-cell bold / italic / underline from `gt::tab_style()`, cell
#' background colours / fills, font and size styling, and Markdown formatting
#' inside labels or titles.  Plain `data.frame` / tibble inputs carry no
#' metadata at all -- set `col_header`, `col_spec`, etc. yourself.
#'
#' @param x A `gt_tbl`, a gtsummary table, an rtables/tern `VTableTree`, a
#'   `flextable`, a `huxtable`, a `data.frame` / tibble, or a `list` of these.
#' @param read_meta Controls metadata extraction from the source table:
#'   `TRUE` (default, read everything in the table above), `FALSE` (use only
#'   the rendered body -- equivalent to the old `paginate()`), or a character
#'   vector of tokens.  Ignored for plain data.frame inputs.  Tokens for
#'   gt/gtsummary: `"col_header"`, `"alignment"`, `"spanning"`, `"widths"`,
#'   `"titles"`, `"footnotes"`.  For rtables/tern: `"col_header"`,
#'   `"alignment"`, `"spanning"`, `"titles"`, `"footnotes"`, `"indent"`,
#'   `"footnote_marks"`.  For flextable: `"col_header"`, `"alignment"`,
#'   `"spanning"`, `"titles"`, `"footnotes"`.  For huxtable: `"col_header"`,
#'   `"alignment"`, `"spanning"`, `"titles"`.
#' @param split How to break the body into pages. A strategy name:
#'   \describe{
#'     \item{`"none"`}{(default) one page; no row limit checked.}
#'     \item{`"rows"`}{fixed chunk size; requires `split_rows`.}
#'     \item{`"group_safe"`}{fill up to `max_rows` but never split a group
#'       (defined by `group_col`) across a page; requires `max_rows`.}
#'     \item{`"group_force"`}{like `"group_safe"`, but a single group larger than
#'       `max_rows` may span pages with a continuation label; requires `max_rows`.}
#'     \item{`"by_value"`}{one page per distinct value of `group_col`; the pages
#'       are named by that value.}
#'   }
#'   `split` may also be a **custom function** for bespoke page-break rules.
#'   It is called as
#'   `split(df, max_rows = , group_col = , group_by = , cont_label = , min_group_rows = )`
#'   on the (cell-formatted) body and must return a **non-empty list of
#'   data.frames** -- one per page.  Named list elements become page names (as
#'   with `"by_value"`).  Your function implements only the split; the shared
#'   pipeline (blank rows, metadata, per-page assembly, and header / width /
#'   style replication) is applied to its output unchanged.  Write the function
#'   with a `...` so it tolerates the context arguments it does not use, and see
#'   [add_cont_label()] for re-creating the `" (Cont.)"` continuation row.
#' @param max_rows Integer or `NULL`.  Maximum body rows per page for the
#'   `"group_safe"` / `"group_force"` splits (required by them).  Ignored by
#'   `"none"`, `"rows"` (which uses `split_rows`) and `"by_value"`.
#' @param split_rows Integer or `NULL`.  Rows per page for `split = "rows"`
#'   (required by it; ignored otherwise).
#' @param group_col Character, integer, or `NULL`.  The column the group-aware
#'   splits (`"group_safe"`, `"group_force"`, `"by_value"`) detect groups on,
#'   given by name or position.  `NULL` (default) uses **column 1**.  This
#'   selects only the *column*; how a group boundary is found on it is set by
#'   `group_by`.  Note that for gt / gtsummary the body keeps gt's column
#'   **ids** (e.g. `"label"`, `"stat_1"`), and for rtables / flextable /
#'   huxtable the columns are renamed `V1`, `V2`, ... -- so an **integer** index
#'   is the most portable.
#' @param group_by How a group boundary is found on `group_col`:
#'   \describe{
#'     \item{`"auto"`}{(default) pick from the column content: leading
#'       indentation present -> `"indent"`; else interspersed empty cells ->
#'       `"filled"`; else -> `"value"`.}
#'     \item{`"indent"`}{a row starts a group when its `group_col` cell is
#'       non-empty and does **not** begin with whitespace (space / tab /
#'       non-breaking space); indented or empty cells are members. The typical
#'       clinical row-label layout (gt / tfrmt bake indentation as NBSP).}
#'     \item{`"value"`}{each maximal run of rows sharing the same `group_col`
#'       value is one group.}
#'     \item{`"filled"`}{a row starts a group when its `group_col` cell is
#'       non-empty; only `NA` / `""` cells are members (the label appears once,
#'       on the group's first row).}
#'   }
#' @param cont_label Character (default `" (Cont.)"`).  Suffix appended to a
#'   group's label on the second and later pages it continues onto (the
#'   group-aware splits), marking a continued group.
#' @param blank_rows Where to insert blank separator rows in the body.  `NULL`
#'   (default) inserts none (but an `rtf_blank_rows` attribute already on the
#'   input is still honoured).  Accepts any of -- or a `list()` combining:
#'   \describe{
#'     \item{an integer vector of positions}{a blank row is inserted *after* each
#'       given data-row index; `0` = before the first row, `-1` = after the last
#'       row (e.g. `c(0, 5, -1)`).}
#'     \item{a [blank_rows_by_change()] object}{insert a blank whenever the value
#'       of one or more columns changes.}
#'     \item{a [blank_rows_by_rule()] object}{insert a blank before / after rows
#'       whose column matches a regular expression.}
#'   }
#'   For example
#'   `blank_rows = list(c(-1), blank_rows_by_change("Visit"))` adds a trailing
#'   blank and a blank at every change of `Visit`.  By default these blanks are
#'   added *after* the split and do not count toward `max_rows`; see
#'   `count_blank_rows` to count them.
#' @param blank_row_first,blank_row_end Logical (default `FALSE`).  Add a single
#'   blank row at the very top (`blank_row_first`) or bottom (`blank_row_end`)
#'   of **every** page, as page furniture.  These are applied after the split
#'   and are never counted toward `max_rows`.
#' @param align_count_pct Logical (default `FALSE`).  Shorthand to realign
#'   `"n (xx.x)"` count/percent cells to a uniform width before pagination (the
#'   built-in [realign_count_pct()]).  Ignored when `cell_format` is supplied,
#'   which takes precedence.
#' @param min_group_rows Integer (default `2`).  Widow/orphan control for the
#'   group-aware splits (`"group_force"`, `"group_safe"`, `"by_value"`): when a
#'   page would end on a group that *starts* on that page while showing fewer
#'   than `min_group_rows` of the group's child rows, the whole group is moved
#'   to the next page.  This prevents a lone group header being stranded at the
#'   foot of a page with none (or too few) of its members.  Set to `0` to
#'   disable (the previous behaviour).
#' @param count_blank_rows Logical (default `FALSE`).  When `TRUE`, blank
#'   separator rows are **counted toward `max_rows`** during pagination, so a
#'   page (data rows + blanks) does not overflow the budget.  The blank
#'   positions resolved from `blank_rows` (and from any `rtf_blank_rows`
#'   attribute already on the input) are materialised before the split and
#'   re-attached per page afterwards, with a leading blank suppressed at the top
#'   of each page.  `blank_row_first` / `blank_row_end` remain page furniture
#'   added after the split and are **not** counted (so they may still exceed
#'   `max_rows`).  When `FALSE` (default) blank rows are added after the split
#'   and do not affect the row count.
#' @param cell_format Optional cell re-formatter applied column-by-column to
#'   the body **before** pagination, for monospaced alignment.  Either a single
#'   function -- applied to every data column (columns 2..N; the row-label
#'   column 1 is left alone) -- or a list of functions taken positionally
#'   (`cell_format[[j]]` for column `j`; non-function entries are skipped).
#'   Each function takes one column (a character vector) and returns a
#'   character vector of the same length; see [fmt_count_paren()] /
#'   [fmt_right_align()] for built-ins and the contract for writing your own.
#'   When supplied it takes precedence over `align_count_pct`.
#' @param collapse_repeats Columns in which to blank **consecutive repeated
#'   values** (repeat suppression), or `NULL` (default, off).  A character /
#'   integer vector naming the columns in priority order.  Within each column,
#'   only the first value of a run is kept; the rest of the run is replaced with
#'   `NA` (which renders as an empty cell -- no row is removed, only the display
#'   text is suppressed).  When several columns are given the suppression is
#'   **hierarchical**: the first column is collapsed on its own value, and each
#'   later column on the *combination* of itself with all earlier listed columns
#'   (a change in any higher column restarts the lower column's run).  This runs
#'   **per page, after the split**, so the pagination still sees the original
#'   repeated values -- group boundaries and `(Cont.)` labels stay correct, and a
#'   group continued onto the next page shows its label again at the top.  (In
#'   `group_by` terms: value-based grouping happens first, then the column is
#'   collapsed to a `"filled"`-style display.)
#' @param drop_cols Columns to **hide from the printed table while still using
#'   them for pagination / grouping**, or `NULL` (default, drop nothing).  A
#'   character / integer vector (or a `list()` to mix names and indices) naming
#'   the columns in the **input body's** coordinates -- the same coordinate
#'   space as `group_col` and `collapse_repeats`.  The named columns stay
#'   present through the split (so
#'   `group_col`, `collapse_repeats` and [blank_rows_by_change()] can reference
#'   them), then are removed from **every page** before that page's table is
#'   rendered.  This makes a column usable as a hidden grouping / sort-key /
#'   carrier column without it appearing in the report.  Position-indexed
#'   metadata (`col_header` incl. spanning headers, `col_spec`, column widths,
#'   `col_header_align`, `row_title`, and per-cell `cell_styles`) is reindexed
#'   automatically to the remaining columns.  `drop_cols` must leave at least
#'   one column to display.  Note that for `split = "by_value"` the page
#'   **names** come from the `group_col` value, so that column may be dropped and
#'   the pages are still named by it; but under `"group_safe"` / `"group_force"`
#'   the `" (Cont.)"` marker is written into the `group_col` cell, so if
#'   `group_col` is itself dropped the marker is not shown (group on the visible
#'   label column if the marker is wanted).
#' @param auto_width Logical (default `FALSE`).  When `TRUE`, each column is
#'   sized to its widest content (column header label or data cell) via
#'   [auto_col_widths()], so long row labels and column headers do not wrap.
#'   The widths are computed once on the full table and applied to every page,
#'   keeping paginated pages aligned.  Ignored if you pass an explicit
#'   `column_widths_twips` or `col_rel_width`.
#' @param table_width_twips Optional total table width in twips, used only when
#'   `auto_width = TRUE`.  When supplied, the auto-sized columns are scaled so
#'   their widths sum to this value (e.g. to fill, or fit within, the writable
#'   page width).  `NULL` (default) uses each column's natural content width,
#'   but **capped at the default page's writable width** (landscape Letter,
#'   0.6in margins) so a naturally over-wide table is scaled down to fit the
#'   page without you having to compute the width.
#' @param border,style Passed to [rtftable()] for every page.  `border`
#'   defaults to `"tfl"`.
#' @param ... Further arguments forwarded to [rtftable()] for every page
#'   (e.g. `col_header`, `col_spec`, `row_title`, `col_rel_width`,
#'   `row_height_twips`).  `row_title` names the row-heading columns (default:
#'   column 1) and sets the per-column default alignment (heading columns left,
#'   others centre).  Explicit values always win over the gt-extracted ones.
#'
#' @return A list of `rtftable` objects, one per page.  When the split is
#'   value-based (or the input was a named list) the list is named.
#'
#' @seealso [as_rtftable()] for the single-page convenience wrapper,
#'   [rtf_tables()] to append the result to a document.
#'
#' @examples
#' # A plain data.frame: one page, no splitting.
#' df <- data.frame(
#'   Parameter = c("Age", "  Mean", "  SD", "Sex", "  F", "  M"),
#'   Value     = c("", "75.1", "8.2", "", "53%", "47%"),
#'   stringsAsFactors = FALSE
#' )
#' pages <- as_rtftables(df)               # length-1 list of rtftable
#' length(pages)
#'
#' # Fixed-size pagination: 3 body rows per page.
#' pages <- as_rtftables(df, split = "rows", split_rows = 3)
#' length(pages)                           # 2 pages
#'
#' # Blank separator rows: after row 3 and after the last row.
#' pages <- as_rtftables(df, blank_rows = c(3, -1))
#' pages[[1]]$blank_rows
#'
#' \dontrun{
#' library(gtsummary)
#' tbl <- trial |>
#'   tbl_summary(by = trt) |>
#'   as_rtftables()                       # list of rtftable pages
#'
#' doc <- rtf_document() |>
#'   rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
#'   rtf_tables(tbl)                       # titles / footnotes flow through
#' generate_rtfreport(doc, "out.rtf", overwrite = TRUE)
#' }
#'
#' @export
as_rtftables <- function(x,
                         read_meta       = TRUE,
                         max_rows        = NULL,
                         split           = c("none", "rows", "group_safe",
                                             "group_force", "by_value"),
                         split_rows      = NULL,
                         group_col       = NULL,
                         group_by        = c("auto", "indent", "value",
                                             "filled"),
                         cont_label      = " (Cont.)",
                         min_group_rows  = 2L,
                         blank_rows      = NULL,
                         blank_row_first = FALSE,
                         blank_row_end   = FALSE,
                         count_blank_rows = FALSE,
                         align_count_pct = FALSE,
                         cell_format     = NULL,
                         collapse_repeats = NULL,
                         drop_cols       = NULL,
                         auto_width        = FALSE,
                         table_width_twips = NULL,
                         border          = "tfl",
                         style           = NULL,
                         ...) {
  # `split` is a built-in strategy name OR a custom pagination function.
  if (!is.function(split)) split <- match.arg(split)
  group_by <- match.arg(group_by)
  user_args <- list(...)

  # ---- list input: recurse, concatenate, propagate names ----------------
  if (is.list(x) && !is.data.frame(x) && !isS4(x) &&
      !.is_gt_tbl(x) && !.is_gtsummary_tbl(x) && !.is_rtables_tbl(x) &&
      !.is_flextable_tbl(x)) {
    if (length(x) == 0L) return(list())
    in_names <- names(x)
    out <- list()
    for (i in seq_along(x)) {
      chunks <- as_rtftables(
        x[[i]], read_meta = read_meta, max_rows = max_rows, split = split,
        split_rows = split_rows, group_col = group_col, group_by = group_by,
        cont_label = cont_label, min_group_rows = min_group_rows,
        blank_rows = blank_rows, blank_row_first = blank_row_first,
        blank_row_end = blank_row_end, count_blank_rows = count_blank_rows,
        align_count_pct = align_count_pct,
        cell_format = cell_format, collapse_repeats = collapse_repeats,
        drop_cols = drop_cols,
        auto_width = auto_width, table_width_twips = table_width_twips,
        border = border, style = style, ...)
      if (!is.null(in_names) && nzchar(in_names[i])) {
        base <- in_names[i]
        if (length(chunks) == 1L) {
          names(chunks) <- base
        } else if (is.null(names(chunks)) ||
                   all(!nzchar(names(chunks) %||% ""))) {
          names(chunks) <- paste0(base, ".", seq_along(chunks))
        } else {
          names(chunks) <- paste0(base, ".", names(chunks))
        }
      }
      out <- c(out, chunks)
    }
    return(out)
  }

  # ---- gtsummary -> gt --------------------------------------------------
  if (.is_gtsummary_tbl(x)) x <- .gtsummary_to_gt(x)

  # ---- resolve body + metadata ------------------------------------------
  if (.is_gt_tbl(x)) {
    tokens          <- .resolve_gt_tokens(read_meta)
    kw              <- .gt_to_rtftable_kwargs(x, tokens = tokens)
    body            <- kw$data
    cell_styles     <- kw$cell_styles
    titles_block    <- kw$titles_block
    footnotes_block <- kw$footnotes_block
  } else if (.is_rtables_tbl(x)) {
    tokens          <- .resolve_rtables_tokens(read_meta)
    kw              <- .rtables_to_rtftable_kwargs(x, tokens = tokens)
    body            <- kw$data
    cell_styles     <- kw$cell_styles
    titles_block    <- kw$titles_block
    footnotes_block <- kw$footnotes_block
  } else if (.is_flextable_tbl(x)) {
    tokens          <- .resolve_flextable_tokens(read_meta)
    kw              <- .flextable_to_rtftable_kwargs(x, tokens = tokens)
    body            <- kw$data
    cell_styles     <- kw$cell_styles
    titles_block    <- kw$titles_block
    footnotes_block <- kw$footnotes_block
  } else if (.is_huxtable_tbl(x)) {
    # NB: a huxtable IS a data.frame subclass, so this branch MUST come before
    # the plain-data.frame branch below.
    tokens          <- .resolve_huxtable_tokens(read_meta)
    kw              <- .huxtable_to_rtftable_kwargs(x, tokens = tokens)
    body            <- kw$data
    cell_styles     <- kw$cell_styles
    titles_block    <- kw$titles_block
    footnotes_block <- kw$footnotes_block
  } else if (is.data.frame(x)) {
    body            <- x
    kw              <- list()
    cell_styles     <- NULL
    titles_block    <- NULL
    footnotes_block <- NULL
  } else {
    stop("`as_rtftables()` supports gt_tbl, gtsummary, rtables/tern, ",
         "flextable, huxtable, data.frame/tibble, or a list of these; got '",
         paste(class(x), collapse = "/"), "'.", call. = FALSE)
  }

  # ---- resolve hidden (drop) columns ------------------------------------
  # Columns to remove from the printed pages AFTER pagination (so they can be
  # used by group_col / collapse_repeats / blank_rows_by_change first, then
  # hidden).  Resolved here, on the input body's coordinates, before the sidx
  # helper column is appended below.
  drop_idx <- .resolve_drop_cols(drop_cols, body)

  # ---- auto column widths -----------------------------------------------
  # When requested, size each column to its widest content (header label or
  # data cell) so that long row labels and column headers do not wrap.  The
  # widths are computed once on the full body and applied to every page, so
  # paginated pages stay aligned.  An explicit `column_widths_twips` /
  # `col_rel_width` from the user always wins.
  if (isTRUE(auto_width) &&
      is.null(user_args$column_widths_twips) &&
      is.null(user_args$col_rel_width)) {
    flat_hdr <- .flatten_col_header_labels(kw$col_header, ncol(body))
    tw <- table_width_twips
    # With no explicit width, use the natural content widths but cap them at
    # the default page's writable width -- so a table that is naturally too
    # wide (e.g. a tfrmt demographics table) is scaled down to fit the page,
    # while narrower tables keep their natural widths.
    if (is.null(tw)) {
      nat <- tryCatch(auto_col_widths(body, col_header = flat_hdr),
                      error = function(e) NULL)
      if (!is.null(nat) && sum(nat) > .default_writable_twips()) {
        tw <- .default_writable_twips()
      }
    }
    aw <- tryCatch(
      auto_col_widths(body, col_header = flat_hdr,
                      table_width_twips = tw, protect_cols = 1L),
      error = function(e) NULL)
    if (!is.null(aw)) user_args$column_widths_twips <- aw
  }

  # ---- paginate (tracking original rows so per-cell styles can be sliced)
  have_styles <- !is.null(cell_styles)
  sidx_col    <- ".__rtf_sidx__"
  if (have_styles) body[[sidx_col]] <- seq_len(nrow(body))

  pages <- .paginate_df(
    body, max_rows = max_rows, split = split, split_rows = split_rows,
    group_col = group_col, group_by = group_by, cont_label = cont_label,
    min_group_rows = min_group_rows, blank_rows = blank_rows,
    blank_row_first = blank_row_first, blank_row_end = blank_row_end,
    count_blank_rows = count_blank_rows,
    align_count_pct = align_count_pct, cell_format = cell_format,
    collapse_repeats = collapse_repeats)
  page_names <- names(pages)

  out <- lapply(seq_along(pages), function(i) {
    pg         <- pages[[i]]
    blank_attr <- attr(pg, "rtf_blank_rows", exact = TRUE)

    cs_slice <- NULL
    if (have_styles) {
      oidx <- pg[[sidx_col]]
      pg[[sidx_col]] <- NULL
      cs_slice <- lapply(oidx, function(r) {
        if (is.na(r)) NULL else cell_styles[[as.integer(r)]]
      })
      if (all(vapply(cs_slice, is.null, logical(1L)))) cs_slice <- NULL
    }

    rt <- .assemble_page_rtftable(pg, kw, cs_slice, user_args,
                                   border, style, blank_attr, drop_idx)
    if (!is.null(titles_block))    attr(rt, "rtf_titles")    <- titles_block
    if (!is.null(footnotes_block)) attr(rt, "rtf_footnotes") <- footnotes_block
    rt
  })
  if (!is.null(page_names)) names(out) <- page_names
  out
}


# Build one page's rtftable from (page data.frame, gt kwargs, sliced
# cell_styles, user overrides).  Shared by as_rtftables() and as_rtftable().
# User-supplied `...` values always beat the gt-extracted ones.
.assemble_page_rtftable <- function(data, kw, cell_styles, user_args,
                                     border, style, blank_attr,
                                     drop_idx = integer(0)) {
  call_args <- list(data = data, border = border, style = style,
                    read_attributes = TRUE)

  # col_header: user > gt
  if (!is.null(user_args$col_header)) {
    call_args$col_header <- user_args$col_header
  } else if (!is.null(kw$col_header)) {
    call_args$col_header <- kw$col_header
  }

  # col_spec: deep merge (user fields win per column)
  if (!is.null(kw$col_spec) || !is.null(user_args$col_spec)) {
    call_args$col_spec <- .merge_col_spec(user_args$col_spec, kw$col_spec)
  }

  # widths: user > gt
  for (k in c("column_widths_twips", "col_rel_width")) {
    if (!is.null(user_args[[k]])) {
      call_args[[k]] <- user_args[[k]]
    } else if (!is.null(kw[[k]])) {
      call_args[[k]] <- kw[[k]]
    }
  }

  # cell_styles: user > sliced-gt
  if (!is.null(user_args$cell_styles)) {
    call_args$cell_styles <- user_args$cell_styles
  } else if (!is.null(cell_styles)) {
    call_args$cell_styles <- cell_styles
  }

  # remaining user args pass through verbatim
  consumed <- c("data", "col_header", "col_spec", "column_widths_twips",
                "col_rel_width", "cell_styles", "border", "style")
  for (k in setdiff(names(user_args), consumed)) {
    call_args[[k]] <- user_args[[k]]
  }

  # Re-attach the blank-row attribute (column removal / subsetting can drop
  # custom attributes); rtftable(read_attributes = TRUE) consumes it.
  if (!is.null(blank_attr)) {
    attr(call_args$data, "rtf_blank_rows") <- blank_attr
  }

  # Hide the `drop_cols` columns: remove them from the (now fully resolved)
  # body + every position-indexed argument, so a carrier / grouping column can
  # be used for pagination above and yet never printed.
  if (length(drop_idx)) {
    call_args <- .apply_col_drop(call_args, drop_idx)
  }

  do.call(rtftable, call_args)
}


# Resolve a `drop_cols` spec (character names and/or integer indices, or NULL)
# to a sorted vector of unique integer column indices into `df`.  Errors on
# unknown names / out-of-range indices, and refuses to drop every column.
.resolve_drop_cols <- function(cols, df) {
  if (is.null(cols) || length(cols) == 0L) return(integer(0))
  idx <- vapply(cols, function(c1) {
    if (is.character(c1)) {
      m <- match(c1, names(df))
      if (is.na(m)) {
        stop(sprintf("`drop_cols` column '%s' not found in the table.", c1),
             call. = FALSE)
      }
      as.integer(m)
    } else {
      i <- as.integer(c1)
      if (is.na(i) || i < 1L || i > ncol(df)) {
        stop(sprintf("`drop_cols` index %s out of range (1..%d).",
                     c1, ncol(df)), call. = FALSE)
      }
      i
    }
  }, integer(1L), USE.NAMES = FALSE)
  idx <- sort(unique(idx))
  if (length(idx) >= ncol(df)) {
    stop("`drop_cols` must leave at least one column to display.", call. = FALSE)
  }
  idx
}


# Remove the columns `drop_idx` (positions into the resolved body) from a
# `rtftable()` call-args list, reindexing every position-indexed argument to the
# kept columns.  Mirrors the internal "carry a helper column through pagination,
# strip it before rendering" pattern so a grouping / sort-key column can be used
# by the split and then hidden.  Handled args: data, col_header (flat leaf rows
# and spanning / pos cells), col_spec (integer + name `col`), col_rel_width,
# column_widths_twips, col_header_align, row_title, and per-row cell_styles
# (each per-column vector).  The `rtf_blank_rows` attribute survives the subset.
.apply_col_drop <- function(call_args, drop_idx) {
  data <- call_args$data
  n0   <- ncol(data)
  drop_idx <- sort(unique(as.integer(drop_idx)))
  drop_idx <- drop_idx[drop_idx >= 1L & drop_idx <= n0]
  if (length(drop_idx) == 0L) return(call_args)
  keep <- setdiff(seq_len(n0), drop_idx)
  if (length(keep) == 0L) {
    stop("`drop_cols` must leave at least one column to display.", call. = FALSE)
  }
  old_names  <- names(data)
  drop_names <- old_names[drop_idx]

  # data (preserve the blank-row attribute across the column subset)
  blank_attr <- attr(data, "rtf_blank_rows", exact = TRUE)
  data <- data[keep]
  if (!is.null(blank_attr)) attr(data, "rtf_blank_rows") <- blank_attr
  call_args$data <- data

  # length-n0 positional numeric vectors
  for (k in c("col_rel_width", "column_widths_twips")) {
    v <- call_args[[k]]
    if (!is.null(v) && length(v) == n0) call_args[[k]] <- v[keep]
  }

  # col_header_align: length-n0 vector reindexes; length-1 (scalar) untouched
  cha <- call_args$col_header_align
  if (!is.null(cha) && length(cha) == n0) call_args$col_header_align <- cha[keep]

  # col_header (flat leaf row(s) and spanning / pos cells)
  if (!is.null(call_args$col_header)) {
    call_args$col_header <- .reindex_col_header(call_args$col_header, keep, n0)
  }

  # col_spec: drop entries on a removed column, remap integer `col` to the new
  # position (name `col` survives unchanged -- names are not reused)
  if (!is.null(call_args$col_spec)) {
    call_args$col_spec <- .reindex_col_spec(call_args$col_spec, keep, drop_names)
  }

  # row_title: integer positions remap; column names survive unless dropped
  if (!is.null(call_args$row_title)) {
    call_args$row_title <- .reindex_row_title(call_args$row_title, keep,
                                              drop_names)
  }

  # cell_styles: per-row list; subset each length-n0 per-column vector
  if (!is.null(call_args$cell_styles)) {
    call_args$cell_styles <- lapply(call_args$cell_styles, function(r) {
      if (is.null(r) || !is.list(r)) return(r)
      lapply(r, function(v) if (length(v) == n0) v[keep] else v)
    })
  }

  call_args
}


# Reindex a col_header argument (raw rtftable form) onto the kept columns.
.reindex_col_header <- function(ch, keep, n0) {
  if (is.character(ch)) {
    if (length(ch) == n0) return(ch[keep])
    # pipe-delimited single string: split, reindex if it matches the width
    if (length(ch) == 1L && grepl("|", ch, fixed = TRUE)) {
      parts <- trimws(strsplit(ch, "|", fixed = TRUE)[[1L]])
      if (length(parts) == n0) return(parts[keep])
    }
    return(ch)
  }
  if (is.list(ch)) {
    rows <- lapply(ch, function(row) .reindex_header_row(row, keep, n0))
    rows <- Filter(Negate(is.null), rows)
    if (length(rows) == 0L) return(NULL)
    return(rows)
  }
  ch
}

# One header row: a character leaf row (length n0) or a list of spanning / pos
# cells.  Returns the reindexed row, or NULL if the row becomes empty.
.reindex_header_row <- function(row, keep, n0) {
  if (is.character(row)) {
    if (length(row) == n0) return(row[keep])
    return(row)
  }
  if (is.list(row)) {
    cells <- lapply(row, function(cell) .reindex_header_cell(cell, keep))
    cells <- Filter(Negate(is.null), cells)
    if (length(cells) == 0L) return(NULL)
    return(cells)
  }
  row
}

# One header cell with a `$pos` (single or c(min,max)) or legacy `$from`/`$to`.
# Returns the cell with positions remapped to kept-column coordinates, or NULL
# if every column it covered was dropped.
.reindex_header_cell <- function(cell, keep) {
  if (!is.list(cell)) return(cell)
  remap <- function(p) {
    span   <- if (length(p) <= 1L) p else seq.int(min(p), max(p))
    inside <- intersect(span, keep)
    if (length(inside) == 0L) return(NULL)
    np <- match(inside, keep)
    if (length(np) == 1L) np else c(min(np), max(np))
  }
  if (!is.null(cell$pos)) {
    np <- remap(cell$pos)
    if (is.null(np)) return(NULL)
    cell$pos <- np
    return(cell)
  }
  if (!is.null(cell$from) && !is.null(cell$to)) {
    np <- remap(c(cell$from, cell$to))
    if (is.null(np)) return(NULL)
    cell$from <- min(np)
    cell$to   <- max(np)
    return(cell)
  }
  cell
}

# Reindex a col_spec list onto kept columns.  Integer `col` is remapped to its
# new position (entry dropped if its column was removed); a character `col`
# survives unless it names a dropped column.
.reindex_col_spec <- function(col_spec, keep, drop_names) {
  out <- list()
  for (spec in col_spec) {
    col <- spec$col
    if (is.null(col)) { out[[length(out) + 1L]] <- spec; next }
    if (is.character(col)) {
      if (col %in% drop_names) next
    } else {
      nw <- match(as.integer(col), keep)
      if (is.na(nw)) next
      spec$col <- nw
    }
    out[[length(out) + 1L]] <- spec
  }
  if (length(out) == 0L) return(NULL)
  out
}

# Reindex a row_title argument onto kept columns.  Integer positions are
# remapped; column names survive unless dropped.  Returns NULL (-> rtftable's
# default of column 1) if nothing remains.
.reindex_row_title <- function(rt, keep, drop_names) {
  if (is.null(rt)) return(NULL)
  if (is.character(rt)) {
    rt2 <- rt[!(rt %in% drop_names)]
    if (length(rt2) == 0L) return(NULL)
    return(rt2)
  }
  m <- match(as.integer(rt), keep)
  m <- m[!is.na(m)]
  if (length(m) == 0L) return(NULL)
  m
}
