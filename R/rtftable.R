# rtftable: standalone table object for use with rtfreport.
#
# Holds one or more data.frames plus all table-level formatting metadata.
# Pass an rtftable to rtf_tables() instead of a bare data.frame for richer
# control.

# Normalize a border specification to rtf_table_border.
# Accepts:
#   rtf_table_border          -> returned as-is
#   rtf_table_style (S3)      -> .style_to_table_border(style)
#   "tfl"                     -> rtf_border_tfl()
#   NULL                      -> NULL
#   old plain nested list     -> .plain_list_to_table_border()
.normalize_table_border <- function(border) {
  if (is.null(border)) return(NULL)
  if (inherits(border, "rtf_table_border")) return(border)
  if (inherits(border, "rtf_table_style"))  return(.style_to_table_border(border))
  if (identical(border, "tfl")) return(rtf_border_tfl())
  if (is.list(border)) return(.plain_list_to_table_border(border))
  stop("`border` must be \"tfl\", NULL, an rtf_table_border object, ",
       "an rtf_table_style object, or a named list.", call. = FALSE)
}

# Normalize col_spec: list of per-column lists -> internal indexed form.
#
# Each output element:
#   list(align, bold, italic, underline, indent_twips,
#        header_bold, header_align, header_italic)
#
# Header-align resolution precedence (highest first):
#   1. col_spec entry's header_align (per-column override from user)
#   2. col_header_align argument     (table-wide, scalar or length-ncol)
#   3. col_spec entry's align        (inherit data alignment)
#
# col_header_align: NULL | character(1) | character(ncol).
#
.normalize_col_spec <- function(col_spec, ncol_df, col_names,
                                 col_header_align = NULL,
                                 style = NULL) {
  # Per-column defaults (potentially seeded from `style`).  `header_align`
  # is left NULL so the cascade can fill it in further down.
  base_align         <- if (!is.null(style)) style$align         else "left"
  base_bold          <- if (!is.null(style)) style$bold          else FALSE
  base_italic        <- if (!is.null(style)) style$italic        else FALSE
  base_underline     <- if (!is.null(style)) style$underline     else FALSE
  base_header_bold   <- if (!is.null(style)) style$header_bold   else FALSE
  base_header_italic <- if (!is.null(style)) style$header_italic else FALSE

  result <- lapply(seq_len(ncol_df), function(j) {
    list(
      align         = base_align,
      bold          = base_bold,
      italic        = base_italic,
      underline     = base_underline,
      indent_twips  = 0L,
      header_bold   = base_header_bold,
      header_align  = NULL,            # resolved later (cascade)
      header_italic = base_header_italic,
      border        = NULL             # per-column border override (rtf_border)
    )
  })

  if (!is.null(col_spec)) {
    if (!is.list(col_spec)) stop("`col_spec` must be a list.", call. = FALSE)
    for (spec in col_spec) {
      if (!is.list(spec) || is.null(spec$col)) {
        stop("Each element of `col_spec` must be a list with a `col` key.",
             call. = FALSE)
      }
      col_ref <- spec$col
      if (is.character(col_ref)) {
        idx <- match(col_ref, col_names)
        if (is.na(idx)) stop(sprintf("col_spec col '%s' not found in data.",
                                       col_ref), call. = FALSE)
      } else {
        idx <- as.integer(col_ref)
        if (is.na(idx) || idx < 1L || idx > ncol_df) {
          stop(sprintf("col_spec col index %d out of range (1..%d).",
                       idx, ncol_df), call. = FALSE)
        }
      }
      for (key in setdiff(names(spec), "col")) {
        result[[idx]][[key]] <- spec[[key]]
      }
      # Validate per-column border (must be rtf_border S3 or NULL).
      if (!is.null(result[[idx]]$border) &&
          !inherits(result[[idx]]$border, "rtf_border")) {
        stop(sprintf("col_spec col %d border must be NULL or an rtf_border() object.",
                     idx), call. = FALSE)
      }
    }
  }

  # Expand col_header_align to a per-column vector (or NULL).
  cha <- col_header_align
  if (!is.null(cha)) {
    if (length(cha) == 1L) {
      cha <- rep(as.character(cha), ncol_df)
    } else if (length(cha) != ncol_df) {
      stop(sprintf("`col_header_align` must have length 1 or %d.", ncol_df),
           call. = FALSE)
    } else {
      cha <- as.character(cha)
    }
    if (!all(cha %in% c("left", "center", "right"))) {
      stop("`col_header_align` values must be \"left\", \"center\", or \"right\".",
           call. = FALSE)
    }
  }

  # Cascade fill: header_align <- col_header_align[j] <- align
  for (j in seq_len(ncol_df)) {
    if (is.null(result[[j]]$header_align)) {
      result[[j]]$header_align <- if (!is.null(cha)) cha[[j]] else result[[j]]$align
    }
  }

  result
}

