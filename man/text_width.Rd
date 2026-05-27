\name{text_width_in}
\alias{text_width_in}
\alias{auto_col_widths}
\title{Font-aware column width estimation}
\description{
\code{text_width_in()} estimates the display width of a character string in
inches for a given font and size.

\code{auto_col_widths()} uses \code{text_width_in()} to compute a sensible
column-width vector in twips for an \code{\link{rtftable}}, based on the
widest entry (data or header) in each column.
}
\usage{
text_width_in(text, font = "courier_new", size_half_points = 18L)

auto_col_widths(
  df,
  col_header          = NULL,
  font                = "courier_new",
  size_half_points    = 18L,
  table_width_twips   = NULL,
  min_col_width_twips = 720L,
  col_padding_twips   = 288L
)
}
\arguments{
\item{text}{Character vector.  \code{NA} is treated as \code{""}.}
\item{font}{Font name.  One of \code{"courier_new"} (default),
  \code{"courier"}, or \code{"arial"}.  Unknown values fall back to
  Courier New.}
\item{size_half_points}{Font size in \strong{half-points} (the unit used by
  RTF and the document's \code{default_format$font_size_half_points}).
  Default \code{18} = 9 pt.}
\item{df}{A \code{data.frame} whose columns are sized.}
\item{col_header}{Optional character vector of column header labels.  When
  supplied, header text is included in the width calculation alongside
  data values.  A pipe-delimited string \code{"A | B | C"} is also accepted.}
\item{table_width_twips}{If supplied, the resulting widths are
  \strong{scaled} so that their sum equals exactly this value.  The last
  column absorbs any rounding residual.}
\item{min_col_width_twips}{Minimum width per column in twips.
  Default 720 = 0.5 inch.}
\item{col_padding_twips}{Padding added to each column's estimated text width
  before converting to twips.  Default 288 ≈ 0.2 inch.}
}
\value{
\itemize{
  \item \code{text_width_in()} — numeric vector of widths in inches (same
    length as \code{text}).
  \item \code{auto_col_widths()} — integer vector of column widths in twips
    (one per column of \code{df}).
}
}
\examples{
# --- text_width_in -----------------------------------------------------------
text_width_in("Hello, World!")                          # ~0.88 in at 9pt Courier
text_width_in("abc", size_half_points = 24L)            # 12pt
text_width_in(c("short", "much longer string"))         # vectorised

# --- auto_col_widths ----------------------------------------------------------
df <- data.frame(
  Subject  = c("001-001", "002-001"),
  Age      = c(34L, 45L),
  Sex      = c("Male", "Female"),
  stringsAsFactors = FALSE
)

# Unconstrained widths (sum to natural fit)
w <- auto_col_widths(df)
w

# Scale to full writable width (14400 twips = 10 in landscape letter)
w_scaled <- auto_col_widths(df, table_width_twips = 14400L)
sum(w_scaled)  # 14400

# Include custom header labels in width calculation
w_hdr <- auto_col_widths(df,
  col_header        = "Subject Identifier | Age (years) | Sex",
  table_width_twips = 10000L)

# Use in rtftable
\dontrun{
  tbl <- rtftable(df, column_widths_twips = auto_col_widths(df))
}
}
\seealso{\code{\link{rtftable}}}
