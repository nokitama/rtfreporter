# Package-load hooks.

.onLoad <- function(libname, pkgname) {
  # Initialise the optional rtf_theme R6 class generator, if R6 is
  # installed.  All other classes are S3 and do not require any setup.
  .init_rtf_theme_class()
  invisible()
}

# `self` is an implicit binding inside R6 method definitions in
# .init_rtf_theme_class() (R/rtf_theme.R).  R CMD check's static
# analysis doesn't recognise it, so we declare it as a known global.
utils::globalVariables("self")
