#' Convert a gt object to an rtftable
#'
#' Bridges the [gt](https://gt.rstudio.com) package and rtfreporter:
#' takes a `gt_tbl` built with gt's friendly API
#' (`cols_label()`, `tab_header()`, `cols_align()`, `tab_source_note()`,
#' ...) and returns an `rtftable` that can be passed directly to
#' [rtf_tables()] in a pipe chain.
#'
#' @section What is extracted from the gt_tbl:
#'
#' When `read = TRUE` (default), the following gt attributes are read
#' and used to fill in rtftable defaults:
#'
#' \describe{
#'   \item{column labels}{from `gt_obj[["_boxhead"]]$column_label` ->
#'     used as the `col_header`.}
#'   \item{per-column alignment}{from
#'     `gt_obj[["_boxhead"]]$column_align` -> used as `col_spec[[j]]$align`.}
#' }
#'
#' Title / subtitle and source notes also live on the `gt_tbl`, but
#' they map to page-level slots in rtfreporter (`titles[[i]]` and
#' `footnotes[[i]]`), not to the rtftable itself.  Use `read_gt = TRUE`
#' on [rtf_tables()] to pull them through automatically -- or pass them
#' explicitly via [rtf_titles()] / [rtf_footnotes()].
#'
#' @section Granular control:
#'
#' Pass `read = c(...)` with one or more of the following tokens
#' instead of `TRUE` to opt in selectively:
#'
#' * `"col_header"`   -- column labels
#' * `"alignment"`    -- per-column alignment
#'
#' (`"titles"` and `"source_notes"` are recognised but apply at the
#' [rtf_tables()] level, not here.)
#'
#' `read = FALSE` is equivalent to `as.data.frame(gt_obj) |> rtftable(...)`.
#'
#' @param gt_obj A `gt_tbl` object built with the gt package.
#' @param read `TRUE` (default), `FALSE`, or a character vector of
#'   tokens listed above.  Controls which gt attributes are read.
#' @param ... Passed to [rtftable()].  Explicit values always win
#'   over the gt-extracted ones.
#'
#' @return An `rtftable` S3 object.
#'
#' @examples
#' \dontrun{
#' library(gt)
#'
#' g <- gt(head(mtcars, 5)) |>
#'   cols_label(mpg = "MPG", cyl = "Cyl") |>
#'   cols_align("right", columns = c(mpg, cyl))
#'
#' # Convert and use in a pipe chain
#' tbl <- as_rtftable(g)
#'
#' doc <- rtf_document() |>
#'   rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
#'   rtf_tables(list(tbl))
#'
#' generate_rtfreport(doc, "output.rtf", overwrite = TRUE)
#' }
#'
#' @seealso [rtf_tables()] -- accepts `gt_tbl` objects directly with
#'   `read_gt =` for title / subtitle / source-note flow-through.
#'
#' @export
as_rtftable <- function(gt_obj, read = TRUE, ...) {
  if (!.is_gt_tbl(gt_obj)) {
    stop("`gt_obj` must be a gt_tbl.", call. = FALSE)
  }
  if (!requireNamespace("gt", quietly = TRUE)) {
    stop("`as_rtftable()` requires the `gt` package.  Install it with ",
         "install.packages(\"gt\").", call. = FALSE)
  }

  tokens     <- .resolve_gt_tokens(read)
  gt_kwargs  <- .gt_to_rtftable_kwargs(gt_obj, tokens = tokens)
  user_args  <- list(...)

  # data: gt-derived data.frame is what we use.  No way to override
  # without breaking the abstraction.
  call_args <- list(data = gt_kwargs$data)

  # col_header: prefer user, fall back to gt.
  if (!is.null(user_args$col_header)) {
    call_args$col_header <- user_args$col_header
  } else if (!is.null(gt_kwargs$col_header)) {
    call_args$col_header <- gt_kwargs$col_header
  }

  # col_spec: deep-merge per-column.  Each user col_spec entry wins for
  # the fields it specifies; gt's `align` fills the gaps.
  if (!is.null(gt_kwargs$col_spec) || !is.null(user_args$col_spec)) {
    call_args$col_spec <- .merge_col_spec(user_args$col_spec,
                                          gt_kwargs$col_spec)
  }

  # All other arguments pass through verbatim.
  for (k in setdiff(names(user_args), c("data", "col_header", "col_spec"))) {
    call_args[[k]] <- user_args[[k]]
  }

  do.call(rtftable, call_args)
}


# Per-column merge of col_spec lists.  `user` wins for any field it
# specifies; missing fields fall back to the corresponding entry in
# `gt`.  Either argument may be NULL.
.merge_col_spec <- function(user, gt) {
  if (is.null(user)) return(gt)
  if (is.null(gt))   return(user)

  # Build a hash keyed by `col` (numeric index or character name) so we
  # can merge entries that target the same column.
  key <- function(e) {
    if (is.null(e$col)) "" else paste0("col:", as.character(e$col))
  }
  merged <- list()
  for (e in gt) merged[[key(e)]] <- e
  for (e in user) {
    k <- key(e)
    if (!is.null(merged[[k]])) {
      # Per-field merge: user overrides gt for matching keys.
      base <- merged[[k]]
      for (f in setdiff(names(e), "col")) base[[f]] <- e[[f]]
      merged[[k]] <- base
    } else {
      merged[[k]] <- e
    }
  }
  unname(merged)
}
