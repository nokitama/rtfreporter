\name{rtftable}
\alias{rtftable}
\title{RTF table object}
\description{
\code{rtftable} holds one or more \code{data.frame}s together with all
table-level formatting metadata.  Pass an \code{rtftable} to
\code{\link{rtf_tables}()} in a pipe chain to use rich formatting such
as spanning headers, relative column widths, TFL borders, and table
alignment.
}
\usage{
rtftable(
  data,
  col_header              = NULL,
  spanning_header         = NULL,
  col_spec                = NULL,
  border                  = "tfl",
  blank_rows              = NULL,
  col_rel_width           = NULL,
  column_widths_twips     = NULL,
  table_width_twips       = NULL,
  table_width_pct_of_writable = NULL,
  table_width_pct         = NULL,
  table_align             = "left",
  row_height_twips        = 0L,
  row_height_exact        = FALSE,
  header_row_height_twips = NULL,
  blank_row_height_twips  = NULL,
  cell_padding_left_twips = 72L,
  cell_padding_right_twips = 72L,
  cell_valign             = "bottom"
)
}
\arguments{
\item{data}{A \code{data.frame}, \strong{or a list of \code{data.frame}s} with
  the same number of columns.  When a list is supplied every data.frame is
  rendered consecutively, each preceded by its own column-header and
  (optionally) spanning-header rows.}

\item{col_header}{Column header specification.  One of:
  \itemize{
    \item \code{NULL} — use column names as a single header row.
    \item A character vector — one element per column (single header row).
    \item A pipe-delimited string \code{"A | B | C"}.
    \item A \code{list} of the above for multiple header rows (shared across
      all data.frames when \code{data} is a list).
    \item When \code{data} is a list of \emph{N} data.frames: a list of exactly
      \emph{N} header specs (one per data.frame) — detected when the list length
      equals \emph{N} and every element is \code{NULL}, a character vector, or a
      list-of-character-vectors.
  }
}

\item{spanning_header}{A list of spanning-header specs.  Each element is a
  named list with \code{from} (int), \code{to} (int), \code{label} (chr),
  \code{underline} (logical).  When \code{data} is a list the spanning header
  is repeated before each data.frame.}

\item{col_spec}{A list of per-column formatting specs.  Each element is a
  named list with \code{col} (column index or name) plus any of:
  \code{align} (\code{"left"}/\code{"center"}/\code{"right"}),
  \code{bold}, \code{italic}, \code{underline} (logical),
  \code{indent_twips} (integer),
  \code{header_bold}, \code{header_italic}, \code{header_align}.}

\item{border}{Border specification.  \code{"tfl"} (default) applies the
  Clinical-TFL standard (header top+bottom, last-data-row bottom, no
  vertical lines).  \code{NULL} disables all borders.
  An \code{\link{rtf_table_border}} object or named list gives full control.}

\item{blank_rows}{Integer vector of positions at which to insert a blank
  separator row in the data section.  \code{0} inserts one before the first
  data row; \code{k} inserts one after data row \code{k}.}

\item{col_rel_width}{Numeric vector of \emph{relative} column widths
  (e.g. \code{c(3, 1, 1)} distributes 3:1:1).  Ignored when
  \code{column_widths_twips} is set.}

\item{column_widths_twips}{Integer vector of \emph{absolute} column widths
  in twips.  Takes precedence over \code{col_rel_width}.}

\item{table_width_twips}{Total table width in twips (absolute).  Used with
  \code{col_rel_width} when \code{column_widths_twips} is not set.
  1440 twips = 1 inch.}

\item{table_width_pct}{Table width as a \strong{percentage} (0–100) of the
  writable page width.  \code{100} = full writable width (margins to margins).
  Takes precedence over \code{table_width_pct_of_writable}.}

\item{table_width_pct_of_writable}{Table width as a \strong{fraction} (0–1)
  of the writable page width.  Kept for backward compatibility;
  prefer \code{table_width_pct}.}

\item{table_align}{Horizontal placement of the table on the page.
  \code{"left"} (default), \code{"center"}, or \code{"right"}.
  Emits \code{\\trqc} or \code{\\trqr} in the RTF row definition;
  \code{"left"} uses the RTF default.}

\item{row_height_twips}{Row height in twips for data rows.  \code{0}
  (default) = automatic height.  Always specify a positive integer; use
  \code{row_height_exact = TRUE} for a fixed (clipped) height.}

\item{row_height_exact}{Logical.  \code{FALSE} (default) = \emph{minimum}
  height (\code{\\trrh} positive; rows expand if content is taller).
  \code{TRUE} = \emph{exact} height (\code{\\trrh} negative; content is
  clipped if taller).}

\item{header_row_height_twips}{Row height for header/spanning rows.
  \code{NULL} uses \code{row_height_twips}.}

\item{blank_row_height_twips}{Height of blank separator rows in twips.
  \code{NULL} (default) uses \code{row_height_twips}.}

\item{cell_padding_left_twips}{Left cell padding in twips (default 72 ≈ 0.05 in).}

\item{cell_padding_right_twips}{Right cell padding in twips (default 72).}

\item{cell_valign}{Vertical cell alignment: \code{"bottom"} (default),
  \code{"top"}, or \code{"center"}.}
}
\value{An S3 object of class \code{rtftable}.}
\seealso{\code{\link{rtfreport}}, \code{\link{generate_rtfreport}},
  \code{\link{rtf_border_tfl}}, \code{\link{auto_col_widths}}}
\examples{
# --- Minimal single-DF table -------------------------------------------------
df <- data.frame(USUBJID = c("101-001", "101-002"), AGE = c(54L, 61L))
tbl <- rtftable(df)

# --- Table width and alignment -----------------------------------------------
# 70 percent of page width, centered
tbl2 <- rtftable(df,
  table_width_pct = 70,
  table_align     = "center")

# Absolute width, right-aligned
tbl3 <- rtftable(df,
  table_width_twips = 7200L,
  table_align       = "right")

# --- Relative column widths --------------------------------------------------
tbl4 <- rtftable(df,
  col_rel_width     = c(2, 1),
  table_width_twips = 9000L)

# --- Spanning header ---------------------------------------------------------
counts <- data.frame(
  Baseline = c("Low", "Normal", "High"),
  A_Low = c(4L, 0L, 0L), A_Norm = c(1L, 13L, 1L), A_High = c(0L, 2L, 3L),
  B_Low = c(3L, 0L, 0L), B_Norm = c(1L, 14L, 0L), B_High = c(0L, 1L, 4L)
)
shift_tbl <- rtftable(
  data            = counts,
  col_header      = c("Baseline", "Low", "Normal", "High", "Low", "Normal", "High"),
  spanning_header = list(
    list(from = 2L, to = 4L, label = "Treatment A (N=24)", underline = TRUE),
    list(from = 5L, to = 7L, label = "Treatment B (N=24)", underline = TRUE)
  ),
  column_widths_twips = c(2160L, 900L, 900L, 900L, 900L, 900L, 900L),
  border              = "tfl",
  row_height_twips    = 280L
)

# --- Multi data.frame (shared spanning header, per-DF col_header) ------------
df1 <- data.frame(A = 1:2, B = 3:4)
df2 <- data.frame(A = 5:6, B = 7:8)
tbl_multi <- rtftable(
  data       = list(df1, df2),
  col_header = list(c("Group 1 A", "Group 1 B"), c("Group 2 A", "Group 2 B"))
)

# --- col_spec: first column left, rest centered ------------------------------
tbl5 <- rtftable(df,
  col_spec = list(
    list(col = 1L, align = "left"),
    list(col = 2L, align = "center")
  )
)
}
