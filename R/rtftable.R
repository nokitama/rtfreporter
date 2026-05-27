# rtftable: standalone table object for use with rtfreport.
#
# Holds one or more data.frames plus all table-level formatting metadata.
# Pass an rtftable to rtf_tables() instead of a bare data.frame for richer
# control.

# Normalize a border specification to rtf_table_border.
# Accepts:
#   rtf_table_border          → returned as-is
#   rtf_table_style (S3)      → .style_to_table_border(style)
#   "tfl"                     → rtf_border_tfl()
#   NULL                      → NULL
#   old plain nested list     → .plain_list_to_table_border()
.normalize_table_border <- function(border) {
  if (is.null(border)) return(NULL)
  if (inherits(border, "rtf_table_border")) return(border)
  if (inherits(border, "rtf_table_style"))  return(.style_to_table_border(border))
  if (identical(border, "tfl")) return(rtf_border_tfl())
  if (is.list(border)) return(.plain_list_to_table_border(border))
  stop("`border` must be \"tfl\", NULL, an rtf_table_border object, ",
       "an rtf_table_style object, or a named list.", call. = FALSE)
}

# Normalize col_spec: list of per-column lists → internal indexed form.
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

  # Cascade fill: header_align ← col_header_align[j] ← align
  for (j in seq_len(ncol_df)) {
    if (is.null(result[[j]]$header_align)) {
      result[[j]]$header_align <- if (!is.null(cha)) cha[[j]] else result[[j]]$align
    }
  }

  result
}

# Normalize the col_header argument into a list whose elements are either:
#   * character vector — a regular label row (one entry per data column)
#   * list of list(from, to, label, underline) — a spanning row
#
# Backward-compatible inputs accepted:
#   NULL                       → NULL (renderer uses names(df))
#   character(n)               → list of one label row
#   "A | B | C"  (single str)  → split on '|', wrapped as one label row
#   list of mixed              → already in canonical form; pass through
.normalize_col_header_rows <- function(col_header) {
  if (is.null(col_header)) return(NULL)

  # Pipe-delimited string shorthand.
  if (is.character(col_header) && length(col_header) == 1L &&
      grepl("|", col_header, fixed = TRUE)) {
    col_header <- trimws(strsplit(col_header, "|", fixed = TRUE)[[1L]])
  }
  if (is.character(col_header)) {
    return(list(col_header))
  }
  if (is.list(col_header)) {
    # Validate each element is a label-row (character) or spanning row
    # (list of list(from, to, label, ...)).
    out <- lapply(col_header, function(row) {
      if (is.character(row)) return(row)
      if (is.list(row) && length(row) > 0L &&
          is.list(row[[1L]]) && !is.null(row[[1L]]$from)) {
        return(row)   # spanning row, leave as-is
      }
      stop("Each col_header element must be a character vector or a list of ",
           "spanning specs (list(from, to, label, underline)).", call. = FALSE)
    })
    return(out)
  }
  stop("`col_header` must be NULL, character, or a list.", call. = FALSE)
}

# Predicate: is `x` a canonical "header rows list" — every element being
# either a character vector (label row) or a spanning row
# (list of list(from, to, label, ...))?
.is_header_rows_list <- function(x) {
  if (!is.list(x) || length(x) == 0L) return(FALSE)
  all(vapply(x, function(row) {
    is.character(row) ||
      (is.list(row) && length(row) > 0L &&
         is.list(row[[1L]]) && !is.null(row[[1L]]$from))
  }, logical(1L)))
}

# Normalize col_header for multi-DF mode.
# Returns a list of length n_dfs, each element is a normalized col_header
# (NULL or a list whose elements are label rows / spanning rows).
.normalize_multi_col_header <- function(col_header, n_dfs) {
  if (is.null(col_header)) return(rep(list(NULL), n_dfs))

  # Plain character → shared single label row for all DFs.
  if (is.character(col_header)) {
    h <- .normalize_col_header_rows(col_header)
    return(rep(list(h), n_dfs))
  }

  if (!is.list(col_header)) {
    stop("`col_header` must be NULL, a character vector, or a list.", call. = FALSE)
  }

  .is_per_df_spec <- function(x) {
    is.null(x) || is.character(x) || .is_header_rows_list(x)
  }

  if (length(col_header) == n_dfs &&
      all(vapply(col_header, .is_per_df_spec, logical(1L)))) {
    # Per-DF specs.
    return(lapply(col_header, .normalize_col_header_rows))
  }

  # Otherwise treat as shared multi-row header.
  if (!.is_header_rows_list(col_header)) {
    stop("Multi-row col_header must contain only character vectors and ",
         "spanning specs (list of list(from, to, label, ...)).", call. = FALSE)
  }
  h <- .normalize_col_header_rows(col_header)
  rep(list(h), n_dfs)
}


# ── Internal S3 constructor ──────────────────────────────────────────────────
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
  cell_padding_left_twips = 72L,
  cell_padding_right_twips = 72L,
  cell_valign = "bottom"
) {
  # ── Resolve defaults from a shared style template, when supplied ───
  # The style provides defaults; explicit arguments always override.
  if (!is.null(style)) {
    if (!inherits(style, "rtf_table_style")) {
      stop("`style` must be an rtf_table_style object.", call. = FALSE)
    }
    # `border` is "tfl" by default — only adopt the style's borders
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
    # ── Single data.frame mode ────────────────────────────────────────────
    data_single <- data

    # Normalize col_header to a list whose elements are either:
    #   - character vector  (regular label row)
    #   - list of list(from, to, label, underline)  (spanning row)
    col_hdr_one <- .normalize_col_header_rows(col_header)

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
    # ── Multi data.frame mode ─────────────────────────────────────────────
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
    col_hdr_list <- .normalize_multi_col_header(col_header, length(data))

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
      cell_valign                 = cell_valign
    ),
    class = "rtftable"
  )
}
