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
#' tables, plain `data.frame` / tibble, or a `list` of any of these (the list
#' is flattened, names propagated as `name`, `name.1`, `name.2`, ...).
#' Figures are out of scope -- use [rtf_figures()] for those.
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
#' \tabular{lll}{
#'   **Metadata** \tab **gt / gtsummary** \tab **rtables / tern** \cr
#'   Column (leaf) labels        \tab yes \tab yes \cr
#'   Per-column alignment        \tab yes \tab yes \cr
#'   Spanning headers            \tab yes \tab yes \cr
#'   Column widths               \tab yes (px/pct) \tab -- \cr
#'   Title + subtitle            \tab yes \tab yes \cr
#'   Footnotes / source notes    \tab yes \tab yes \cr
#'   In-cell footnote marks      \tab yes (superscript) \tab yes (superscript) \cr
#'   Row-group rows + indent     \tab yes (rendered) \tab yes (rendered) \cr
#' }
#'
#' **Not carried** (RTF cannot reproduce these, so they are intentionally
#' ignored): per-cell bold / italic / underline from `gt::tab_style()`, cell
#' background colours / fills, font and size styling, and Markdown formatting
#' inside labels or titles.  Plain `data.frame` / tibble inputs carry no
#' metadata at all -- set `col_header`, `col_spec`, etc. yourself.
#'
#' @param x A `gt_tbl`, a gtsummary table, an rtables/tern `VTableTree`, a
#'   `data.frame` / tibble, or a `list` of these.
#' @param read_meta Controls metadata extraction from the source table:
#'   `TRUE` (default, read everything in the table above), `FALSE` (use only
#'   the rendered body -- equivalent to the old `paginate()`), or a character
#'   vector of tokens.  Ignored for plain data.frame inputs.  Tokens for
#'   gt/gtsummary: `"col_header"`, `"alignment"`, `"spanning"`, `"widths"`,
#'   `"titles"`, `"footnotes"`.  For rtables/tern: `"col_header"`,
#'   `"alignment"`, `"spanning"`, `"titles"`, `"footnotes"`, `"indent"`,
#'   `"footnote_marks"`.
#' @param max_rows,split,split_rows,group_col,cont_label,blank_rows,blank_row_first,blank_row_end,align_count_pct
#'   Pagination controls.  Identical meaning to the (now deprecated)
#'   `paginate()`.  `split = "none"` (default) keeps the whole table as a
#'   single page.
#' @param border,style Passed to [rtftable()] for every page.  `border`
#'   defaults to `"tfl"`.
#' @param ... Further arguments forwarded to [rtftable()] for every page
#'   (e.g. `col_header`, `col_spec`, `col_rel_width`, `row_height_twips`).
#'   Explicit values always win over the gt-extracted ones.
#'
#' @return A list of `rtftable` objects, one per page.  When the split is
#'   value-based (or the input was a named list) the list is named.
#'
#' @seealso [as_rtftable()] for the single-page convenience wrapper,
#'   [rtf_tables()] to append the result to a document.
#'
#' @examples
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
                         cont_label      = " (Cont.)",
                         blank_rows      = NULL,
                         blank_row_first = FALSE,
                         blank_row_end   = FALSE,
                         align_count_pct = FALSE,
                         border          = "tfl",
                         style           = NULL,
                         ...) {
  split     <- match.arg(split)
  user_args <- list(...)

  # ---- list input: recurse, concatenate, propagate names ----------------
  if (is.list(x) && !is.data.frame(x) && !isS4(x) &&
      !.is_gt_tbl(x) && !.is_gtsummary_tbl(x) && !.is_rtables_tbl(x)) {
    if (length(x) == 0L) return(list())
    in_names <- names(x)
    out <- list()
    for (i in seq_along(x)) {
      chunks <- as_rtftables(
        x[[i]], read_meta = read_meta, max_rows = max_rows, split = split,
        split_rows = split_rows, group_col = group_col, cont_label = cont_label,
        blank_rows = blank_rows, blank_row_first = blank_row_first,
        blank_row_end = blank_row_end, align_count_pct = align_count_pct,
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
  } else if (is.data.frame(x)) {
    body            <- x
    kw              <- list()
    cell_styles     <- NULL
    titles_block    <- NULL
    footnotes_block <- NULL
  } else {
    stop("`as_rtftables()` supports gt_tbl, gtsummary, data.frame/tibble, ",
         "or a list of these; got '", paste(class(x), collapse = "/"), "'.",
         call. = FALSE)
  }

  # ---- paginate (tracking original rows so per-cell styles can be sliced)
  have_styles <- !is.null(cell_styles)
  sidx_col    <- ".__rtf_sidx__"
  if (have_styles) body[[sidx_col]] <- seq_len(nrow(body))

  pages <- .paginate_df(
    body, max_rows = max_rows, split = split, split_rows = split_rows,
    group_col = group_col, cont_label = cont_label, blank_rows = blank_rows,
    blank_row_first = blank_row_first, blank_row_end = blank_row_end,
    align_count_pct = align_count_pct)
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
                                   border, style, blank_attr)
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
                                     border, style, blank_attr) {
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

  do.call(rtftable, call_args)
}
