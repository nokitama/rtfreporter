# Pipe Composition API for rtfreporter
# S3-based immutable composition interface for building RTF reports with pipes (%>%)
#
# This is the primary public API. Build a document by piping rtf_document()
# through rtf_tables(), rtf_section(), format functions, then generate_rtfreport().

# ============================================================================
# Utility: NULL-coalescing operator
# ============================================================================

# NULL-coalescing operator: returns a if not NULL, otherwise b
`%||%` <- function(a, b) if (!is.null(a)) a else b

# ============================================================================
# S3 Constructor: rtf_document()
# ============================================================================

#' Create an RTF document for pipe composition
#'
#' Initialize a new RTF document object for building reports with pipes.
#' Provides sensible defaults for clinical trial reports.
#'
#' @param font_table Optional font table. Default: list(list(name = "Courier"))
#' @param color_table Optional color table. Default: c("#000000")
#' @param page Optional page settings (orientation, dimensions, margins).
#'             Default: landscape letter 11x8.5", margins 0.9 inch
#'             (top/bottom) and 0.6 inch (left/right).
#' @param default_format Optional document-wide default formatting.
#'
#' @return An rtf_document object (S3 class) with structure:
#'   - document: list(font_table, color_table, page, default_format)
#'   - contents: list (initially empty, populated by rtf_tables/rtf_figures)
#'   - sections: list (initially empty, populated by rtf_section)
#'
#' @examples
#' \dontrun{
#' doc <- rtf_document()
#' }
#'
#' @export
rtf_document <- function(font_table = NULL, color_table = NULL, page = NULL,
                         default_format = NULL) {
  # Default clinical trial settings
  if (is.null(page)) {
    page <- list(
      orientation = "landscape",
      width_in = 11,
      height_in = 8.5,
      margin_top_in = 0.9,
      margin_bottom_in = 0.9,
      margin_left_in = 0.6,
      margin_right_in = 0.6
    )
  }

  if (is.null(font_table)) {
    font_table <- list(list(name = "Courier"))
  }

  if (is.null(color_table)) {
    color_table <- c("#000000")
  }

  # Create immutable S3 object
  doc <- structure(
    list(
      document = list(
        font_table = font_table,
        color_table = color_table,
        page = page,
        default_format = default_format
      ),
      contents  = list(),
      titles    = list(),
      footnotes = list(),
      sections  = list()
    ),
    class = "rtf_document"
  )

  doc
}

# ============================================================================
# rtf_config() - Document-level settings
# ============================================================================

#' Configure document-level settings
#'
#' Update font, color, page, or default formatting for the document.
#' This function is typically called once after creating a document.
#' Only non-NULL parameters are updated (NULL = no change).
#'
#' @param doc An rtf_document object.
#' @param font_table Optional font table to replace default.
#' @param color_table Optional color table to replace default.
#' @param page Optional page settings list.
#' @param default_format Optional document-wide default formatting.
#'
#' @return Modified rtf_document object (new copy, original unchanged).
#'
#' @export
rtf_config <- function(doc, font_table = NULL, color_table = NULL, page = NULL,
                       default_format = NULL) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }

  # Create a copy (immutable pattern)
  doc_copy <- doc

  # Update only non-NULL parameters
  if (!is.null(font_table)) {
    doc_copy$document$font_table <- font_table
  }
  if (!is.null(color_table)) {
    doc_copy$document$color_table <- color_table
  }
  if (!is.null(page)) {
    doc_copy$document$page <- page
  }
  if (!is.null(default_format)) {
    doc_copy$document$default_format <- default_format
  }

  doc_copy
}

# ============================================================================
# Content Addition: rtf_tables() and rtf_figures()
# ============================================================================