# Normalize the col_header argument into a list whose elements are either:
#   * character vector -- a regular label row (one entry per data column)
#   * list of list(from, to, label, ...) -- a spanning row (renderer's form)
#
# Accepted inputs (in order of detection):
#   NULL                                        -> NULL (renderer uses names(df))
#   character(n)                                -> list of one label row
#   "A | B | C"   (single string)               -> split on '|', single row
#   rtf_col_header object                       -> unclass; list of rows
#   list, top-level all cell specs              -> wrap as a single row
#   list of mixed rows (label / spanning / pos) -> multi-row
#
# `ncol_df` is required when any row uses the new pos-style cell spec
# (it is needed to validate ranges and to fill gaps with empty cells).
.normalize_col_header_rows <- function(col_header, ncol_df = NULL) {
  if (is.null(col_header)) return(NULL)

  # rtf_col_header object -> list of rows (still tagged by class for outer
  # callers; here we strip it so the per-row loop below treats it as data).
  if (inherits(col_header, "rtf_col_header")) {
    col_header <- unclass(col_header)
  }

  # Pipe-delimited string shorthand.
  if (is.character(col_header) && length(col_header) == 1L &&
      grepl("|", col_header, fixed = TRUE)) {
    col_header <- trimws(strsplit(col_header, "|", fixed = TRUE)[[1L]])
  }
  if (is.character(col_header)) {
    return(list(col_header))
  }
  if (!is.list(col_header)) {
    stop("`col_header` must be NULL, character, or a list.", call. = FALSE)
  }

  # Auto-detect: a bare list of cell specs at the top level means a single
  # row of cells, not multiple rows.  Wrap it so the row loop sees one row.
  if (length(col_header) > 0L &&
      all(vapply(col_header, .is_cell_spec, logical(1L)))) {
    col_header <- list(col_header)
  }

  lapply(col_header, function(row) {
    if (is.character(row)) return(row)
    if (!is.list(row) || length(row) == 0L) {
      stop("Each col_header row must be a character vector or a non-empty ",
           "list of cell specs.", call. = FALSE)
    }
    if (.is_cell_spec(row[[1L]])) {
      if (!is.null(row[[1L]]$pos)) {
        if (is.null(ncol_df)) {
          stop("Internal: ncol_df required to normalize pos-style rows.",
               call. = FALSE)
        }
        return(.pos_row_to_spans(row, ncol_df))
      }
      if (!is.null(row[[1L]]$from)) {
        return(row)   # legacy spanning row, leave as-is
      }
    }
    stop("Each col_header element must be a character vector, a list of ",
         "col_cell()/pos-spec cells, or a list of spanning specs ",
         "(list(from, to, label, ...)).", call. = FALSE)
  })
}

# Predicate: is `x` a canonical "header rows list" -- every element being
# either a character vector (label row) or a spanning / pos-cell row
# (list whose first element has $from or $pos)?
.is_header_rows_list <- function(x) {
  if (!is.list(x) || length(x) == 0L) return(FALSE)
  all(vapply(x, function(row) {
    is.character(row) ||
      (is.list(row) && length(row) > 0L &&
         is.list(row[[1L]]) &&
         (!is.null(row[[1L]]$from) || !is.null(row[[1L]]$pos)))
  }, logical(1L)))
}

