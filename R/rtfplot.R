# rtfplot: figure object for embedding PNG/JPEG images into RTF reports.
#
# Reads the image file, extracts dimensions, and stores the binary data as
# hex so that generate_rtfreport() can emit a \pict RTF command.

# Read PNG image dimensions from the IHDR chunk (bytes 17-24).
.read_png_dims <- function(path) {
  raw <- readBin(path, "raw", n = 24L)
  if (length(raw) < 24L) stop("File too short to be a valid PNG.", call. = FALSE)
  # PNG signature: bytes 1-8.  IHDR chunk: bytes 9-12 (length), 13-16 (type),
  # 17-20 (width), 21-24 (height) — all big-endian.
  to_int <- function(b) sum(as.integer(b) * c(16777216L, 65536L, 256L, 1L))
  list(width = to_int(raw[17:20]), height = to_int(raw[21:24]))
}

# Read JPEG image dimensions by scanning for the SOF marker.
.read_jpeg_dims <- function(path) {
  raw <- readBin(path, "raw", n = file.info(path)$size)
  n   <- length(raw)
  i   <- 3L  # Skip the 2-byte SOI marker (FF D8).
  while (i <= n - 4L) {
    if (raw[i] == as.raw(0xFF)) {
      marker <- raw[i + 1L]
      # SOF0/SOF1/SOF2 markers carry frame dimensions.
      if (marker %in% as.raw(c(0xC0, 0xC1, 0xC2))) {
        height <- as.integer(raw[i + 5L]) * 256L + as.integer(raw[i + 6L])
        width  <- as.integer(raw[i + 7L]) * 256L + as.integer(raw[i + 8L])
        return(list(width = width, height = height))
      }
      # Skip past this marker segment.
      seg_len <- as.integer(raw[i + 2L]) * 256L + as.integer(raw[i + 3L])
      i <- i + seg_len + 2L
    } else {
      i <- i + 1L
    }
  }
  stop("Could not locate SOF marker to read JPEG dimensions.", call. = FALSE)
}

#' RTF plot (embedded figure) object
#'
#' `rtfplot` reads a PNG or JPEG image and prepares it for binary embedding
#' inside an RTF document via the `\pict` command.
#'
#' @param path Path to the image file (PNG or JPEG).
#' @param width_twips Displayed width in twips.  `NULL` = use the full
#'   writable width of the page.
#' @param height_twips Displayed height in twips.  `NULL` = maintain the
#'   image's aspect ratio given `width_twips`.
#' @param align Horizontal alignment: `"center"` (default), `"left"`,
#'   `"right"`.
#'
#' Internal R6 class for plot objects
#' (S3 wrapper rtfplot() is the public API)
rtfplot_r6 <- R6::R6Class(
  classname = "rtfplot_r6",
  public = list(
    path         = NULL,
    width_twips  = NULL,
    height_twips = NULL,
    align        = NULL,
    img_width    = NULL,  # native pixel width
    img_height   = NULL,  # native pixel height
    img_type     = NULL,  # "png" or "jpeg"

    initialize = function(path, width_twips = NULL, height_twips = NULL,
                          align = "center") {
      if (!file.exists(path)) {
        stop(sprintf("Image file not found: %s", path), call. = FALSE)
      }
      ext <- tolower(tools::file_ext(path))
      if (!ext %in% c("png", "jpg", "jpeg")) {
        stop("rtfplot supports PNG and JPEG files only.", call. = FALSE)
      }
      self$path <- path
      self$img_type <- if (ext == "png") "png" else "jpeg"

      dims <- if (self$img_type == "png") .read_png_dims(path) else .read_jpeg_dims(path)
      self$img_width  <- dims$width
      self$img_height <- dims$height

      self$width_twips  <- if (!is.null(width_twips))  as.integer(width_twips)  else NULL
      self$height_twips <- if (!is.null(height_twips)) as.integer(height_twips) else NULL
      if (!align %in% c("left", "center", "right")) {
        stop("`align` must be 'left', 'center', or 'right'.", call. = FALSE)
      }
      self$align <- align
      invisible(self)
    }
  )
)
