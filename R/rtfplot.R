# rtfplot: figure object for embedding PNG/JPEG images into RTF reports.
#
# Reads the image file, extracts dimensions, and stores the binary data
# location plus metadata.  The renderer (.render_rtfplot) reads the file and
# emits a \pict RTF command.

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

# Internal S3 constructor.  Public callers use rtfplot() in wrappers.R.
.new_rtfplot <- function(path, width_twips = NULL, height_twips = NULL,
                         align = "center") {
  if (!file.exists(path)) {
    stop(sprintf("Image file not found: %s", path), call. = FALSE)
  }
  ext <- tolower(tools::file_ext(path))
  if (!ext %in% c("png", "jpg", "jpeg")) {
    stop("rtfplot supports PNG and JPEG files only.", call. = FALSE)
  }
  img_type <- if (ext == "png") "png" else "jpeg"

  dims <- if (img_type == "png") .read_png_dims(path) else .read_jpeg_dims(path)

  if (!align %in% c("left", "center", "right")) {
    stop("`align` must be 'left', 'center', or 'right'.", call. = FALSE)
  }

  structure(
    list(
      path         = path,
      width_twips  = if (!is.null(width_twips))  as.integer(width_twips)  else NULL,
      height_twips = if (!is.null(height_twips)) as.integer(height_twips) else NULL,
      align        = align,
      img_width    = dims$width,
      img_height   = dims$height,
      img_type     = img_type
    ),
    class = "rtfplot"
  )
}
