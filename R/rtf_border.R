# rtf_border.R -- Border specifications (all S3)
#
# Three constructor functions build border specifications used in
# rtf_header(), rtf_footer(), and rtftable():
#
#   rtf_border_side   -- one edge (style, width, color)
#   rtf_border        -- four edges of a single cell/row
#   rtf_table_border  -- per-zone borders for a full table
#
# All three are plain S3 lists with a class attribute.  Reference semantics
# are intentionally absent: every value is a pure record that travels with
# copy semantics, so passing a border into multiple tables is always safe.


# -- Internal helpers -----------------------------------------------------------

.valid_border_styles <- c("single", "double", "thick", "dash", "dot")

.check_border_side <- function(x, arg = deparse(substitute(x))) {
  if (!is.null(x) && !inherits(x, "rtf_border_side")) {
    stop(sprintf("`%s` must be NULL or an rtf_border_side object.", arg), call. = FALSE)
  }
}

.check_hex_color <- function(color) {
  if (is.null(color)) return(invisible(NULL))
  if (!is.character(color) || length(color) != 1L ||
      !grepl("^#[0-9A-Fa-f]{6}$", color)) {
    stop("`color` must be NULL or a 6-digit hex color string (e.g. \"#FF0000\").",
         call. = FALSE)
  }
}


# -- rtf_border_side ------------------------------------------------------------

#' Single-edge border specification
#'
#' Defines the line style, weight, and colour for one edge of a cell.
#' Use this as an argument to [rtf_border()].
#'
#' @param style Line style.  One of `"single"` (default), `"double"`,
#'   `"thick"`, `"dash"`, `"dot"`, or `"none"`.  Use `"none"` to build an
#'   *explicit no-line* side: unlike `NULL` (which simply leaves a side
#'   unset), a `"none"` side **overrides** any inherited border when it is
#'   merged on top of another spec.  This is how a per-cell border can
#'   remove an automatically-drawn rule -- e.g. suppressing the group
#'   underline under one spanning column-header cell.
#' @param width Line weight in twips.  Default `15` ≈ 0.5 pt.  Ignored when
#'   `style = "none"`.
#' @param color Line colour.  `NULL` (default) = black.  Or a 6-digit hex
#'   string such as `"#003366"`.
#'
#' @return A list of class `"rtf_border_side"`.
#'
#' @seealso [rtf_border()] to assemble sides into a cell border, and
#'   [rtf_table_border()] for whole-table border zones.
#'
#' @examples
#' rtf_border_side()                                   # thin black rule (~0.5 pt)
#' rtf_border_side(style = "double", width = 30L, color = "#003366")
#' rtf_border_side("none")   # explicit "no line" that removes an inherited rule
#' @export
rtf_border_side <- function(style = "single", width = 15L, color = NULL) {
  style <- match.arg(style, c(.valid_border_styles, "none"))
  width <- as.integer(width)
  if (!identical(style, "none") && width < 1L) {
    stop("`width` must be a positive integer (twips).", call. = FALSE)
  }
  .check_hex_color(color)
  structure(
    list(style = style, width = width, color = color),
    class = "rtf_border_side"
  )
}

#' @export
print.rtf_border_side <- function(x, ...) {
  col_str <- if (!is.null(x$color)) paste0(", color=", x$color) else ""
  cat(sprintf("<rtf_border_side: %s, %d twips%s>\n", x$style, x$width, col_str))
  invisible(x)
}


# -- rtf_border ----------------------------------------------------------------

#' Four-edge border specification for a cell or row
#'
#' Specifies borders for up to four sides (top, bottom, left, right).  Each
#' side is either `NULL` (no border) or an [rtf_border_side()] object.
#'
#' To derive a new border from an existing one, use [rtf_border_with()].
#'
#' @param top,bottom,left,right `NULL` (no border on that side) or an
#'   [rtf_border_side()] object.
#'
#' @return A list of class `"rtf_border"`.
#'
#' @examples
#' rtf_border(top = rtf_border_side(), bottom = rtf_border_side())  # top + bottom
#' rtf_border(bottom = rtf_border_side(color = "#003366"))          # blue underline
#' @export
rtf_border <- function(top = NULL, bottom = NULL, left = NULL, right = NULL) {
  .check_border_side(top,    "top")
  .check_border_side(bottom, "bottom")
  .check_border_side(left,   "left")
  .check_border_side(right,  "right")
  structure(
    list(top = top, bottom = bottom, left = left, right = right),
    class = "rtf_border"
  )
}

