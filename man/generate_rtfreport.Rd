\name{generate_rtfreport}
\alias{generate_rtfreport}
\title{Generate an RTF file from an rtfreport object}
\description{
Render an \code{rtfreport} object to a single RTF file.
}
\usage{generate_rtfreport(report, file_path, overwrite = FALSE)}
\arguments{
\item{report}{An \code{rtfreport} object.}
\item{file_path}{Output RTF file path.}
\item{overwrite}{Logical; whether to overwrite an existing file.}
}
\value{
Invisibly returns \code{file_path}.
}
\seealso{
\code{\link{rtfreport}}
}
\examples{
\dontrun{
  report <- rtfreport$new()
  sec <- report$add_section()
  report$add_page(sec, title = "Example")
  generate_rtfreport(report, tempfile(fileext = ".rtf"), overwrite = TRUE)
}
}