# S3 Methods for rtfreport objects
# These are the public API for manipulating rtfreport instances.
# Implementation delegates to internal R6 methods on rtfreport_r6 objects.

# ============================================================================
# Section Management
# ============================================================================

#' Add a section to a report
#'
#' S3 method to add a new section to an rtfreport object.
#'
#' @param report An rtfreport object.
#' @param header Optional header (from \code{rtf_header()}).
#' @param footer Optional footer (from \code{rtf_footer()}).
#'
#' @return Invisibly returns the section index (integer).
#'
#' @export
add_section <- function(report, header = NULL, footer = NULL) {
  UseMethod("add_section")
}

#' @export
add_section.rtfreport_r6 <- function(report, header = NULL, footer = NULL) {
  report$add_section(header = header, footer = footer)
}

#' Get a section from a report
#'
#' @param report An rtfreport object.
#' @param section_index Integer index of the section.
#'
#' @return A section list (header, footer, pages).
#'
#' @export
get_section <- function(report, section_index) {
  UseMethod("get_section")
}

#' @export
get_section.rtfreport_r6 <- function(report, section_index) {
  report$get_section(section_index)
}

#' Get section header
#'
#' @param report An rtfreport object.
#' @param section_index Integer index of the section.
#'
#' @return The section's header (from \code{rtf_header()}) or NULL.
#'
#' @export
get_section_header <- function(report, section_index) {
  UseMethod("get_section_header")
}

#' @export
get_section_header.rtfreport_r6 <- function(report, section_index) {
  report$get_section_header(section_index)
}

#' Get section footer
#'
#' @param report An rtfreport object.
#' @param section_index Integer index of the section.
#'
#' @return The section's footer (from \code{rtf_footer()}) or NULL.
#'
#' @export
get_section_footer <- function(report, section_index) {
  UseMethod("get_section_footer")
}

#' @export
get_section_footer.rtfreport_r6 <- function(report, section_index) {
  report$get_section_footer(section_index)
}

#' Set section header
#'
#' @param report An rtfreport object.
#' @param section_index Integer index of the section.
#' @param header New header (from \code{rtf_header()}).
#'
#' @return Invisibly returns the report (for chaining).
#'
#' @export
set_section_header <- function(report, section_index, header) {
  UseMethod("set_section_header")
}

#' @export
set_section_header.rtfreport_r6 <- function(report, section_index, header) {
  report$set_section_header(section_index, header)
  invisible(report)
}

#' Set section footer
#'
#' @param report An rtfreport object.
#' @param section_index Integer index of the section.
#' @param footer New footer (from \code{rtf_footer()}).
#'
#' @return Invisibly returns the report (for chaining).
#'
#' @export
set_section_footer <- function(report, section_index, footer) {
  UseMethod("set_section_footer")
}

#' @export
set_section_footer.rtfreport_r6 <- function(report, section_index, footer) {
  report$set_section_footer(section_index, footer)
  invisible(report)
}

# ============================================================================
# Page Management
# ============================================================================

#' Add a page to a section
#'
#' S3 method to add a page to a section within an rtfreport.
#'
#' @param report An rtfreport object.
#' @param section_index Integer index of the target section.
#' @param title Optional title (character or character vector for multi-line).
#' @param content List of content blocks (rtftable, rtfplot, data.frame, or file paths).
#'                Content type is auto-detected.
#' @param footer_notes Optional footer notes (character or character vector for multi-line).
#' @param page_options Optional page-level options list.
#'
#' @return Invisibly returns the report (for chaining).
#'
#' @export
add_page <- function(report, section_index, title = NULL, content = list(),
                     footer_notes = NULL, page_options = NULL) {
  UseMethod("add_page")
}

#' @export
add_page.rtfreport_r6 <- function(report, section_index, title = NULL,
                                   content = list(), footer_notes = NULL,
                                   page_options = NULL) {
  report$add_page(section_index = section_index, title = title,
                  content = content, footer_notes = footer_notes,
                  page_options = page_options)
  invisible(report)
}

#' Get a page from a section
#'
#' @param report An rtfreport object.
#' @param section_index Integer index of the section.
#' @param page_index Integer index of the page within the section.
#'
#' @return A page list (title, content, footer_notes, page_options).
#'
#' @export
get_page <- function(report, section_index, page_index) {
  UseMethod("get_page")
}

#' @export
get_page.rtfreport_r6 <- function(report, section_index, page_index) {
  report$get_page(section_index, page_index)
}

#' Set page title
#'
#' @param report An rtfreport object.
#' @param section_index Integer index of the section.
#' @param page_index Integer index of the page within the section.
#' @param title New title (character or character vector for multi-line).
#'
#' @return Invisibly returns the report (for chaining).
#'
#' @export
set_page_title <- function(report, section_index, page_index, title) {
  UseMethod("set_page_title")
}

#' @export
set_page_title.rtfreport_r6 <- function(report, section_index, page_index, title) {
  report$set_page_title(section_index, page_index, title)
  invisible(report)
}

#' Set page footer notes
#'
#' @param report An rtfreport object.
#' @param section_index Integer index of the section.
#' @param page_index Integer index of the page within the section.
#' @param footer_notes New footer notes (character or character vector for multi-line).
#'
#' @return Invisibly returns the report (for chaining).
#'
#' @export
set_page_footer_notes <- function(report, section_index, page_index, footer_notes) {
  UseMethod("set_page_footer_notes")
}