#' @export
print.rtf_border <- function(x, ...) {
  cat("<rtf_border>\n")
  for (s in c("top", "bottom", "left", "right")) {
    v <- x[[s]]
    if (is.null(v)) {
      cat(sprintf("  %-6s: none\n", s))
    } else {
      col_str <- if (!is.null(v$color)) paste0(", color=", v$color) else ""
      cat(sprintf("  %-6s: %s, %d twips%s\n", s, v$style, v$width, col_str))
    }
  }
  invisible(x)
}

#' Return a copy of an `rtf_border` with selected sides replaced
#'
#' Non-mutating: returns a new `rtf_border` with the supplied side(s) set on
#' top of `border`.  `NULL` arguments leave the corresponding side unchanged.
#'
#' @param border An [rtf_border()] object.  `NULL` is accepted and treated as
#'   an empty border.
#' @param top,bottom,left,right Replacement [rtf_border_side()] values, or
#'   `NULL` to leave a side unchanged.
#'
#' @return A new `rtf_border` object.
#'
#' @examples
#' b <- rtf_border(top = rtf_border_side(), bottom = rtf_border_side())
#' rtf_border_with(b, bottom = rtf_border_side(color = "#003366"))  # recolour bottom
#' rtf_border_with(b, top = rtf_border_side("none"))                # drop the top rule
#' @export
rtf_border_with <- function(border, top = NULL, bottom = NULL,
                            left = NULL, right = NULL) {
  if (is.null(border)) border <- rtf_border()
  if (!inherits(border, "rtf_border")) {
    stop("`border` must be NULL or an rtf_border object.", call. = FALSE)
  }
  .check_border_side(top,    "top")
  .check_border_side(bottom, "bottom")
  .check_border_side(left,   "left")
  .check_border_side(right,  "right")
  if (!is.null(top))    border$top    <- top
  if (!is.null(bottom)) border$bottom <- bottom
  if (!is.null(left))   border$left   <- left
  if (!is.null(right))  border$right  <- right
  border
}


# -- Convenience rtf_border constructors ----------------------------------------

#' @describeIn rtf_border All sides `NULL` (explicit "no border").
#' @export
rtf_border_none <- function() rtf_border()

#' @describeIn rtf_border Top edge only.
#' @param style,width,color Passed to [rtf_border_side()].
#' @export
rtf_border_top <- function(style = "single", width = 15L, color = NULL) {
  rtf_border(top = rtf_border_side(style, width, color))
}

#' @describeIn rtf_border Bottom edge only.
#' @export
rtf_border_bottom <- function(style = "single", width = 15L, color = NULL) {
  rtf_border(bottom = rtf_border_side(style, width, color))
}

#' @describeIn rtf_border All four edges.
#' @export
rtf_border_box <- function(style = "single", width = 15L, color = NULL) {
  s <- rtf_border_side(style, width, color)
  rtf_border(top = s, bottom = s, left = s, right = s)
}


# -- rtf_table_border ----------------------------------------------------------

#' Per-zone border specification for a table
#'
#' Specifies borders for each logical zone of an [rtftable()].
#' Each zone is either `NULL` (no border) or an [rtf_border()] object.
#' `first_row` and `last_row` are *overrides* merged on top of the `body` spec.
#'
#' @param header    [rtf_border()] for column-header rows.  `NULL` = none.
#' @param spanning  [rtf_border()] for spanning-header rows.  `NULL` = none.
#' @param body      [rtf_border()] for data rows.  `NULL` = none.
#' @param first_row [rtf_border()] override for the first data row.
#' @param last_row  [rtf_border()] override for the last data row.
#'
#' @return A list of class `"rtf_table_border"`.
#'
#' @seealso [rtf_border()] / [rtf_border_side()] for the pieces; pass the result
#'   as `rtftable(border = )`.
#'
#' @examples
#' # The clinical TFL look spelled out by zone: header top + bottom rules and a
#' # bottom rule on the last data row (equivalent to `rtftable(border = "tfl")`).
#' rtf_table_border(
#'   header   = rtf_border(top = rtf_border_side(), bottom = rtf_border_side()),
#'   last_row = rtf_border(bottom = rtf_border_side())
#' )
#' @export
rtf_table_border <- function(header    = NULL,
                              spanning  = NULL,
                              body      = NULL,
                              first_row = NULL,
                              last_row  = NULL) {
  zones <- list(header = header, spanning = spanning, body = body,
                first_row = first_row, last_row = last_row)
  for (nm in names(zones)) {
    v <- zones[[nm]]
    if (!is.null(v) && !inherits(v, "rtf_border")) {
      stop(sprintf("`%s` must be NULL or an rtf_border object.", nm), call. = FALSE)
    }
  }
  structure(zones, class = "rtf_table_border")
}