#' Add content pages to document
#'
#' Append one or more content items as pages. **Each element of `tables`
#' becomes exactly one page**, holding a single table or figure.
#'
#' Table-formatting arguments (`col_rel_width`, `border`, `row_height_twips`,
#' ...) accepted by this function are applied **only to bare `data.frame`
#' elements** of `tables`. Elements already constructed via `rtftable()` or
#' `rtfplot()` carry their own settings and are not overridden.
#'
#' @param doc An rtf_document object.
#' @param tables A list where each element is one page's content. Each
#'   element must be one of:
#'   - `data.frame`: simple table; the table-format arguments below apply.
#'   - `rtftable` object (from `rtftable()`): table with full formatting.
#'   - `rtfplot` object (from `rtfplot()`): embedded figure.
#' @param col_rel_width,column_widths_twips,table_width_twips,table_width_pct_of_writable,table_width_pct,table_align Column-width and table-width settings applied to bare `data.frame` elements. See [rtftable()] for details.
#' @param col_header,col_header_align,spanning_header,col_spec,border,blank_rows,read_attributes,style Per-table content settings applied to bare `data.frame` elements. See [rtftable()] for details.
#' @param row_height_twips,row_height_exact,header_row_height_twips,blank_row_height_twips Row-height settings applied to bare `data.frame` elements. See [rtftable()] for details.
#' @param cell_padding_left_twips,cell_padding_right_twips,cell_valign Cell layout settings applied to bare `data.frame` elements. See [rtftable()] for details.
#' @param titles `NULL` (default) or a list of length `length(tables)`. Each
#'   element is a character vector -- one element per row of that page's
#'   title.  Magic tokens \code{"\{HALF_BLANK_ROW\}"} and
#'   \code{"\{BLANK_ROW\}"} are honoured.  Use `NULL` per element to
#'   fall back to the default (\code{\{HALF_BLANK_ROW\}} -- one
#'   half-height blank row).
#' @param footnotes `NULL` (default) or a list of length `length(tables)`.
#'   Same structure as `titles`; each element becomes one row in the
#'   footnote block.  Magic tokens supported.
#' @param auto_section Logical. When `TRUE` and `tables` is a **named** list,
#'   each name is used as a per-section heading appended to the common header
#'   defined by `rtf_section(secinfo = ...)` (called without a `page` argument).
#'   The document is then automatically split into one RTF section per named
#'   element. Unnamed items fall through to the previous section.
#'   Default `FALSE`.
#' @param section_label_align Alignment for the auto-appended section label row.
#'   One of `"left"` (default), `"center"`, or `"right"`.
#'
#' @return Modified rtf_document with appended contents.
#'
#' @examples
#' \dontrun{
#' df1 <- data.frame(A = 1:3, B = c("x", "y", "z"))
#' df2 <- data.frame(A = 4:6, B = c("p", "q", "r"))
#'
#' # Three pages, shared formatting applied to both bare data.frames
#' doc <- rtf_document() %>%
#'   rtf_tables(
#'     list(df1, df2, rtfplot("fig.png")),
#'     col_rel_width    = c(1, 2),
#'     border           = "tfl",
#'     row_height_twips = 280L
#'   )
#' }
#'
#' @export
rtf_tables <- function(doc, tables,
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
                        titles = NULL,
                        footnotes = NULL,
                        auto_section = FALSE,
                        section_label_align = "left") {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }

  if (!is.list(tables)) {
    stop("`tables` must be a list", call. = FALSE)
  }

  .is_content_item <- function(x) {
    is.data.frame(x) ||
      inherits(x, "rtftable") ||
      inherits(x, "rtfplot")
  }

  # Validate each page-level item: exactly one content per page.
  for (i in seq_along(tables)) {
    item <- tables[[i]]
    if (!.is_content_item(item)) {
      stop("Item ", i,
           " must be a data.frame, rtftable(), or rtfplot() object. ",
           "Each list element corresponds to exactly one page (one content).",
           call. = FALSE)
    }
  }

  # Promote bare data.frames to rtftable using the supplied formatting args.
  tables <- lapply(tables, function(item) {
    if (is.data.frame(item)) {
      .new_rtftable(
        data                        = item,
        col_header                  = col_header,
        col_header_align            = col_header_align,
        spanning_header             = spanning_header,
        col_spec                    = col_spec,
        border                      = border,
        blank_rows                  = blank_rows,
        read_attributes             = read_attributes,
        style                       = style,
        col_rel_width               = col_rel_width,
        column_widths_twips         = column_widths_twips,
        table_width_twips           = table_width_twips,
        table_width_pct_of_writable = table_width_pct_of_writable,
        table_width_pct             = table_width_pct,
        table_align                 = table_align,
        row_height_twips            = row_height_twips,
        row_height_exact            = row_height_exact,
        header_row_height_twips     = header_row_height_twips,
        blank_row_height_twips      = blank_row_height_twips,
        cell_padding_left_twips     = cell_padding_left_twips,
        cell_padding_right_twips    = cell_padding_right_twips,
        cell_valign                 = cell_valign
      )
    } else {
      item
    }
  })

  # When auto_section = TRUE, wrap each named item in an rtf_auto_section_item
  # sentinel so that .pipe_doc_to_r6_report() can build per-section headers.
  if (isTRUE(auto_section)) {
    tbl_names <- names(tables)
    if (!is.null(tbl_names) && any(nzchar(tbl_names))) {
      tables <- lapply(seq_along(tables), function(i) {
        nm <- tbl_names[[i]]
        if (!is.null(nm) && nzchar(nm)) {
          structure(
            list(content = tables[[i]], label = nm,
                 label_align = section_label_align),
            class = "rtf_auto_section_item"
          )
        } else {
          tables[[i]]
        }
      })
    }
  }

  # Validate titles / footnotes lengths
  .validate_parallel <- function(x, n, name) {
    if (is.null(x)) return(rep(list(NULL), n))
    if (!is.list(x)) {
      stop(sprintf("`%s` must be a list (or NULL).", name), call. = FALSE)
    }
    if (length(x) != n) {
      stop(sprintf("`%s` must have length %d (= length(tables)).",
                   name, n), call. = FALSE)
    }
    x
  }
  titles    <- .validate_parallel(titles,    length(tables), "titles")
  footnotes <- .validate_parallel(footnotes, length(tables), "footnotes")

  # Create copy and append
  doc_copy <- doc
  doc_copy$contents  <- c(doc_copy$contents,  tables)
  doc_copy$titles    <- c(doc_copy$titles,    titles)
  doc_copy$footnotes <- c(doc_copy$footnotes, footnotes)
  doc_copy
}

