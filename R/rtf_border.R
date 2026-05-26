# rtf_border.R — Border class hierarchy for rtfreporter
#
# Three constructor functions build border specifications used in
# rtf_header(), rtf_footer(), and rtftable():
#
#   rtf_border_side   — one edge (style, width, color)
#   rtf_border        — four edges of a single cell/row
#   rtf_table_border  — per-zone borders for a full table
#
# All return plain lists with a class attribute (not R6).
# See also: specs/api_contract.md § Border class hierarchy


# ── Internal helpers ───────────────────────────────────────────────────────────

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


# ── rtf_border_side ────────────────────────────────────────────────────────────

#' Single-edge border specification
#'
#' Defines the line style, weight, and colour for one edge of a cell.
#' Use this as an argument to [rtf_border()].
#'
#' @param style Line style.  One of `"single"` (default), `"double"`,
#'   `"thick"`, `"dash"`, `"dot"`.
#' @param width Line weight in twips.  Default `15` ≈ 0.5 pt.
#' @param color Line colour.  `NULL` (default) = black.  Or a 6-digit hex
#'   string such as `"#003366"`.
#'
#' @return A list of class `"rtf_border_side"`.
#' @export
rtf_border_side <- function(style = "single", width = 15L, color = NULL) {
  style <- match.arg(style, .valid_border_styles)
  width <- as.integer(width)
  if (width < 1L) stop("`width` must be a positive integer (twips).", call. = FALSE)
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


# ── rtf_border (R6) ────────────────────────────────────────────────────────────
#
# Why R6 here?
#
#   This is the one place where rtfreporter deliberately uses R6 instead of
#   S3 — to demonstrate the *one* feature S3 cannot offer cleanly: a
#   chained builder pattern + shared mutable references.  Users who want to
#   tune a single template and have many tables pick it up automatically
#   benefit from R6 reference semantics.  S3 lists would force a copy.
#
#   Backward compatibility: the R6 object also carries the S3 class name
#   "rtf_border", so existing code using `inherits(x, "rtf_border")` and
#   field access via `x$top` / `x[["top"]]` continues to work unchanged.

#' Four-edge border specification for a cell or row
#'
#' Specifies borders for up to four sides (top, bottom, left, right).  Each
#' side is either `NULL` (no border) or an [rtf_border_side()] object.
#'
#' @param top,bottom,left,right `NULL` or an [rtf_border_side()] object.
#'
#' @return An R6 object of class `rtf_border`.
#' @export
rtf_border <- function(top = NULL, bottom = NULL, left = NULL, right = NULL) {
  rtf_border_class$new(top = top, bottom = bottom, left = left, right = right)
}

# Internal: the R6 class behind rtf_border().
rtf_border_class <- R6::R6Class(
  classname = "rtf_border",
  public = list(
    top    = NULL,
    bottom = NULL,
    left   = NULL,
    right  = NULL,

    initialize = function(top = NULL, bottom = NULL, left = NULL, right = NULL) {
      .check_border_side(top,    "top")
      .check_border_side(bottom, "bottom")
      .check_border_side(left,   "left")
      .check_border_side(right,  "right")
      self$top    <- top
      self$bottom <- bottom
      self$left   <- left
      self$right  <- right
      invisible(self)
    },

    # ── In-place setters (chainable; returns self) ────────────────────────
    # Use these when you are intentionally mutating a shared style template
    # and want every referencing table to see the update.
    set_top    = function(side) { .check_border_side(side, "side"); self$top    <- side; invisible(self) },
    set_bottom = function(side) { .check_border_side(side, "side"); self$bottom <- side; invisible(self) },
    set_left   = function(side) { .check_border_side(side, "side"); self$left   <- side; invisible(self) },
    set_right  = function(side) { .check_border_side(side, "side"); self$right  <- side; invisible(self) },

    # ── Non-mutating builders (returns a fresh clone with one side set) ──
    # Use these in pipe chains where you want to derive a new border from
    # an existing one without altering the original.
    with_top    = function(side) self$clone()$set_top(side),
    with_bottom = function(side) self$clone()$set_bottom(side),
    with_left   = function(side) self$clone()$set_left(side),
    with_right  = function(side) self$clone()$set_right(side),

    # ── Apply an override (mutating) — non-NULL sides of `other` win ────
    apply_override = function(other) {
      if (is.null(other)) return(invisible(self))
      for (side in c("top", "bottom", "left", "right")) {
        if (!is.null(other[[side]])) self[[side]] <- other[[side]]
      }
      invisible(self)
    },

    # ── Non-mutating override — returns a clone with overrides applied ──
    override = function(other) {
      out <- self$clone()
      out$apply_override(other)
      out
    },

    print = function(...) {
      cat("<rtf_border (R6)>\n")
      for (s in c("top", "bottom", "left", "right")) {
        v <- self[[s]]
        if (is.null(v)) {
          cat(sprintf("  %-6s: none\n", s))
        } else {
          col_str <- if (!is.null(v$color)) paste0(", color=", v$color) else ""
          cat(sprintf("  %-6s: %s, %d twips%s\n", s, v$style, v$width, col_str))
        }
      }
      invisible(self)
    }
  )
)

# ── Convenience rtf_border constructors ────────────────────────────────────────

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


# ── rtf_table_border ──────────────────────────────────────────────────────────

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


# ── TFL preset ────────────────────────────────────────────────────────────────

#' Clinical TFL-style table border preset
#'
#' Returns an [rtf_table_border()] matching the standard clinical TFL style:
#' top and bottom borders on the column-header row, bottom border on the last
#' data row, no vertical lines.
#'
#' @inheritParams rtf_border_side
#' @return An `rtf_table_border` object.
#' @export
rtf_border_tfl <- function(style = "single", width = 15L, color = NULL) {
  s <- rtf_border_side(style, width, color)
  rtf_table_border(
    header   = rtf_border(top = s, bottom = s),
    spanning = NULL,
    body     = NULL,
    first_row = NULL,
    last_row  = rtf_border(bottom = s)
  )
}


# ── Internal conversion helpers ───────────────────────────────────────────────

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
# of `over`.  Crucial detail: rtf_border is now R6, which means values are
# passed by reference.  We MUST clone() first, otherwise mutating `base`
# would silently alter every caller that shares the same template.
.merge_rtf_border <- function(base, over) {
  if (is.null(base)) return(over)
  if (is.null(over) || length(over) == 0L) return(base)
  if (inherits(base, "rtf_border") && inherits(base, "R6")) {
    out <- base$clone()
    for (side in c("top", "bottom", "left", "right")) {
      if (!is.null(over[[side]])) out[[side]] <- over[[side]]
    }
    return(out)
  }
  # Legacy plain-list path (shouldn't appear anymore, kept defensively).
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