#' @export
print.rtf_table_border <- function(x, ...) {
  cat("<rtf_table_border>\n")
  for (zone in c("header", "spanning", "body", "first_row", "last_row")) {
    if (!is.null(x[[zone]])) {
      sides <- vapply(c("top", "bottom", "left", "right"), function(s) {
        b <- x[[zone]][[s]]
        if (is.null(b)) "none"
        else paste0(b$style, "/", b$width, if (!is.null(b$color)) paste0("/", b$color) else "")
      }, character(1L))
      cat(sprintf("  %-10s: T=%s B=%s L=%s R=%s\n",
                  zone, sides[1], sides[2], sides[3], sides[4]))
    } else {
      cat(sprintf("  %-10s: none\n", zone))
    }
  }
  invisible(x)
}


# -- TFL preset ----------------------------------------------------------------

#' Clinical TFL-style table border preset
#'
#' Returns an [rtf_table_border()] matching the standard clinical TFL style:
#' **borders are applied to the column-header block only**, with no
#' borders in the data area by default.  Specifically:
#'
#' * `header$top`    -- top border on the topmost header row
#' * `header$bottom` -- bottom border on the bottommost header row
#' * A multi-column spanning cell additionally receives a bottom border
#'   (group underline) **only where the column grouping changes below it**
#'   -- that is, when the next header row subdivides the columns the span
#'   covers.  A span repeated unchanged on the following row is not
#'   underlined.  This is added automatically by the renderer.
#' * No vertical lines.
#' * **No borders on the data section** (`body` / `first_row` /
#'   `last_row` all `NULL`).  Callers who want a bottom rule under the
#'   last data row can set it explicitly:
#'   `rtf_table_border(last_row = rtf_border(bottom = rtf_border_side()))`.
#'
#' @inheritParams rtf_border_side
#' @return An `rtf_table_border` object.
#'
#' @examples
#' rtf_border_tfl()                         # the standard clinical TFL rules
#' rtf_border_tfl(width = 30L)              # heavier rules
#' rtftable(data.frame(A = 1:2), border = rtf_border_tfl())
#' @export
rtf_border_tfl <- function(style = "single", width = 15L, color = NULL) {
  s <- rtf_border_side(style, width, color)
  rtf_table_border(
    header   = rtf_border(top = s, bottom = s),
    spanning = NULL,
    body     = NULL,
    first_row = NULL,
    last_row  = NULL
  )
}


# -- Internal conversion helpers -----------------------------------------------

# Convert old plain-list border spec (used by rtftable before the class redesign)
# to rtf_table_border.  The old spec had keys: header, spanning, body,
# first_row, last_row, each a list with top/bottom/left/right string + width.
.plain_list_to_table_border <- function(lst) {
  zones <- c("header", "spanning", "body", "first_row", "last_row")
  result <- vector("list", length(zones))
  names(result) <- zones

  for (zone in zones) {
    spec <- lst[[zone]]
    if (is.null(spec) || length(spec) == 0L) next
    width <- as.integer(spec$width %||% 15L)
    sides <- list()
    for (side in c("top", "bottom", "left", "right")) {
      st <- spec[[side]]
      if (!is.null(st) && !st %in% c("none", "")) {
        sides[[side]] <- rtf_border_side(st, width)
      }
    }
    if (length(sides) > 0L) {
      result[[zone]] <- do.call(rtf_border, sides)
    }
  }
  do.call(rtf_table_border, result)
}

# Merge two rtf_border objects: override sides of `base` with non-NULL sides
# of `over`.  Both arguments are S3 lists; R's copy-on-modify semantics mean
# the caller's `base` is never mutated.
.merge_rtf_border <- function(base, over) {
  if (is.null(base)) return(over)
  if (is.null(over) || length(over) == 0L) return(base)
  for (side in c("top", "bottom", "left", "right")) {
    if (!is.null(over[[side]])) base[[side]] <- over[[side]]
  }
  base
}

# Collect all hex colors from an rtf_border (or NULL).
.collect_border_colors <- function(b) {
  if (is.null(b)) return(character(0))
  cols <- character(0)
  for (side in c("top", "bottom", "left", "right")) {
    c2 <- b[[side]]$color
    if (!is.null(c2)) cols <- c(cols, c2)
  }
  cols
}

# Collect all hex colors from an rtf_table_border (or NULL).
.collect_table_border_colors <- function(tb) {
  if (is.null(tb)) return(character(0))
  cols <- character(0)
  for (zone in c("header", "spanning", "body", "first_row", "last_row")) {
    cols <- c(cols, .collect_border_colors(tb[[zone]]))
  }
  cols
}
