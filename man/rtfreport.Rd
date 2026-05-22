\name{rtfreport}
\alias{rtfreport}
\alias{rtf_header}
\alias{rtf_footer}
\title{RTF report object and header/footer constructors}
\description{
\code{rtfreport} is the R6 class generator for one RTF report. It stores the
document in a document -> section -> page hierarchy.

\code{rtf_header()} and \code{rtf_footer()} create structured header/footer
objects with explicit control over borders, width, and row height.
}
\usage{
rtfreport$new(font_table = NULL, color_table = NULL, default_page = NULL, default_format = NULL)
rtf_header(rows, border = NULL, width_twips = NULL, row_height_twips = NULL, top_border = NULL)
rtf_footer(rows, border = rtf_border_top(), width_twips = NULL, row_height_twips = NULL, top_border = NULL)
}
\arguments{
\item{font_table}{A list of font definitions. Each element is a list with at
  least a \code{name} element (character string). Default: \code{list(list(name = "Courier"))}.}
\item{color_table}{A character vector of hex color codes (e.g. \code{"#000000"}).
  Default: \code{c("#000000")}.}
\item{default_page}{A named list of page layout settings. Keys:
  \code{paper}, \code{orientation}, \code{width_twips}, \code{height_twips},
  \code{margin_top_twips}, \code{margin_bottom_twips}, \code{margin_left_twips},
  \code{margin_right_twips}. Default: letter landscape with 0.75" top/bottom
  and 0.5" left/right margins.}
\item{default_format}{A named list of text/table formatting defaults. Keys:
  \code{font_index}, \code{font_size_half_points}, \code{line_spacing},
  \code{table_cell_height_twips}.}
\item{rows}{A named character vector (single row) or a list of named character
  vectors (multi-row). Names \code{l}, \code{c}, \code{r} map to left, center,
  right columns. See \bold{Column-count rules} below.}
\item{border}{An \code{\link{rtf_border}} object controlling the border applied
  to all rows of the header/footer table. \code{NULL} = no border (default for
  header). Use \code{\link{rtf_border_top}()} for a horizontal dividing line
  (default for footer).}
\item{width_twips}{Integer. Table width in twips. \code{NULL} (default) uses
  the full writable width (page width minus margins).}
\item{row_height_twips}{Integer row height in twips. \code{NULL} (default) reads
  \code{header_footer_row_height_twips} from \code{inst/resources/rtfreporter_defaults.R}.}
\item{top_border}{\emph{Deprecated.} Use \code{border = rtf_border_top()} or
  \code{border = NULL} instead. Emits a warning if supplied.}
}
\section{Header/Footer format}{

Headers and footers use a \strong{plain named character vector} to specify
cell content. The names map to column alignment:

\tabular{ll}{
  \strong{Name} \tab \strong{Alignment} \cr
  \code{l}      \tab left              \cr
  \code{r}      \tab right             \cr
  \code{c}      \tab center            \cr
}

\strong{Column-count rules:}
\itemize{
  \item Only \code{l} → 1 column (left)
  \item Only \code{c} → 1 column (center)
  \item Only \code{r} → 1 column (right)
  \item \code{l} + \code{r} (no \code{c}) → 2 columns (left, right)
  \item \code{c} present with \code{l} or \code{r} → 3 columns; missing keys fill with \code{""}
  \item \code{l} + \code{c} + \code{r} → 3 columns
}

\strong{Shorthand form} (plain named vector, single row):
\preformatted{
report$add_section(
  header = c(l = "Protocol: RTF-101", r = "Page {AUTO_PAGE} of {TOTAL_PAGES}"),
  footer = c(l = "Confidential")
)
}

\strong{Object form} (multi-row, with borders and width):
\preformatted{
hdr <- rtf_header(
  rows = list(
    c(l = "Protocol: RTF-101", r = "HOGE company"),
    c(l = "Study Title",       r = "Page {AUTO_PAGE} of {TOTAL_PAGES}")
  )
)
ftr <- rtf_footer(c(l = "Confidential"), top_border = TRUE)
report$add_section(header = hdr, footer = ftr)
}

\strong{Section inheritance:} If \code{add_section()} is called without a
\code{header} or \code{footer}, the value is inherited from the immediately
preceding section. If no preceding section exists, no header/footer is rendered.

\strong{Page tokens} available in header/footer text:
\describe{
  \item{\code{{AUTO_PAGE}}}{Replaced with RTF \code{\\chpgn} — dynamic page number
    updated per page by the RTF viewer. \strong{(Recommended)}}
  \item{\code{{AUTO_TOTAL_PAGES}}}{Replaced with RTF NUMPAGES field — dynamic
    total updated by the RTF viewer.}
  \item{\code{{PAGE}}}{Alias for \code{{AUTO_PAGE}}.}
  \item{\code{{TOTAL_PAGES}}}{Replaced with the static total page count computed
    at render time by \code{generate_rtfreport()}.}
}
Recommended usage: \code{"Page \{AUTO_PAGE\} of \{TOTAL_PAGES\}"}.
}
\details{
The public methods include:
\itemize{
\item \code{add_section(header = NULL, footer = NULL)} — Adds a section and returns
  its 1-based index. \code{header} and \code{footer} accept a plain named vector
  or an \code{rtf_header()} / \code{rtf_footer()} object.
\item \code{get_section(section_index)} — Returns the full section list.
\item \code{get_section_header(section_index)} — Returns the header stored in the
  section (may be \code{NULL} if not set).
\item \code{get_section_footer(section_index)} — Returns the footer stored in the
  section (may be \code{NULL} if not set).
\item \code{set_section_header(section_index, header)} — Sets or replaces the
  section header after creation.
\item \code{set_section_footer(section_index, footer)} — Sets or replaces the
  section footer after creation.
\item \code{add_page(section_index, title = NULL, content = list(), footer_notes = NULL, page_options = NULL)} — Adds a page and returns its 1-based index.
\item \code{add_table(section_index, page_index, data, footer = NULL, metadata = NULL)}
\item \code{add_listing(section_index, page_index, data, footer = NULL, metadata = NULL)}
\item \code{add_figure(section_index, page_index, path, footer = NULL, metadata = NULL)}
\item \code{add_section_from_dataframes(data_list, section_header = NULL, section_footer = NULL, page_titles = NULL, block_type = "table", page_footer_notes = NULL, metadata = NULL)} — Convenience method; creates one section with one page per data frame.
\item \code{set_default_header(header)} — \strong{Deprecated.} Emits a warning; does nothing. Use per-section \code{header} in \code{add_section()} instead.
\item \code{set_default_footer(footer)} — \strong{Deprecated.} Emits a warning; does nothing. Use per-section \code{footer} in \code{add_section()} instead.
\item \code{set_default_page(page)} — Updates page layout defaults.
\item \code{set_default_format(fmt)} — Updates text/table formatting defaults.
\item \code{set_document_defaults(...)} — Updates any combination of defaults in one call.
\item \code{validate()} — Validates the report structure; stops with an error message if invalid.
}
}
\value{
\code{rtfreport$new()} returns an \code{R6ClassGenerator} object. \code{rtf_header()}
and \code{rtf_footer()} return a named list with elements \code{rows},
\code{width_twips}, \code{top_border}, and \code{row_height_twips}.
}
\examples{
# Shorthand header/footer (single row)
report <- rtfreport$new()
sec <- report$add_section(
  header = c(l = "Protocol: RTF-101", r = "Page {AUTO_PAGE} of {TOTAL_PAGES}"),
  footer = c(l = "Confidential")
)
report$add_page(sec, title = "Table 1")

# Object form with multi-row header
hdr <- rtf_header(
  rows = list(
    c(l = "Protocol: RTF-101", r = "HOGE company"),
    c(l = "Study Title",       r = "Page {AUTO_PAGE} of {TOTAL_PAGES}")
  )
)
ftr <- rtf_footer(c(l = "Confidential"))

report2 <- rtfreport$new()
sec2 <- report2$add_section(header = hdr, footer = ftr)
report2$add_page(sec2, title = "Table 1")

# Get header/footer back
hdr_back <- report2$get_section_header(sec2)
ftr_back <- report2$get_section_footer(sec2)
}