# Normalize col_header for multi-DF mode.
# Returns a list of length n_dfs, each element is a normalized col_header
# (NULL or a list whose elements are label rows / spanning rows).
# `ncol_df` is required when any row uses pos-style cells.
.normalize_multi_col_header <- function(col_header, n_dfs, ncol_df = NULL) {
  if (is.null(col_header)) return(rep(list(NULL), n_dfs))

  # rtf_col_header instance is treated as a shared header for all DFs.
  if (inherits(col_header, "rtf_col_header")) {
    h <- .normalize_col_header_rows(col_header, ncol_df)
    return(rep(list(h), n_dfs))
  }

  # Plain character -> shared single label row for all DFs.
  if (is.character(col_header)) {
    h <- .normalize_col_header_rows(col_header, ncol_df)
    return(rep(list(h), n_dfs))
  }

  if (!is.list(col_header)) {
    stop("`col_header` must be NULL, a character vector, or a list.",
         call. = FALSE)
  }

  # A bare list of cell specs is a single row -- same handling as the
  # single-DF normalizer.
  if (length(col_header) > 0L &&
      all(vapply(col_header, .is_cell_spec, logical(1L)))) {
    h <- .normalize_col_header_rows(col_header, ncol_df)
    return(rep(list(h), n_dfs))
  }

  .is_per_df_spec <- function(x) {
    is.null(x) || inherits(x, "rtf_col_header") ||
      is.character(x) || .is_header_rows_list(x)
  }

  if (length(col_header) == n_dfs &&
      all(vapply(col_header, .is_per_df_spec, logical(1L)))) {
    return(lapply(col_header,
                   function(h) .normalize_col_header_rows(h, ncol_df)))
  }

  # Otherwise treat as shared multi-row header.
  if (!.is_header_rows_list(col_header)) {
    stop("Multi-row col_header must contain only character vectors and ",
         "cell-spec rows (col_cell()/pos-spec, or list(from, to, ...)).",
         call. = FALSE)
  }
  h <- .normalize_col_header_rows(col_header, ncol_df)
  rep(list(h), n_dfs)
}


# -- Internal S3 constructor --------------------------------------------------
#
# Builds an `rtftable` S3 object containing the normalized fields the
# renderer expects.  Public callers use rtftable() in wrappers.R; this
# function does the heavy lifting (validation, default resolution,
# normalization) regardless of the entry point.