#' Add figure content to document
#'
#' Append one or more image files (PNG/JPEG) as content pages. Each figure
#' creates one new page. Display dimensions and alignment apply to every
#' bare path in `figures`; elements already constructed via [rtfplot()] keep
#' their own settings.
#'
#' @param doc An rtf_document object.
#' @param figures A list whose elements are either character file paths to
#'   image files (PNG/JPEG) or pre-built `rtfplot` objects from [rtfplot()].
#' @param width_twips Display width in twips for bare paths.  `NULL` = full
#'   writable width.
#' @param height_twips Display height in twips for bare paths.  `NULL` =
#'   derived from the image's aspect ratio.
#' @param align Horizontal alignment for bare paths: `"center"` (default),
#'   `"left"`, or `"right"`.
#' @param titles,footnotes Optional lists of length `length(figures)`. See
#'   [rtf_tables()] for the same semantics -- character vectors per page,
#'   magic tokens supported.
#'
#' @return Modified rtf_document with appended figure contents.
#'
#' @export
rtf_figures <- function(doc, figures,
                         width_twips = NULL, height_twips = NULL,
                         align = "center",
                         titles = NULL, footnotes = NULL) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }

  if (!is.list(figures)) {
    stop("`figures` must be a list of file paths or rtfplot() objects",
         call. = FALSE)
  }

  # Validate and promote each element to rtfplot.
  fig_objs <- lapply(seq_along(figures), function(i) {
    fig <- figures[[i]]
    if (inherits(fig, "rtfplot")) {
      return(fig)
    }
    if (!is.character(fig) || length(fig) != 1L) {
      stop("Item ", i,
           " must be a single character file path or an rtfplot() object",
           call. = FALSE)
    }
    .new_rtfplot(path = fig, width_twips = width_twips,
                 height_twips = height_twips, align = align)
  })

  .validate_parallel <- function(x, n, name) {
    if (is.null(x)) return(rep(list(NULL), n))
    if (!is.list(x))
      stop(sprintf("`%s` must be a list (or NULL).", name), call. = FALSE)
    if (length(x) != n)
      stop(sprintf("`%s` must have length %d (= length(figures)).",
                   name, n), call. = FALSE)
    x
  }
  titles    <- .validate_parallel(titles,    length(figures), "titles")
  footnotes <- .validate_parallel(footnotes, length(figures), "footnotes")

  doc_copy <- doc
  doc_copy$contents  <- c(doc_copy$contents,  fig_objs)
  doc_copy$titles    <- c(doc_copy$titles,    titles)
  doc_copy$footnotes <- c(doc_copy$footnotes, footnotes)
  doc_copy
}

# ============================================================================
# rtf_titles() / rtf_footnotes() -- assign titles / footnotes to pages
# ============================================================================

