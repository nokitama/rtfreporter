# Pipe Composition API for rtfreporter
# S3-based immutable composition interface for building RTF reports with pipes (%>%)
#
# This module provides an alternative to the S3 methods API (add_section, add_page, etc.)
# with a focus on functional composition and pipeline building.

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
#'             Default: landscape letter 11x8.5", margins 0.75/0.5"
#' @param default_format Optional document-wide default formatting.
#'
#' @return An rtf_document object (S3 class) with structure:
#'   - document: list(font_table, color_table, page, default_format)
#'   - contents: list (initially empty, populated by rtf_tables/rtf_figures)
#'   - sections: list (initially empty, populated by rtf_section)
#'   - table_formats: list (initially empty, populated by rtf_table_format)
#'   - header_formats: list (initially empty, populated by rtf_header_format)
#'   - footer_formats: list (initially empty, populated by rtf_footer_format)
#'   - figure_formats: list (initially empty, populated by rtf_figure_format)
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
      margin_top_in = 0.75,
      margin_bottom_in = 0.75,
      margin_left_in = 0.5,
      margin_right_in = 0.5
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
      contents = list(),
      sections = list(),
      table_formats = list(),
      header_formats = list(),
      footer_formats = list(),
      figure_formats = list()
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

#' Add table content to document
#'
#' Append one or more data.frames as content pages.
#' Automatically numbers pages based on content order.
#'
#' @param doc An rtf_document object.
#' @param tables A list of content items:
#'   - data.frame: treated as a single table on one page
#'   - list of data.frames: multiple tables on one page
#'   Example: list(df1, df2, list(df3a, df3b)) creates 3 pages
#'
#' @return Modified rtf_document with appended contents.
#'
#' @export
rtf_tables <- function(doc, tables) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }

  if (!is.list(tables)) {
    stop("`tables` must be a list", call. = FALSE)
  }

  # Validate each item
  for (i in seq_along(tables)) {
    item <- tables[[i]]

    # Check if it's a single data.frame
    if (is.data.frame(item)) {
      # OK - single table
      next
    }

    # Check if it's a list of data.frames
    if (is.list(item)) {
      if (length(item) > 0) {
        # Check all items in list are data.frames
        if (!all(sapply(item, is.data.frame))) {
          stop("Item ", i, " in tables must contain only data.frames",
               call. = FALSE)
        }
      }
      # OK - list of tables (possibly empty)
      next
    }

    # If we get here, it's invalid
    stop("Item ", i, " in tables must be a data.frame or list of data.frames",
         call. = FALSE)
  }

  # Create copy and append
  doc_copy <- doc
  doc_copy$contents <- c(doc_copy$contents, tables)
  doc_copy
}

#' Add figure content to document
#'
#' Append one or more image files as content pages.
#' Each figure creates one new page.
#'
#' @param doc An rtf_document object.
#' @param figures A list of file paths (character) to image files.
#'
#' @return Modified rtf_document with appended figure contents.
#'
#' @export
rtf_figures <- function(doc, figures) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }

  if (!is.list(figures)) {
    stop("`figures` must be a list of file paths", call. = FALSE)
  }

  # Validate each path
  for (i in seq_along(figures)) {
    fig <- figures[[i]]
    if (!is.character(fig) || length(fig) != 1) {
      stop("Item ", i, " must be a single character file path", call. = FALSE)
    }
    if (!file.exists(fig)) {
      stop("File not found: ", fig, call. = FALSE)
    }
  }

  # Wrap each in list (each figure = one page)
  wrapped_figures <- lapply(figures, function(x) list(x))

  # Create copy and append
  doc_copy <- doc
  doc_copy$contents <- c(doc_copy$contents, wrapped_figures)
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
rtf_section <- function(doc, page, secinfo) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
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
# Format Functions
# ============================================================================