.new_rtftable <- function(
  data,
  col_header = NULL,
  col_header_align = NULL,
  spanning_header = NULL,
  col_spec = NULL,
  border = "tfl",
  blank_rows = NULL,
  read_attributes = TRUE,
  style = NULL,
  col_rel_width = NULL,
  column_widths_twips = NULL,
  table_width_twips = NULL,
  table_width_pct_of_writable = NULL,
  table_width_pct = NULL,
  table_align = "left",
  row_height_twips = NULL,
  row_height_exact = FALSE,
  header_row_height_twips = NULL,
  blank_row_height_twips = NULL,
  cell_padding_left_twips = 0L,
  cell_padding_right_twips = 0L,
  cell_valign = "bottom",
  cell_styles = NULL
) {
  # -- Resolve defaults from a shared style template, when supplied ---
  # The style provides defaults; explicit arguments always override.
  if (!is.null(style)) {
    if (!inherits(style, "rtf_table_style")) {
      stop("`style` must be an rtf_table_style object.", call. = FALSE)
    }
    # `border` is "tfl" by default -- only adopt the style's borders
    # when the caller has not passed an rtf_table_border or another
    # explicit object.
    if (identical(border, "tfl")) border <- style
    if (is.null(col_header_align)) col_header_align <- style$header_align
    if (is.null(row_height_twips)) row_height_twips <- style$row_height_twips
    if (!is.null(style$cell_padding_left_twips) &&
        identical(cell_padding_left_twips, 72L)) {
      cell_padding_left_twips <- style$cell_padding_left_twips
    }
    if (!is.null(style$cell_padding_right_twips) &&
        identical(cell_padding_right_twips, 72L)) {
      cell_padding_right_twips <- style$cell_padding_right_twips
    }
  }

  data_single  <- NULL
  data_list    <- NULL
  col_hdr_one  <- NULL
  col_hdr_list <- NULL

  if (is.data.frame(data)) {
    # -- Single data.frame mode --------------------------------------------
    data_single <- data

    # Normalize col_header to a list whose elements are either:
    #   - character vector  (regular label row)
    #   - list of list(from, to, label, underline)  (spanning row)
    col_hdr_one <- .normalize_col_header_rows(col_header, ncol(data))

    cs <- .normalize_col_spec(
      col_spec, ncol(data), names(data),
      col_header_align = col_header_align,
      style            = style)

    # Read recognised attributes off the data.frame as fallback defaults.
    if (isTRUE(read_attributes)) {
      attr_data <- .read_data_attributes(data)
      if (is.null(blank_rows) && !is.null(attr_data$blank_rows)) {
        blank_rows <- attr_data$blank_rows
      }
    }

  } else if (is.list(data) && length(data) > 0L) {
    # -- Multi data.frame mode ---------------------------------------------
    for (i in seq_along(data)) {
      if (!is.data.frame(data[[i]])) {
        stop(sprintf("`data[[%d]]` must be a data.frame.", i), call. = FALSE)
      }
    }
    ncols_all <- vapply(data, ncol, integer(1L))
    if (length(unique(ncols_all)) > 1L) {
      stop("All data.frames in `data` must have the same number of columns.",
           call. = FALSE)
    }
    data_list    <- data
    col_hdr_list <- .normalize_multi_col_header(col_header, length(data),
                                                  ncol_df = ncols_all[1L])

    ref_ncol  <- ncols_all[1L]
    ref_names <- names(data[[1L]])
    cs <- .normalize_col_spec(
      col_spec, ref_ncol, ref_names,
      col_header_align = col_header_align,
      style            = style)

  } else {
    stop("`data` must be a data.frame or a non-empty list of data.frames.",
         call. = FALSE)
  }

  # Border: normalize to rtf_table_border (or NULL for no borders).
  border_resolved <- .normalize_table_border(border)

  # Resolve blank_rows spec into a sorted integer vector of positions.
  blank_rows_resolved <- NULL
  if (!is.null(blank_rows)) {
    if (is.data.frame(data)) {
      blank_rows_resolved <- .resolve_blank_rows(blank_rows, data)
    } else {
      # Multi-DF: only integer positions supported here (applied per-DF).
      if (!is.numeric(blank_rows) || is.list(blank_rows)) {
        stop("In multi-DF mode, `blank_rows` must be an integer vector ",
             "of positions; by_change / by_rule specs are not supported.",
             call. = FALSE)
      }
      v <- as.integer(blank_rows)
      if (any(is.na(v)) || any(v < -1L)) {
        stop("`blank_rows` integers must be -1, 0, or positive.", call. = FALSE)
      }
      blank_rows_resolved <- sort(unique(v))
    }
  }

  # table width %
  twpw <- table_width_pct_of_writable
  if (!is.null(table_width_pct)) {
    pct <- as.numeric(table_width_pct)
    if (is.na(pct) || pct <= 0 || pct > 100) {
      stop("`table_width_pct` must be a number in (0, 100].", call. = FALSE)
    }
    twpw <- pct / 100
  }

  if (!table_align %in% c("left", "center", "right")) {
    stop("`table_align` must be 'left', 'center', or 'right'.", call. = FALSE)
  }
  if (!is.logical(row_height_exact) || length(row_height_exact) != 1L) {
    stop("`row_height_exact` must be TRUE or FALSE.", call. = FALSE)
  }
  if (!cell_valign %in% c("top", "center", "bottom")) {
    stop("`cell_valign` must be 'top', 'center', or 'bottom'.", call. = FALSE)
  }

  # Validate and normalise cell_styles.
  # Must be NULL or a list of length == total data rows.
  total_rows <- if (!is.null(data_single)) nrow(data_single)
                else sum(vapply(data_list, nrow, integer(1L)))
  cell_styles_resolved <- NULL
  if (!is.null(cell_styles)) {
    if (!is.list(cell_styles)) {
      stop("`cell_styles` must be a list (one element per data row) or NULL.",
           call. = FALSE)
    }
    if (length(cell_styles) != total_rows) {
      stop(sprintf(
        "`cell_styles` length (%d) must equal the number of data rows (%d).",
        length(cell_styles), total_rows), call. = FALSE)
    }
    cell_styles_resolved <- cell_styles
  }

  structure(
    list(
      data                        = data_single,
      data_list                   = data_list,
      col_header                  = col_hdr_one,
      col_header_list             = col_hdr_list,
      spanning_header             = spanning_header,
      col_spec                    = cs,
      border                      = border_resolved,
      blank_rows                  = blank_rows_resolved,
      col_rel_width               = col_rel_width,
      column_widths_twips         = if (!is.null(column_widths_twips)) as.integer(column_widths_twips) else NULL,
      table_width_twips           = table_width_twips,
      table_width_pct_of_writable = twpw,
      table_align                 = table_align,
      row_height_twips            = if (is.null(row_height_twips)) NULL else as.integer(row_height_twips),
      row_height_exact            = row_height_exact,
      header_row_height_twips     = if (!is.null(header_row_height_twips)) as.integer(header_row_height_twips) else NULL,
      blank_row_height_twips      = if (!is.null(blank_row_height_twips)) as.integer(blank_row_height_twips) else NULL,
      cell_padding_left_twips     = as.integer(cell_padding_left_twips),
      cell_padding_right_twips    = as.integer(cell_padding_right_twips),
      cell_valign                 = cell_valign,
      cell_styles                 = cell_styles_resolved
    ),
    class = "rtftable"
  )
}


