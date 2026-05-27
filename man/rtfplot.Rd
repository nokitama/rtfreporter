\name{rtfplot}
\alias{rtfplot}
\title{RTF plot object}
\description{
\code{rtfplot} reads a PNG or JPEG image and prepares it for embedding inside
an RTF document.
}
\usage{rtfplot(path, width_twips = NULL, height_twips = NULL, align = "center")}
\arguments{
\item{path}{Path to a PNG or JPEG image file.}
\item{width_twips}{Displayed width in twips.  \code{NULL} = full writable width.}
\item{height_twips}{Displayed height in twips.  \code{NULL} = derived from aspect ratio.}
\item{align}{Horizontal alignment: \code{"center"} (default), \code{"left"}, or \code{"right"}.}
}
\value{
An S3 object of class \code{rtfplot}.
}
\seealso{\code{\link{rtf_figures}}, \code{\link{generate_rtfreport}}}
\examples{
\dontrun{
  plot_obj <- rtfplot("figure.png")
}
}
