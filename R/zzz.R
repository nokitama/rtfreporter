# Package-load hooks.
#
# rtfreporter is pure S3 -- no class generators to initialise at load time.
# `.onLoad()` seeds the package's configurable defaults (see R/defaults.R) as
# `rtfreporter.*` options, without clobbering any value a site has already set
# (e.g. in Rprofile.site), so per-site defaults take precedence.
.onLoad <- function(libname, pkgname) {
  op <- options()
  fd <- .rtfreporter_factory_defaults()
  toset <- !(names(fd) %in% names(op))
  if (any(toset)) options(fd[toset])
  invisible()
}
