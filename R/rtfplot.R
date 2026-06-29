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
  # 17-20 (width), 21-24 (height) -- all big-endian.
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

#' Create an RTF figure object
#'
#' Embeds a PNG or JPEG image into the RTF output.
#' The result can be passed directly to `rtf_tables()` in a pipe chain.
#'
#' @param path Path to a PNG or JPEG image file.
#' @param width_twips Display width in twips. `NULL` = full writable width.
#' @param height_twips Display height in twips. `NULL` = derived from aspect ratio.
#' @param align Horizontal alignment: `"center"` (default), `"left"`, or `"right"`.
#'
#' @return An `rtfplot` (S3) object suitable for use in `rtf_tables()`.
#'
#' @examples
#' \dontrun{
#' fig <- rtfplot("scatter.png", width_twips = 9000L)
#'
#' doc <- rtf_document() %>%
#'   rtf_section(page = 1, secinfo = list(
#'     header = rtf_header(rows = list(c(l = "Figure 14.1")))
#'   )) %>%
#'   rtf_tables(list(fig))
#'
#' generate_rtfreport(doc, "output.rtf", overwrite = TRUE)
#' }
#'
#' @export
rtfplot <- function(path, width_twips = NULL, height_twips = NULL,
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


#' Print an rtfplot object
#'
#' Prints a compact summary of an [rtfplot()] figure: the image type and file,
#' the image's native pixel size, the display size that will be embedded (in
#' twips and inches, or the defaults when unset), and the alignment.
#'
#' @param x An `rtfplot` object.
#' @param ... Additional arguments (unused).
#'
#' @return `x`, invisibly. Called for the side effect of printing the summary.
#'
#' @examples
#' \dontrun{
#' print(rtfplot("scatter.png", width_twips = 9000L))
#' }
#'
#' @export
print.rtfplot <- function(x, ...) {
  cat(sprintf("<rtfplot> %s: %s\n", toupper(x$img_type), basename(x$path)))
  cat(sprintf("  Native size:  %d x %d px\n", x$img_width, x$img_height))
  twips_in <- function(t) sprintf("%d twips (%.2f in)", t, t / 1440)
  w <- if (is.null(x$width_twips))  "full writable width" else twips_in(x$width_twips)
  h <- if (is.null(x$height_twips)) "auto (aspect ratio)" else twips_in(x$height_twips)
  cat(sprintf("  Display:      %s wide x %s\n", w, h))
  cat(sprintf("  Align:        %s\n", x$align))
  invisible(x)
}
