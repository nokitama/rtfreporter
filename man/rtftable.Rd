\name{rtftable}
\alias{rtftable}
\title{RTF table object}
\description{
\code{rtftable} wraps a data frame together with table formatting metadata.
Pass an \code{rtftable} object to \code{report$add_table()} to render a
clinical-style table.
}
\usage{rtftable$new(data, col_header = NULL, spanning_header = NULL, col_spec = NULL, border = "tfl", blank_rows = NULL, col_rel_width = NULL, column_widths_twips = NULL, table_width_twips = NULL, table_width_pct_of_writable = NULL, row_height_twips = 0L, row_height_exact = FALSE, header_row_height_twips = NULL, blank_row_height_twips = NULL, cell_padding_left_twips = 72L, cell_padding_right_twips = 72L, cell_valign = "bottom")}
\arguments{
\item{data}{A data frame.}
\item{col_header}{Column header specification.}
\item{spanning_header}{Optional spanning-header specification.}
\item{col_spec}{Per-column formatting specification.}
\item{border}{Border specification. The default \code{"tfl"} applies a clinical TFL layout.}
\item{blank_rows}{Positions where blank separator rows are inserted.}
\item{col_rel_width}{Relative column widths.}
\item{column_widths_twips}{Absolute column widths in twips.}
\item{table_width_twips}{Total table width in twips.}
\item{table_width_pct_of_writable}{Table width as a fraction of writable page width.}
\item{row_height_twips}{Row height in twips.}
\item{row_height_exact}{Logical; whether the row height is exact.}
\item{header_row_height_twips}{Header row height in twips.}
\item{blank_row_height_twips}{Blank-row height in twips.}
\item{cell_padding_left_twips}{Left cell padding in twips.}
\item{cell_padding_right_twips}{Right cell padding in twips.}
\item{cell_valign}{Vertical alignment: \code{"bottom"}, \code{"top"}, or \code{"center"}.}
}
\value{
An \code{R6ClassGenerator} object.
}
\examples{
df <- data.frame(USUBJID = c("101-001", "101-002"), AGE = c(54, 61))
tbl <- rtftable$new(df)
}