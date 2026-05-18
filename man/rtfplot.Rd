\name{rtfplot}
\alias{rtfplot}
\title{RTF plot object}
\description{
\code{rtfplot} reads a PNG or JPEG image and prepares it for embedding inside
an RTF document.
}
\usage{rtfplot$new(path, width_twips = NULL, height_twips = NULL, align = "center")}
\arguments{
\item{path}{Path to a PNG or JPEG image file.}
\item{width_twips}{Displayed width in twips.}
\item{height_twips}{Displayed height in twips.}
\item{align}{Horizontal alignment: \code{"center"}, \code{"left"}, or \code{"right"}.}
}
\value{
An \code{R6ClassGenerator} object.
}
\examples{
\dontrun{
  plot_obj <- rtfplot$new("figure.png")
}
}