#' Assign content titles to pages
#'
#' Replace the per-page title list with the supplied values.  The length of
#' `titles` must equal the number of pages already added via [rtf_tables()]
#' / [rtf_figures()].
#'
#' Each element is a character vector -- one element per row of the title
#' block.  Magic tokens \code{"\{HALF_BLANK_ROW\}"} (half-height blank
#' row) and \code{"\{BLANK_ROW\}"} (full-height blank row, equivalent
#' to `""`) are honoured.
#' Pass `NULL` for a single element to fall back to the default of one
#' \code{\{HALF_BLANK_ROW\}} row above the content.
#'
#' @param doc An rtf_document object.
#' @param titles A list of length equal to the number of pages.
#'
#' @return Modified rtf_document.
#'
#' @examples
#' \dontrun{
#' doc <- rtf_document() %>%
#'   rtf_tables(list(df1, df2)) %>%
#'   rtf_titles(list(
#'     c("Table 14.1.1", "{HALF_BLANK_ROW}", "Safety Population"),
#'     "Table 14.1.2"
#'   ))
#' }
#'
#' @export
rtf_titles <- function(doc, titles) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }
  n <- length(doc$contents)
  if (n == 0L) {
    stop("Cannot set titles before any content has been added.", call. = FALSE)
  }
  if (!is.list(titles)) {
    stop("`titles` must be a list (one element per page).", call. = FALSE)
  }
  if (length(titles) != n) {
    stop(sprintf("`titles` must have length %d (= number of pages).", n),
         call. = FALSE)
  }
  doc_copy <- doc
  doc_copy$titles <- titles
  doc_copy
}

#' Assign content footnotes to pages
#'
#' Same shape as [rtf_titles()]: a list with one element per page, each a
#' character vector whose entries become rows of the footnote block.  Magic
#' tokens are honoured.  `NULL` per element suppresses the footnote for
#' that page.
#'
#' @param doc An rtf_document object.
#' @param footnotes A list of length equal to the number of pages.
#'
#' @return Modified rtf_document.
#'
#' @export
rtf_footnotes <- function(doc, footnotes) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }
  n <- length(doc$contents)
  if (n == 0L) {
    stop("Cannot set footnotes before any content has been added.", call. = FALSE)
  }
  if (!is.list(footnotes)) {
    stop("`footnotes` must be a list (one element per page).", call. = FALSE)
  }
  if (length(footnotes) != n) {
    stop(sprintf("`footnotes` must have length %d (= number of pages).", n),
         call. = FALSE)
  }
  doc_copy <- doc
  doc_copy$footnotes <- footnotes
  doc_copy
}

# ============================================================================
# Section Definition: rtf_section()
# ============================================================================

#' Define sections for pages
#'
#' Map page numbers to sections with headers/footers.
#' Pages are automatically numbered based on content order (starting at 1).
#'
#' @param doc An rtf_document object.
#' @param page Integer or vector of page numbers to assign this section.
#'   - Single integer: one section starts at this page
#'   - Vector: assign multiple pages to sections (length must match secinfo)
#' @param secinfo Section information (one or more section definitions):
#'   - Single section: list(header = ..., footer = ...)
#'   - Multiple sections: list(sec1, sec2, ...) where each is a section list
#'
#' @return Modified rtf_document with section definitions added.
#'
#' @details
#' The `page` parameter identifies where each section starts. Pages are
#' auto-numbered from your content list (rtf_tables and rtf_figures).
#'
#' @examples
#' \dontrun{
#' doc <- rtf_document() %>%
#'   rtf_tables(list(df1, df2, df3)) %>%
#'   rtf_section(page = 1, secinfo = list(header = h1, footer = f1)) %>%
#'   rtf_section(page = 3, secinfo = list(header = h2, footer = f2))
#' }
#'
#' @export
rtf_section <- function(doc, page = NULL, secinfo) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }

  # Handle page = NULL: store as "_default" template used by auto_section.
  if (is.null(page)) {
    doc_copy <- doc
    doc_copy$sections[["_default"]] <- secinfo
    return(doc_copy)
  }

  # Normalize page to character for list indexing
  page <- as.character(page)

  # Create copy
  doc_copy <- doc

  # Handle single vs. multiple sections
  if (length(page) == 1) {
    # Single section
    if (is.list(secinfo) && !is.null(secinfo$header) || !is.null(secinfo$footer)) {
      # secinfo is a single section
      doc_copy$sections[[page]] <- secinfo
    } else if (is.list(secinfo) && length(secinfo) > 0 &&
               (is.list(secinfo[[1]]) || is.null(secinfo[[1]]))) {
      # secinfo might be a wrapped section or empty list
      doc_copy$sections[[page]] <- secinfo
    } else {
      stop("secinfo must be a list with header/footer fields", call. = FALSE)
    }
  } else {
    # Multiple pages, possibly multiple sections
    if (!is.list(secinfo)) {
      stop("When page is a vector, secinfo must be a list of section objects",
           call. = FALSE)
    }

    # Check if secinfo is a list of sections or a single section
    # If first element is a list (looks like a section), assume list of sections
    if (length(page) > 1 && length(secinfo) > 0) {
      if (is.list(secinfo[[1]]) || is.null(secinfo[[1]])) {
        # Likely list of section objects
        if (length(page) != length(secinfo)) {
          stop("Length of page (", length(page), ") must match length of secinfo (",
               length(secinfo), ")", call. = FALSE)
        }

        for (i in seq_along(page)) {
          doc_copy$sections[[page[i]]] <- secinfo[[i]]
        }
      } else {
        # Single section dict applied to all pages
        for (p in page) {
          doc_copy$sections[[p]] <- secinfo
        }
      }
    }
  }

  doc_copy
}

