# S3 wrapper functions for public API
# These are thin shells that call the internal R6 class constructors.

#' Create an RTF report object
#'
#' Wrapper function for the internal `rtfreport_r6` R6 class.
#'
#' @param font_table Optional font table list.
#' @param color_table Optional color table.
#' @param default_page Optional default page settings.
#' @param default_format Optional default format settings.
#'
#' @return An `rtfreport_r6` R6 object (mutably modified via methods).
#'
#' @examples
#' \dontrun{
#'   report <- rtfreport()
#'   sec <- report$add_section()
#' }
#'
#' @export
rtfreport <- function(font_table = NULL, color_table = NULL,
                      default_page = NULL, default_format = NULL) {
  rtfreport_r6$new(
    font_table = font_table,
    color_table = color_table,
    default_page = default_page,
    default_format = default_format
  )
}

#' Create an RTF table object
#'
#' Wrapper function for the internal `rtftable_r6` R6 class.
#'
#' @param data A `data.frame`, or a list of `data.frame`s with identical column count.
#' @param col_header Optional column header specification.
#' @param spanning_header Optional spanning header specification.
#' @param col_spec Optional per-column formatting specification.
#' @param border Border specification. Defaults to `"tfl"` (Clinical TFL standard).
#' @param blank_rows Optional vector of positions to insert blank rows.
#' @param col_rel_width Optional numeric vector of relative column widths.
#' @param column_widths_twips Optional integer vector of absolute column widths in twips.
#' @param table_width_twips Optional total table width in twips.
#' @param table_width_pct_of_writable Optional table width as fraction of writable page width (0–1).
#' @param table_width_pct Optional table width as percentage of writable page width (0–100).
#' @param table_align Horizontal placement: `"left"` (default), `"center"`, or `"right"`.
#' @param row_height_twips Row height for data rows in twips. Default `0` = automatic.
#' @param row_height_exact Logical. If `TRUE`, row height is exact (clipped); if `FALSE`, it is a minimum.
#' @param header_row_height_twips Optional row height for header rows.
#' @param blank_row_height_twips Optional row height for blank separator rows.
#' @param cell_padding_left_twips Left cell padding in twips.
#' @param cell_padding_right_twips Right cell padding in twips.
#' @param cell_valign Vertical cell alignment: `"bottom"` (default), `"top"`, or `"center"`.
#'
#' @return An `rtftable_r6` R6 object.
#'
#' @export
rtftable <- function(data, col_header = NULL, spanning_header = NULL,
                     col_spec = NULL, border = "tfl", blank_rows = NULL,
                     col_rel_width = NULL, column_widths_twips = NULL,
                     table_width_twips = NULL, table_width_pct_of_writable = NULL,
                     table_width_pct = NULL, table_align = "left",
                     row_height_twips = 0L, row_height_exact = FALSE,
                     header_row_height_twips = NULL, blank_row_height_twips = NULL,
                     cell_padding_left_twips = 72L, cell_padding_right_twips = 72L,
                     cell_valign = "bottom") {
  rtftable_r6$new(
    data = data,
    col_header = col_header,
    spanning_header = spanning_header,
    col_spec = col_spec,
    border = border,
    blank_rows = blank_rows,
    col_rel_width = col_rel_width,
    column_widths_twips = column_widths_twips,
    table_width_twips = table_width_twips,
    table_width_pct_of_writable = table_width_pct_of_writable,
    table_width_pct = table_width_pct,
    table_align = table_align,
    row_height_twips = row_height_twips,
    row_height_exact = row_height_exact,
    header_row_height_twips = header_row_height_twips,
    blank_row_height_twips = blank_row_height_twips,
    cell_padding_left_twips = cell_padding_left_twips,
    cell_padding_right_twips = cell_padding_right_twips,
    cell_valign = cell_valign
  )
}

#' Create an RTF figure (image) object
#'
#' Wrapper function for the internal `rtfplot_r6` R6 class.
#'
#' @param path Path to a PNG or JPEG image file.
#' @param width_twips Optional display width in twips. If `NULL`, width is computed from image aspect ratio.
#' @param height_twips Optional display height in twips. If `NULL`, height is computed from aspect ratio.
#' @param align Horizontal alignment: `"center"` (default), `"left"`, or `"right"`.
#'
#' @return An `rtfplot_r6` R6 object.
#'
#' @export
rtfplot <- function(path, width_twips = NULL, height_twips = NULL,
                    align = "center") {
  rtfplot_r6$new(
    path = path,
    width_twips = width_twips,
    height_twips = height_twips,
    align = align
  )
}
