\name{rtf_border_side}
\alias{rtf_border_side}
\alias{rtf_border}
\alias{rtf_border_none}
\alias{rtf_border_top}
\alias{rtf_border_bottom}
\alias{rtf_border_box}
\alias{rtf_table_border}
\alias{rtf_border_tfl}
\title{Border specification classes for rtfreporter}
\description{
Three constructor functions build border specifications used in
\code{\link{rtf_header}}, \code{\link{rtf_footer}}, and
\code{\link{rtftable}}.  All return plain lists with a class attribute.
}

\section{Class hierarchy}{
\itemize{
  \item \code{rtf_border_side} — defines one edge (style, weight, colour).
  \item \code{rtf_border} — four edges of a single cell or row.
  \item \code{rtf_table_border} — per-zone borders for a full table.
}
}

\usage{
rtf_border_side(style = "single", width = 15L, color = NULL)

rtf_border(top = NULL, bottom = NULL, left = NULL, right = NULL)

rtf_border_none()
rtf_border_top(style = "single", width = 15L, color = NULL)
rtf_border_bottom(style = "single", width = 15L, color = NULL)
rtf_border_box(style = "single", width = 15L, color = NULL)

rtf_table_border(
  header    = NULL,
  spanning  = NULL,
  body      = NULL,
  first_row = NULL,
  last_row  = NULL
)

rtf_border_tfl(style = "single", width = 15L, color = NULL)
}

\arguments{
  \item{style}{Line style. One of \code{"single"} (default), \code{"double"},
    \code{"thick"}, \code{"dash"}, \code{"dot"}.}
  \item{width}{Line weight in twips (integer).  Default \code{15} ≈ 0.5 pt.}
  \item{color}{Line colour.  \code{NULL} (default) = black.  Or a 6-digit hex
    string such as \code{"#003366"}.}
  \item{top, bottom, left, right}{\code{NULL} (no border on this edge) or an
    \code{rtf_border_side} object.}
  \item{header}{An \code{rtf_border} for column-header rows, or \code{NULL}.}
  \item{spanning}{An \code{rtf_border} for spanning-header rows, or \code{NULL}.}
  \item{body}{An \code{rtf_border} for data rows, or \code{NULL}.}
  \item{first_row}{An \code{rtf_border} override for the first data row
    (merged on top of \code{body}).}
  \item{last_row}{An \code{rtf_border} override for the last data row
    (merged on top of \code{body}).}
}

\value{
\itemize{
  \item \code{rtf_border_side()} — a list of class \code{"rtf_border_side"}.
  \item \code{rtf_border()} and convenience variants — a list of class
    \code{"rtf_border"}.
  \item \code{rtf_table_border()} and \code{rtf_border_tfl()} — a list of
    class \code{"rtf_table_border"}.
}
}

\examples{
# --- rtf_border_side ---------------------------------------------------------
s_single <- rtf_border_side()                        # single, 15 twips, black
s_thick  <- rtf_border_side("thick", 20L, "#003366") # thick, 20 twips, dark blue

# --- rtf_border (cell) -------------------------------------------------------
b_top    <- rtf_border_top()          # top edge only
b_box    <- rtf_border_box()          # all four edges
b_custom <- rtf_border(
  top    = rtf_border_side("single"),
  bottom = rtf_border_side("double", 10L)
)

# --- rtf_table_border --------------------------------------------------------
tbl_b <- rtf_table_border(
  header   = rtf_border(top = rtf_border_side(), bottom = rtf_border_side()),
  last_row = rtf_border(bottom = rtf_border_side())
)

# TFL clinical preset (same as rtftable default)
tbl_b <- rtf_border_tfl()

# --- Using borders in header/footer ------------------------------------------
ftr <- rtf_footer(
  rows   = list(c(l = "Confidential", r = "{AUTO_PAGE}/{AUTO_TOTAL_PAGES}")),
  border = rtf_border_top()   # default; top dividing line
)
hdr <- rtf_header(
  rows   = list(c(c = "Study Title")),
  border = rtf_border(bottom = rtf_border_side("thick", 20L))
)

# --- Using borders in rtftable -----------------------------------------------
tbl <- rtftable(
  data   = data.frame(A = 1:3, B = letters[1:3]),
  border = rtf_border_tfl()
)

# Custom table border
tbl2 <- rtftable(
  data   = data.frame(X = 1:2),
  border = rtf_table_border(
    header   = rtf_border_box(),
    last_row = rtf_border(bottom = rtf_border_side("double"))
  )
)
}

\seealso{
\code{\link{rtf_header}}, \code{\link{rtf_footer}}, \code{\link{rtftable}}
}
