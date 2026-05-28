# zzz.R -- .onLoad() hook: lazy-initialise the optional R6 rtf_theme class.

test_that(".onLoad() is exported from the package namespace", {
  expect_true(exists(".onLoad", envir = asNamespace("rtfreporter"),
                     inherits = FALSE))
  on_load <- get(".onLoad", envir = asNamespace("rtfreporter"),
                  inherits = FALSE)
  expect_type(on_load, "closure")
})

test_that(".onLoad() runs without error (idempotent)", {
  on_load <- get(".onLoad", envir = asNamespace("rtfreporter"),
                  inherits = FALSE)
  # Calling it a second time should be a no-op.
  expect_silent(on_load(NULL, "rtfreporter"))
})

test_that("rtf_theme R6 class generator is initialised after package load", {
  skip_if_not_installed("R6")
  gen <- get(".rtf_theme_class", envir = asNamespace("rtfreporter"),
             inherits = FALSE)
  expect_false(is.null(gen))
  expect_true(inherits(gen, "R6ClassGenerator"))
})

test_that(".init_rtf_theme_class() is a no-op when called again", {
  skip_if_not_installed("R6")
  before <- get(".rtf_theme_class", envir = asNamespace("rtfreporter"),
                 inherits = FALSE)
  rtfreporter:::.init_rtf_theme_class()
  after  <- get(".rtf_theme_class", envir = asNamespace("rtfreporter"),
                 inherits = FALSE)
  expect_identical(before, after)
})
