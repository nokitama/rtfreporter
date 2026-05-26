# ============================================================================
#  rtf_table_style — shared, mutable style template (R6)
# ============================================================================
#
#  Why R6 here?
#  ------------
#  An `rtf_table_style` is meant to be **shared by many tables**.  Define
#  a single "company TFL theme" once, hand the same instance to dozens of
#  rtftable() calls, and later flip e.g. `style$header_bold <- TRUE` —
#  every referencing table instantly reflects the change.  That is exactly
#  the reference-semantics value-add that R6 brings over S3 lists.
#
#  Why `rtf_border_side` and `rtf_table_border` stay S3
#  ----------------------------------------------------
#  `rtf_border_side` is a tiny immutable value object (style + width +
#  colour).  Copy semantics are entirely appropriate.
#
#  `rtf_table_border` is a passive grouping of `rtf_border`s by zone;
#  it has no mutation methods of its own.  Plain S3 lists keep it
#  introspectable via `str()` / `dput()`.
#
#  Resolution precedence (used by rtftable_r6 / renderer)
#  ------------------------------------------------------
#  At table construction time, rtftable() resolves each setting by walking
#  the chain:
#
#      explicit argument > col_spec entry > style field > package default
#
#  so an explicit rtftable() argument always wins, and a style object
#  merely provides defaults.

