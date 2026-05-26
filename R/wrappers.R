# Constructor wrappers for rtftable and rtfplot
# These are thin shells over the internal R6 classes, providing a clean
# public API with full parameter documentation.

#' Create an RTF table object
#'
#' Constructs a table object with full formatting control.
#' The result can be passed directly to `rtf_tables()` in a pipe chain.
#'
#' @param data A `data.frame`, or a `list` of `data.frame`s (multi-DF mode).
#'   Multi-DF mode renders each data.frame with its own column headers but
#'   shares column widths and border settings.
#' @param col_header Column header specification.
#'   - `NULL`: use column names of `data`.
#'   - Character vector: one label per column (single header row).
#'   - List of character vectors: multiple header rows.
#'   - In multi-DF mode: a `list` of per-DF specs (same length as `data`).
#' @param spanning_header List of spanning-header groups. Each element is a
#'   `list(from, to, label, underline)` where `from`/`to` are 1-based column
#'   indices.
#' @param col_spec List of per-column formatting specs. Each element may
#'   contain: `col` (integer), `align` (`"left"`/`"center"`/`"right"`),
#'   `bold`, `italic`, `underline` (logical), `indent_twips` (integer),
#'   `header_align`, `header_bold`, `header_italic`.
#' @param border Border specification.
#'   - `"tfl"`: clinical TFL preset (header top+bottom, last-row bottom).
#'   - `"none"`: no borders.
#'   - An `rtf_table_border` object from `rtf_table_border()`.
#' @param blank_rows Integer vector of row positions after which a blank
#'   separator row is inserted. Use `0` to insert before the first row.
#' @param col_rel_width Numeric vector of relative column widths (e.g.
#'   `c(2, 1, 1)` makes the first column twice as wide as the others).
#' @param column_widths_twips Integer vector of absolute column widths in
#'   twips. Overrides `col_rel_width`.
#' @param table_width_twips Total table width in twips.
#' @param table_width_pct_of_writable Table width as a fraction 0–1 of the
#'   writable page width.
#' @param table_width_pct Table width as a percentage 0–100 of the writable
#'   page width (convenience alias for `table_width_pct_of_writable * 100`).
#' @param table_align Horizontal placement: `"left"` (default), `"center"`,
#'   or `"right"`.
#' @param row_height_twips Row height for data rows in twips. `NULL` (default)
#'   uses the document-wide default from `rtfreporter_defaults.R`
#'   (font-size-aware). A positive integer specifies an explicit value.
#' @param row_height_exact Logical. `TRUE` = exact (clipped); `FALSE` = minimum.
#' @param header_row_height_twips Row height for column-header rows.
#' @param blank_row_height_twips Row height for blank separator rows.
#' @param cell_padding_left_twips Left cell padding in twips (default 72).
#' @param cell_padding_right_twips Right cell padding in twips (default 72).
#' @param cell_valign Vertical alignment: `"bottom"` (default), `"top"`,
#'   or `"center"`.
#'
#' @return An `rtftable_r6` object suitable for use in `rtf_tables()`.
#'
#' @examples
#' \dontrun{
#' df <- data.frame(Subject = c("001", "002"), Age = c(34L, 45L))
#'
#' # Simple table
#' tbl <- rtftable(df, col_rel_width = c(2, 1), row_height_twips = 280L)
#'
#' # Use in a pipe chain
#' doc <- rtf_document() %>%
#'   rtf_section(page = 1, secinfo = list(
#'     header = rtf_header(rows = list(c(l = "Protocol: RTF-101", r = "ACME Pharma")))
#'   )) %>%
#'   rtf_tables(list(tbl))
#'
#' generate_rtfreport(doc, "output.rtf", overwrite = TRUE)
#' }
#'
#' @export
rtftable <- function(data, col_header = NULL, spanning_header = NULL,
                     col_spec = NULL, border = "tfl", blank_rows = NULL,
                     col_rel_width = NULL, column_widths_twips = NULL,
                     table_width_twips = NULL, table_width_pct_of_writable = NULL,
                     table_width_pct = NULL, table_align = "left",
                     row_height_twips = NULL, row_height_exact = FALSE,
                     header_row_height_twips = NULL, blank_row_height_twips = NULL,
                     cell_padding_left_twips = 72L, cell_padding_right_twips = 72L,
                     cell_valign = "bottom") {
  rtftable_r6$new(
    data                        = data,
    col_header                  = col_header,
    spanning_header             = spanning_header,
    col_spec                    = col_spec,
    border                      = border,
    blank_rows                  = blank_rows,
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
}

#' Create an RTF figure object
#'
#' Embeds a PNG or JPEG image into the RTF output.
#' The result can be passed directly to `rtf_tables()` in a pipe chain.
#'
#' @param path Path to a PNG or JPEG image file.
#' @param width_twips Display width in twips. `NULL` = full writable width.
#' @param height_twips Display height in twips. `NULL` = derived from aspect ratio.
#' @param align Horizontal alignment: `"center"` (default), `"left"`, or `"right"`.
#'
#' @return An `rtfplot_r6` object suitable for use in `rtf_tables()`.
#'
#' @examples
#' \dontrun{
#' fig <- rtfplot("scatter.png", width_twips = 9000L)
#'
#' doc <- rtf_document() %>%
#'   rtf_section(page = 1, secinfo = list(
#'     header = rtf_header(rows = list(c(l = "Figure 14.1")))
#'   )) %>%
#'   rtf_tables(list(fig))
#'
#' generate_rtfreport(doc, "output.rtf", overwrite = TRUE)
#' }
#'
#' @export
rtfplot <- function(path, width_twips = NULL, height_twips = NULL,
                    align = "center") {
  rtfplot_r6$new(
    path         = path,
    width_twips  = width_twips,
    height_twips = height_twips,
    align        = align
  )
}