#' @export
set_page_footer_notes.rtfreport_r6 <- function(report, section_index, page_index,
                                               footer_notes) {
  report$set_page_footer_notes(section_index, page_index, footer_notes)
  invisible(report)
}

#' Set page options
#'
#' @param report An rtfreport object.
#' @param section_index Integer index of the section.
#' @param page_index Integer index of the page within the section.
#' @param page_options New page options list.
#'
#' @return Invisibly returns the report (for chaining).
#'
#' @export
set_page_options <- function(report, section_index, page_index, page_options) {
  UseMethod("set_page_options")
}

#' @export
set_page_options.rtfreport_r6 <- function(report, section_index, page_index,
                                          page_options) {
  report$set_page_options(section_index, page_index, page_options)
  invisible(report)
}

# ============================================================================
# Content Block Management
# ============================================================================

#' Add a content block to a page
#'
#' S3 method to add a block (table, figure, listing) to a page.
#'
#' @param report An rtfreport object.
#' @param section_index Integer index of the section.
#' @param page_index Integer index of the page.
#' @param block Content block (rtftable, rtfplot, data.frame, file path, or explicit list).
#'
#' @return Invisibly returns the report (for chaining).
#'
#' @export
add_block <- function(report, section_index, page_index, block) {
  UseMethod("add_block")
}

#' @export
add_block.rtfreport_r6 <- function(report, section_index, page_index, block) {
  report$add_block(section_index, page_index, block)
  invisible(report)
}

#' Add a table block to a page
#'
#' @param report An rtfreport object.
#' @param section_index Integer index of the section.
#' @param page_index Integer index of the page.
#' @param data A data.frame or rtftable object.
#' @param footer Optional footer text for the block.
#' @param metadata Optional block-level metadata.
#'
#' @return Invisibly returns the report (for chaining).
#'
#' @export
add_table <- function(report, section_index, page_index, data, footer = NULL,
                      metadata = NULL) {
  UseMethod("add_table")
}

#' @export
add_table.rtfreport_r6 <- function(report, section_index, page_index, data,
                                   footer = NULL, metadata = NULL) {
  report$add_table(section_index, page_index, data, footer, metadata)
  invisible(report)
}

#' Add a listing block to a page
#'
#' @param report An rtfreport object.
#' @param section_index Integer index of the section.
#' @param page_index Integer index of the page.
#' @param data A data.frame.
#' @param footer Optional footer text for the block.
#' @param metadata Optional block-level metadata.
#'
#' @return Invisibly returns the report (for chaining).
#'
#' @export
add_listing <- function(report, section_index, page_index, data, footer = NULL,
                        metadata = NULL) {
  UseMethod("add_listing")
}

#' @export
add_listing.rtfreport_r6 <- function(report, section_index, page_index, data,
                                     footer = NULL, metadata = NULL) {
  report$add_listing(section_index, page_index, data, footer, metadata)
  invisible(report)
}

#' Add a figure block to a page
#'
#' @param report An rtfreport object.
#' @param section_index Integer index of the section.
#' @param page_index Integer index of the page.
#' @param path Path to image file, or rtfplot object.
#' @param footer Optional footer text for the block.
#' @param metadata Optional block-level metadata.
#'
#' @return Invisibly returns the report (for chaining).
#'
#' @export
add_figure <- function(report, section_index, page_index, path, footer = NULL,
                       metadata = NULL) {
  UseMethod("add_figure")
}

#' @export
add_figure.rtfreport_r6 <- function(report, section_index, page_index, path,
                                    footer = NULL, metadata = NULL) {
  report$add_figure(section_index, page_index, path, footer, metadata)
  invisible(report)
}

# ============================================================================
# Bulk Operations
# ============================================================================

#' Add a section from a list of data.frames
#'
#' @param report An rtfreport object.
#' @param data_list List of data.frames to add as pages.
#' @param section_header Optional section header.
#' @param section_footer Optional section footer.
#' @param page_titles Optional character vector of page titles (length 1 or same as data_list).
#' @param block_type Block type: `"table"` (default) or `"listing"`.
#' @param page_footer_notes Optional footer notes for pages.
#' @param metadata Optional metadata.
#'
#' @return Invisibly returns the report (for chaining).
#'
#' @export
add_section_from_dataframes <- function(report, data_list, section_header = NULL,
                                        section_footer = NULL, page_titles = NULL,
                                        block_type = "table", page_footer_notes = NULL,
                                        metadata = NULL) {
  UseMethod("add_section_from_dataframes")
}

#' @export
add_section_from_dataframes.rtfreport_r6 <- function(report, data_list,
                                                      section_header = NULL,
                                                      section_footer = NULL,
                                                      page_titles = NULL,
                                                      block_type = "table",
                                                      page_footer_notes = NULL,
                                                      metadata = NULL) {
  report$add_section_from_dataframes(
    data_list = data_list,
    section_header = section_header,
    section_footer = section_footer,
    page_titles = page_titles,
    block_type = block_type,
    page_footer_notes = page_footer_notes,
    metadata = metadata
  )
  invisible(report)
}

# ============================================================================
# Validation
# ============================================================================

#' Validate report structure
#'
#' Check that the report structure is valid before rendering.
#'
#' @param report An rtfreport object.
#'
#' @return Invisibly returns the report.
#'
#' @export
validate_report <- function(report) {
  UseMethod("validate_report")
}

#' @export
validate_report.rtfreport_r6 <- function(report) {
  report$validate()
  invisible(report)
}
