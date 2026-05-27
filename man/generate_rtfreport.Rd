\name{generate_rtfreport}
\alias{generate_rtfreport}
\title{Generate an RTF file from a report object}
\description{
Render an \code{rtf_document} (built with the pipe API) — or the
internal \code{rtfreport} S3 object — to a single RTF file.
}
\usage{generate_rtfreport(report, file_path, overwrite = FALSE)}
\arguments{
\item{report}{An \code{rtf_document} object from \code{\link{rtf_document}()},
  or an internal \code{rtfreport} S3 object.}
\item{file_path}{Output RTF file path.}
\item{overwrite}{Logical; whether to overwrite an existing file.}
}
\value{
Invisibly returns \code{file_path}.
}
\seealso{
\code{\link{rtf_document}}, \code{\link{rtf_tables}}, \code{\link{rtf_section}}
}
\examples{
\dontrun{
  library(magrittr)
  df <- data.frame(A = 1:3, B = c("x", "y", "z"))
  doc <- rtf_document() \%>\%
    rtf_section(page = 1, secinfo = list(header = rtf_header(c(l = "Example")))) \%>\%
    rtf_tables(list(df))
  generate_rtfreport(doc, tempfile(fileext = ".rtf"), overwrite = TRUE)
}
}