#' Shared table style (R6)
#'
#' Holds a bundle of table-wide formatting defaults — borders, alignment,
#' bold, cell padding — that can be **shared by many tables** by passing
#' the same instance to multiple `rtftable()` calls.  Because the object
#' is an R6 reference, mutating it (e.g. `style$header_bold <- TRUE`)
#' propagates to every table that references it at render time.
#'
#' For an immutable derivation, call `style$clone_with(...)` which returns
#' a fresh copy with selected fields replaced.
#'
#' @field border_header,border_spanning,border_body,border_first_row,border_last_row
#'   [rtf_border()] objects (or `NULL`) controlling each zone of the table.
#' @field header_align,header_bold,header_italic Defaults for column-header
#'   row formatting.  `header_align = NULL` means "inherit `align`".
#' @field align,bold,italic Defaults for data-row formatting.
#' @field cell_padding_left_twips,cell_padding_right_twips Cell padding
#'   (twips) used by both column-header and data cells.
#' @field row_height_twips Row height (twips); `NULL` = font-aware default.
#'
#' @examples
#' \dontrun{
#' # Define once
#' tfl_style <- rtf_table_style$new(
#'   border_header   = rtf_border(top = rtf_border_side(), bottom = rtf_border_side()),
#'   border_last_row = rtf_border(bottom = rtf_border_side()),
#'   header_bold     = FALSE,
#'   header_align    = NULL    # inherit data alignment
#' )
#'
#' # Apply to many tables
#' tbls <- lapply(dfs, function(df) rtftable(df, style = tfl_style))
#'
#' # Tweak the theme; every referencing table picks it up at render time
#' tfl_style$header_bold <- TRUE
#' }
#'
#' @export
rtf_table_style <- R6::R6Class(
  classname = "rtf_table_style",
  public = list(
    # ── Zone borders ──────────────────────────────────────────────────────
    border_header    = NULL,
    border_spanning  = NULL,
    border_body      = NULL,
    border_first_row = NULL,
    border_last_row  = NULL,

    # ── Column-header text defaults ───────────────────────────────────────
    header_align  = NULL,   # NULL ⇒ inherit data align in col_spec
    header_bold   = FALSE,
    header_italic = FALSE,

    # ── Data-row text defaults ────────────────────────────────────────────
    align     = "left",
    bold      = FALSE,
    italic    = FALSE,
    underline = FALSE,

    # ── Cell metrics ──────────────────────────────────────────────────────
    cell_padding_left_twips  = NULL,
    cell_padding_right_twips = NULL,
    row_height_twips         = NULL,

    initialize = function(
      border_header    = NULL,
      border_spanning  = NULL,
      border_body      = NULL,
      border_first_row = NULL,
      border_last_row  = NULL,
      header_align     = NULL,
      header_bold      = FALSE,
      header_italic    = FALSE,
      align            = "left",
      bold             = FALSE,
      italic           = FALSE,
      underline        = FALSE,
      cell_padding_left_twips  = NULL,
      cell_padding_right_twips = NULL,
      row_height_twips         = NULL
    ) {
      .check_border <- function(b, nm) {
        if (!is.null(b) && !inherits(b, "rtf_border")) {
          stop(sprintf("`%s` must be NULL or an rtf_border object.", nm),
               call. = FALSE)
        }
      }
      .check_border(border_header,    "border_header")
      .check_border(border_spanning,  "border_spanning")
      .check_border(border_body,      "border_body")
      .check_border(border_first_row, "border_first_row")
      .check_border(border_last_row,  "border_last_row")

      self$border_header    <- border_header
      self$border_spanning  <- border_spanning
      self$border_body      <- border_body
      self$border_first_row <- border_first_row
      self$border_last_row  <- border_last_row

      self$header_align  <- header_align
      self$header_bold   <- isTRUE(header_bold)
      self$header_italic <- isTRUE(header_italic)

      self$align     <- align
      self$bold      <- isTRUE(bold)
      self$italic    <- isTRUE(italic)
      self$underline <- isTRUE(underline)

      self$cell_padding_left_twips  <- cell_padding_left_twips
      self$cell_padding_right_twips <- cell_padding_right_twips
      self$row_height_twips         <- row_height_twips

      invisible(self)
    },

    # ── Non-mutating derivation: return a clone with named fields replaced ─
    # Demonstrates how R6 inheritance / cloning lets users build derived
    # themes without affecting the parent.
    clone_with = function(...) {
      overrides <- list(...)
      out <- self$clone()
      for (nm in names(overrides)) {
        if (!nm %in% ls(out, all.names = FALSE)) {
          stop(sprintf("Unknown style field: '%s'", nm), call. = FALSE)
        }
        out[[nm]] <- overrides[[nm]]
      }
      out
    },

    # ── Convert this R6 style into the rtf_table_border S3 spec consumed
    # by the renderer's existing border pipeline.
    as_table_border = function() {
      rtf_table_border(
        header    = self$border_header,
        spanning  = self$border_spanning,
        body      = self$border_body,
        first_row = self$border_first_row,
        last_row  = self$border_last_row
      )
    },

    print = function(...) {
      cat("<rtf_table_style (R6)>\n")
      cat("  borders:\n")
      for (z in c("header", "spanning", "body", "first_row", "last_row")) {
        v <- self[[paste0("border_", z)]]
        cat(sprintf("    %-10s: %s\n", z, if (is.null(v)) "none" else "<rtf_border>"))
      }
      cat(sprintf("  header_align : %s\n",
                  if (is.null(self$header_align)) "(inherit align)" else self$header_align))
      cat(sprintf("  header_bold  : %s\n", self$header_bold))
      cat(sprintf("  align        : %s\n", self$align))
      cat(sprintf("  bold         : %s\n", self$bold))
      cat(sprintf("  cell_padding : L=%s R=%s\n",
                  self$cell_padding_left_twips  %||% "(default)",
                  self$cell_padding_right_twips %||% "(default)"))
      invisible(self)
    }
  )
)

# Built-in TFL theme as an R6 style.  Returns a *fresh* instance each call
# so callers can mutate without affecting other call sites.
#
#' Clinical TFL preset (R6 style)
#'
#' Returns a freshly constructed `rtf_table_style` matching the standard
#' clinical TFL preset: borders are applied to the **column-header
#' block only** (top on the topmost header row, bottom on the
#' bottommost; multi-col spanning auto-underlines).  **The data section
#' carries no borders by default.**  No vertical lines.  No bold
#' headers.
#'
#' Callers who want a bottom rule under the last data row can set it
#' explicitly after construction:
#' `style$border_last_row <- rtf_border(bottom = rtf_border_side())`.
#'
#' @return An `rtf_table_style` R6 object.
#' @export
rtf_table_style_tfl <- function() {
  s <- rtf_border_side()
  rtf_table_style$new(
    border_header = rtf_border(top = s, bottom = s),
    header_bold   = FALSE,
    header_align  = NULL    # inherit data alignment
  )
}
