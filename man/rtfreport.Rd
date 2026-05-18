\name{rtfreport}
\alias{rtfreport}
\title{RTF report object}
\description{
\code{rtfreport} is the R6 class generator for one RTF report. It stores the
document in a document -> section -> page hierarchy.
}
\usage{rtfreport$new(font_table = NULL, color_table = NULL, default_page = NULL, default_header = NULL, default_footer = NULL, default_format = NULL)}
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
\item{default_header}{Document-wide default header applied to sections that do
  not specify their own header. A list with elements:
  \describe{
    \item{\code{rows}}{A list of plain named character vectors (see \bold{Header/Footer format}).
      Default: empty list (no document-wide header).}
    \item{\code{width_twips}}{Header width in twips, or \code{NULL} for full writable width.}
  }
}
\item{default_footer}{Document-wide default footer. Same structure as
  \code{default_header}, plus:
  \describe{
    \item{\code{top_border}}{Logical. Draw a horizontal rule above the footer. Default: \code{TRUE}.}
  }
}
\item{default_format}{A named list of text/table formatting defaults. Keys:
  \code{font_index}, \code{font_size_half_points}, \code{line_spacing},
  \code{table_cell_height_twips}.}
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

\strong{Section-level header/footer} (single row, passed directly to
\code{add_section()} or \code{set_section_header()} / \code{set_section_footer()}):

\preformatted{
report$add_section(
  header = c(l = "Protocol: RTF-101", r = "Page {PAGE} of {TOTAL_PAGES}"),
  footer = c(l = "Confidential")
)
}

\strong{Document-level default header/footer} (may be multi-row; each row is a
plain named character vector inside \code{rows}):

\preformatted{
report$set_default_header(list(
  rows = list(
    c(l = "Protocol: RTF-101", r = "Page {PAGE} of {TOTAL_PAGES}"),
    c(l = "Study Title",       r = "Company Name")
  )
))
report$set_default_footer(list(
  rows      = list(c(l = "Confidential - For Clinical Study Use Only")),
  top_border = TRUE
))
}

\strong{Page tokens} available in header/footer text:
\describe{
  \item{\code{{PAGE}}}{Replaced with a dynamic page-number RTF field (\code{\\chpgn})
    updated per page by the RTF viewer.}
  \item{\code{{TOTAL_PAGES}}}{Replaced with the static total page count computed at
    render time.}
}
}
\details{
The public methods include:
\itemize{
\item \code{add_section(header = NULL, footer = NULL)} — Adds a section and returns
  its 1-based index. \code{header} and \code{footer} are plain named character
  vectors (see \bold{Header/Footer format}).
\item \code{get_section(section_index)} — Returns the section list.
\item \code{set_section_header(section_index, header)} — Sets or replaces the
  section header after creation.
\item \code{set_section_footer(section_index, footer)} — Sets or replaces the
  section footer after creation.
\item \code{add_page(section_index, title = NULL, content = list(), footer_notes = NULL, page_options = NULL)} — Adds a page and returns its 1-based index.
\item \code{add_table(section_index, page_index, data, footer = NULL, metadata = NULL)}
\item \code{add_listing(section_index, page_index, data, footer = NULL, metadata = NULL)}
\item \code{add_figure(section_index, page_index, path, footer = NULL, metadata = NULL)}
\item \code{add_section_from_dataframes(data_list, section_header = NULL, section_footer = NULL, page_titles = NULL, block_type = "table", page_footer_notes = NULL, metadata = NULL)} — Convenience method that creates one section with one page per data frame.
\item \code{set_default_header(header)} — Updates the document-wide default header.
\item \code{set_default_footer(footer)} — Updates the document-wide default footer.
\item \code{set_default_page(page)} — Updates page layout defaults.
\item \code{set_default_format(fmt)} — Updates text/table formatting defaults.
\item \code{set_document_defaults(...)} — Updates any combination of defaults in one call.
\item \code{validate()} — Validates the report structure; stops with an error message if invalid.
}
}
\value{
An \code{R6ClassGenerator} object.
}
\examples{
report <- rtfreport$new()
sec <- report$add_section(
  header = c(l = "Protocol: RTF-101", r = "Page {PAGE} of {TOTAL_PAGES}"),
  footer = c(l = "Confidential")
)
report$add_page(sec, title = "Table 1")
}