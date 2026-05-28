# rtfplot.R -- figure object for embedding PNG / JPEG into RTF.

# Helper: write a 1x1 valid PNG to a tempfile and return its path.
# We hand-write the bytes (74-byte minimal RGB PNG) so the test works
# in any environment — no graphics device required.
.tmp_png <- function() {
  bytes <- as.raw(c(
    # PNG signature
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    # IHDR chunk (length, type, width=1, height=1, bit-depth=8, color=2 RGB,
    # compression=0, filter=0, interlace=0, CRC)
    0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x02, 0x00, 0x00, 0x00,
    0x90, 0x77, 0x53, 0xDE,
    # IDAT chunk (length 12, type, deflated single white pixel, CRC)
    0x00, 0x00, 0x00, 0x0C,
    0x49, 0x44, 0x41, 0x54,
    0x08, 0x99, 0x63, 0xF8, 0xFF, 0xFF, 0xFF, 0x3F,
    0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0xCC, 0x59,
    0xE7,
    # IEND chunk
    0x00, 0x00, 0x00, 0x00,
    0x49, 0x45, 0x4E, 0x44,
    0xAE, 0x42, 0x60, 0x82
  ))
  f <- tempfile(fileext = ".png")
  writeBin(bytes, f)
  f
}

# ──────── Construction ────────────────────────────────────────────────────

test_that("rtfplot() constructs an S3 object from a PNG path", {
  f   <- .tmp_png(); on.exit(unlink(f), add = TRUE)
  fig <- rtfplot(f)
  expect_s3_class(fig, "rtfplot")
  expect_identical(fig$path, f)
  expect_identical(fig$img_type, "png")
  expect_gt(fig$img_width,  0L)
  expect_gt(fig$img_height, 0L)
  expect_identical(fig$align, "center")     # default
})

test_that("rtfplot(width_twips, height_twips, align) propagate", {
  f <- .tmp_png(); on.exit(unlink(f), add = TRUE)
  fig <- rtfplot(f, width_twips = 7200L, height_twips = 3600L,
                  align = "left")
  expect_identical(fig$width_twips,  7200L)
  expect_identical(fig$height_twips, 3600L)
  expect_identical(fig$align,        "left")
})

test_that("rtfplot() rejects non-existent files", {
  expect_error(rtfplot("/nope/does/not/exist.png"), "not found")
})

test_that("rtfplot() rejects unsupported extensions", {
  f <- tempfile(fileext = ".bmp"); file.create(f)
  on.exit(unlink(f), add = TRUE)
  expect_error(rtfplot(f), "PNG and JPEG")
})

test_that("rtfplot() rejects invalid align", {
  f <- .tmp_png(); on.exit(unlink(f), add = TRUE)
  expect_error(rtfplot(f, align = "justify"), "align")
})

# ──────── End-to-end render via rtf_figures() / generate_rtfreport() ──────

test_that("a figure can be embedded into a generated RTF document", {
  f <- .tmp_png(); on.exit(unlink(f), add = TRUE)
  doc <- rtf_document()
  doc <- rtf_section(doc, page = 1,
                     secinfo = list(header = NULL, footer = NULL))
  doc <- rtf_figures(doc, list(rtfplot(f, width_twips = 4320L)))

  out <- tempfile(fileext = ".rtf")
  on.exit(unlink(out), add = TRUE)
  expect_invisible(generate_rtfreport(doc, out, overwrite = TRUE))
  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 0L)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # \pict signals an embedded picture, \pngblip identifies the format.
  expect_match(txt, "\\\\pict")
  expect_match(txt, "\\\\pngblip")
})