# ============================================================================
# Format Functions (DEPRECATED)
# ============================================================================
#
# These four functions never actually applied formatting to the rendered RTF
# output -- they only stored values in unused slots of the rtf_document object.
# They are retained as no-ops with a deprecation warning so that existing
# scripts continue to run, and will be removed in a future release.
#
# Replacement: pass the formatting arguments (col_rel_width, border,
# row_height_twips, ...) directly to `rtf_tables()`, or build each item with
# `rtftable()` / `rtfplot()`.

#' Deprecated formatting functions
#'
#' `rtf_table_format()`, `rtf_header_format()`, `rtf_footer_format()`, and
#' `rtf_figure_format()` are **deprecated** and have no effect on the rendered
#' output. They will be removed in a future release.
#'
#' Use the formatting arguments of [rtf_tables()] (for tables and bare
#' data.frames) and [rtf_figures()] (for figures) instead, or build each item
#' explicitly with [rtftable()] / [rtfplot()] and pass it to `rtf_tables()`.
#'
#' @param doc An rtf_document object.
#' @param ... Ignored.
#'
#' @return `doc`, unchanged.
#' @name rtf_format-deprecated
#' @keywords internal
NULL

#' @rdname rtf_format-deprecated
#' @export
rtf_table_format <- function(doc, ...) {
  .Deprecated(
    new = "rtf_tables",
    msg = paste(
      "rtf_table_format() is deprecated and has no effect.",
      "Pass formatting arguments directly to rtf_tables() instead."
    )
  )
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }
  doc
}

#' @rdname rtf_format-deprecated
#' @export
rtf_header_format <- function(doc, ...) {
  .Deprecated(
    new = "rtf_header",
    msg = paste(
      "rtf_header_format() is deprecated and has no effect.",
      "Configure header rows via rtf_header() / rtf_section() instead."
    )
  )
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }
  doc
}

#' @rdname rtf_format-deprecated
#' @export
rtf_footer_format <- function(doc, ...) {
  .Deprecated(
    new = "rtf_footer",
    msg = paste(
      "rtf_footer_format() is deprecated and has no effect.",
      "Configure footer rows via rtf_footer() / rtf_section() instead."
    )
  )
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }
  doc
}

#' @rdname rtf_format-deprecated
#' @export
rtf_figure_format <- function(doc, ...) {
  .Deprecated(
    new = "rtf_figures",
    msg = paste(
      "rtf_figure_format() is deprecated and has no effect.",
      "Pass width_twips / height_twips / align to rtf_figures() or rtfplot() instead."
    )
  )
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }
  doc
}

# ============================================================================
# S3 Methods for printing
# ============================================================================

#' Print an rtf_document object
#'
#' @param x An rtf_document object.
#' @param ... Additional arguments (unused).
#'
#' @export
print.rtf_document <- function(x, ...) {
  cat("rtf_document object\n")
  cat("  Pages:", length(x$contents), "\n")
  cat("  Sections defined:", length(x$sections), "\n")
  cat("  Document page size:", x$document$page$width_in, "x",
      x$document$page$height_in, "inches\n")
  invisible(x)
}