# Apply explicitly-passed rtf_tables() formatting overrides onto a pre-built
# rtftable, in place of the table's own / gt-derived values.  `ov` is a named
# list containing ONLY the arguments the caller passed explicitly (see
# rtf_tables()); fields absent from `ov` are left untouched.  Each value is
# normalised exactly as the rtftable() constructor would.
.override_rtftable_fields <- function(tbl, ov) {
  if (length(ov) == 0L) return(tbl)
  has <- function(k) k %in% names(ov)

  ref_df    <- if (!is.null(tbl$data_list)) tbl$data_list[[1L]] else tbl$data
  ncol_df   <- if (!is.null(ref_df)) ncol(ref_df) else length(tbl$col_spec)
  col_names <- if (!is.null(ref_df)) names(ref_df) else NULL

  # -- column / table widths and placement (stored verbatim) --------------
  if (has("col_rel_width"))        tbl$col_rel_width <- ov$col_rel_width
  if (has("column_widths_twips"))  tbl$column_widths_twips <-
      if (is.null(ov$column_widths_twips)) NULL else as.integer(ov$column_widths_twips)
  if (has("table_width_twips"))    tbl$table_width_twips <- ov$table_width_twips
  if (has("table_width_pct_of_writable"))
    tbl$table_width_pct_of_writable <- ov$table_width_pct_of_writable
  if (has("table_width_pct") && !is.null(ov$table_width_pct)) {
    pct <- as.numeric(ov$table_width_pct)
    if (is.na(pct) || pct <= 0 || pct > 100) {
      stop("`table_width_pct` must be a number in (0, 100].", call. = FALSE)
    }
    tbl$table_width_pct_of_writable <- pct / 100
  }
  if (has("table_align")) {
    if (!ov$table_align %in% c("left", "center", "right")) {
      stop("`table_align` must be 'left', 'center', or 'right'.", call. = FALSE)
    }
    tbl$table_align <- ov$table_align
  }

  # -- row heights ---------------------------------------------------------
  if (has("row_height_twips"))
    tbl$row_height_twips <- if (is.null(ov$row_height_twips)) NULL
                            else as.integer(ov$row_height_twips)
  if (has("row_height_exact")) {
    if (!is.logical(ov$row_height_exact) || length(ov$row_height_exact) != 1L) {
      stop("`row_height_exact` must be TRUE or FALSE.", call. = FALSE)
    }
    tbl$row_height_exact <- ov$row_height_exact
  }
  if (has("header_row_height_twips"))
    tbl$header_row_height_twips <- if (is.null(ov$header_row_height_twips)) NULL
                                   else as.integer(ov$header_row_height_twips)
  if (has("blank_row_height_twips"))
    tbl$blank_row_height_twips <- if (is.null(ov$blank_row_height_twips)) NULL
                                  else as.integer(ov$blank_row_height_twips)

  # -- cell padding / valign ----------------------------------------------
  if (has("cell_padding_left_twips"))
    tbl$cell_padding_left_twips <- as.integer(ov$cell_padding_left_twips)
  if (has("cell_padding_right_twips"))
    tbl$cell_padding_right_twips <- as.integer(ov$cell_padding_right_twips)
  if (has("cell_valign")) {
    if (!ov$cell_valign %in% c("top", "center", "bottom")) {
      stop("`cell_valign` must be 'top', 'center', or 'bottom'.", call. = FALSE)
    }
    tbl$cell_valign <- ov$cell_valign
  }

  # -- border (needs normalisation) ---------------------------------------
  if (has("border")) tbl$border <- .normalize_table_border(ov$border)

  # -- spanning header (stored verbatim) ----------------------------------
  if (has("spanning_header")) tbl$spanning_header <- ov$spanning_header

  # -- column header (single- vs multi-DF) --------------------------------
  if (has("col_header")) {
    if (!is.null(tbl$data_list)) {
      tbl$col_header_list <- .normalize_multi_col_header(
        ov$col_header, length(tbl$data_list), ncol_df = ncol_df)
    } else {
      tbl$col_header <- .normalize_col_header_rows(ov$col_header, ncol_df)
    }
  }

  # -- blank rows (resolve against the table's data) ----------------------
  if (has("blank_rows")) {
    if (is.null(ov$blank_rows)) {
      tbl$blank_rows <- NULL
    } else if (!is.null(tbl$data)) {
      tbl$blank_rows <- .resolve_blank_rows(ov$blank_rows, tbl$data)
    } else {
      v <- as.integer(ov$blank_rows)
      tbl$blank_rows <- sort(unique(v))
    }
  }

  # -- per-column spec: merge user fields over the existing spec ----------
  if (has("col_spec") && !is.null(ov$col_spec)) {
    for (spec in ov$col_spec) {
      if (!is.list(spec) || is.null(spec$col)) {
        stop("Each element of `col_spec` must be a list with a `col` key.",
             call. = FALSE)
      }
      idx <- if (is.character(spec$col)) match(spec$col, col_names)
             else as.integer(spec$col)
      if (is.na(idx) || idx < 1L || idx > length(tbl$col_spec)) next
      for (f in setdiff(names(spec), "col")) tbl$col_spec[[idx]][[f]] <- spec[[f]]
      # The column header (and any spanning header above it) inherits the
      # data alignment unless the header alignment is set explicitly.  When
      # this override changes `align` but not `header_align`, re-inherit so
      # the headers follow -- matching the construction-time cascade.
      if ("align" %in% names(spec) && !("header_align" %in% names(spec))) {
        tbl$col_spec[[idx]]$header_align <- spec$align
      }
    }
  }

  # -- column-header alignment (top-priority override of the cascade) -----
  if (has("col_header_align") && !is.null(ov$col_header_align)) {
    cha <- ov$col_header_align
    for (j in seq_along(tbl$col_spec)) {
      tbl$col_spec[[j]]$header_align <- if (length(cha) == 1L) cha else cha[[j]]
    }
  }

  # NB: `style` is a construction-time defaults seed and is NOT applied as a
  # post-hoc override to a pre-built rtftable; pass it to rtftable() /
  # as_rtftables() instead.

  tbl
}