#' Format table content across pages
#'
#' Apply formatting specifications to table content on specified pages.
#' Multiple calls accumulate format specifications; NULL parameters don't
#' override previous settings.
#'
#' @param doc An rtf_document object.
#' @param pages Page selector: "all" for all pages, or integer/vector c(1, 3, 5).
#' @param border Optional border style (e.g., "tfl", "none").
#' @param row_height_twips Optional row height in twips.
#' @param cell_padding_left Optional left cell padding in twips.
#' @param cell_padding_right Optional right cell padding in twips.
#' @param ... Additional format parameters.
#'
#' @return Modified rtf_document with format specifications.
#'
#' @export
rtf_table_format <- function(doc, pages, border = NULL, row_height_twips = NULL,
                             cell_padding_left = NULL, cell_padding_right = NULL, ...) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }

  # Collect parameters
  params <- list(
    border = border,
    row_height_twips = row_height_twips,
    cell_padding_left = cell_padding_left,
    cell_padding_right = cell_padding_right,
    ...
  )

  .apply_format(doc, pages, "table_formats", params)
}

#' Format table headers across pages
#'
#' Apply formatting to table header rows.
#'
#' @param doc An rtf_document object.
#' @param pages Page selector: "all" or c(1, 3, 5).
#' @param border Optional border style.
#' @param row_height_twips Optional row height in twips.
#' @param ... Additional format parameters.
#'
#' @return Modified rtf_document.
#'
#' @export
rtf_header_format <- function(doc, pages, border = NULL, row_height_twips = NULL, ...) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }

  params <- list(
    border = border,
    row_height_twips = row_height_twips,
    ...
  )

  .apply_format(doc, pages, "header_formats", params)
}

#' Format table footers across pages
#'
#' Apply formatting to table footer rows.
#'
#' @param doc An rtf_document object.
#' @param pages Page selector: "all" or c(1, 3, 5).
#' @param border Optional border style.
#' @param row_height_twips Optional row height in twips.
#' @param ... Additional format parameters.
#'
#' @return Modified rtf_document.
#'
#' @export
rtf_footer_format <- function(doc, pages, border = NULL, row_height_twips = NULL, ...) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }

  params <- list(
    border = border,
    row_height_twips = row_height_twips,
    ...
  )

  .apply_format(doc, pages, "footer_formats", params)
}

#' Format figures across pages
#'
#' Apply formatting to figure content.
#'
#' @param doc An rtf_document object.
#' @param pages Page selector: "all" or c(1, 3, 5).
#' @param width_twips Optional figure width in twips.
#' @param height_twips Optional figure height in twips.
#' @param ... Additional format parameters.
#'
#' @return Modified rtf_document.
#'
#' @export
rtf_figure_format <- function(doc, pages, width_twips = NULL, height_twips = NULL, ...) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }

  params <- list(
    width_twips = width_twips,
    height_twips = height_twips,
    ...
  )

  .apply_format(doc, pages, "figure_formats", params)
}

# ============================================================================
# Internal Helper: .apply_format()
# ============================================================================

#' Apply format specifications safely
#'
#' Internal helper to merge format specifications. Handles:
#' - pages = "all" for all pages
#' - pages = c(1, 3, 5) for specific pages
#' - NULL parameters (not included in merge)
#' - Overwrites via utils::modifyList()
#'
#' @param doc An rtf_document object.
#' @param pages "all" or character/integer vector of page numbers.
#' @param format_key Name of the format list in doc (e.g., "table_formats").
#' @param params List of format parameters (NULL values are filtered out).
#'
#' @return Modified doc with format specs merged.
#'
#' @keywords internal
.apply_format <- function(doc, pages, format_key, params) {
  # Normalize pages
  if (is.character(pages) && length(pages) == 1 && pages == "all") {
    pages <- "all"
  } else {
    pages <- as.character(pages)
  }

  # Filter out NULL parameters
  config <- Filter(function(x) !is.null(x), params)

  # If nothing to apply, return early
  if (length(config) == 0) {
    return(doc)
  }

  # Create copy
  doc_copy <- doc

  # Apply format specs
  if (identical(pages, "all")) {
    # Merge with "all" key
    existing <- doc_copy[[format_key]][["all"]] %||% list()
    doc_copy[[format_key]][["all"]] <- utils::modifyList(existing, config)
  } else {
    # Merge with each specified page key
    for (p in pages) {
      existing <- doc_copy[[format_key]][[p]] %||% list()
      doc_copy[[format_key]][[p]] <- utils::modifyList(existing, config)
    }
  }

  doc_copy
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
