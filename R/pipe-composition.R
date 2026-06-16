# Pipe Composition API for rtfreporter
# S3-based immutable composition interface for building RTF reports with pipes (%>%)
#
# This is the primary public API. Build a document by piping rtf_document()
# through rtf_tables(), rtf_section(), format functions, then generate_rtfreport().

# ============================================================================
# Utility: NULL-coalescing operator
# ============================================================================

# NULL-coalescing operator: returns a if not NULL, otherwise b
`%||%` <- function(a, b) if (!is.null(a)) a else b

# ============================================================================
# S3 Constructor: rtf_document()
# ============================================================================

#' Create an RTF document for pipe composition
#'
#' Initialize a new RTF document object for building reports with pipes.
#' Provides sensible defaults for clinical trial reports.
#'
#' `rtf_document()` is the **constructor**: it starts a new, empty document and
#' supplies a default for anything you do not specify. To **change settings on a
#' document you have already composed** -- one that already holds content and
#' sections -- use [rtf_config()] instead, which alters only the keys you pass
#' and leaves the content untouched. In short: `rtf_document()` *builds a new*
#' document from defaults; `rtf_config()` *edits an existing* one in place. The
#' two are complementary, not interchangeable -- you cannot change the page of
#' an already-composed report with `rtf_document()` without discarding its
#' content.
#'
#' @param font_table Optional font table. Default: list(list(name = "Courier"))
#' @param color_table Optional vector of `"#RRGGBB"` colours to pre-declare in
#'   the document's colour table (so they are available by index). Default
#'   `c("#000000")`. Colours used by borders and by `col_spec`/`cell_styles`
#'   `color` are added automatically, so you only need this to declare colours
#'   you reference elsewhere. Black/white are reserved and added implicitly.
#' @param page Optional page settings as a named list. Recognised keys (all in
#'   inches unless noted): `paper_size` (a named preset, see below),
#'   `orientation` (`"landscape"` / `"portrait"`), `width_in`, `height_in`,
#'   `margin_top_in` / `margin_bottom_in` / `margin_left_in` / `margin_right_in`,
#'   and `header_dist_in` / `footer_dist_in` (distance of the header/footer band
#'   from the page edge; when omitted, each defaults to half the corresponding
#'   top/bottom margin). Default: landscape letter, margins 0.9 inch
#'   (top/bottom) and 0.6 inch (left/right).
#'
#'   These defaults are read from the `rtfreporter.*` options, so a site can
#'   change them in `Rprofile.site` (see [rtfreporter_options()]); an explicit
#'   key here always wins.
#'
#'   `paper_size` selects a named preset (case-insensitive): `"letter"`
#'   (8.5x11"), `"legal"` (8.5x14"), `"A4"` (210x297mm), `"A3"`, `"A5"`. So
#'   `list(paper_size = "A4")` gives **A4 landscape** in one line, and
#'   `list(paper_size = "A4", orientation = "portrait")` gives A4 portrait.
#'
#'   Geometry is resolved as follows: (1) explicit `width_in` / `height_in`
#'   **win** and are used as given -- the orientation is *inferred* from them
#'   (`width_in >= height_in` means landscape); an explicit `orientation` that
#'   contradicts the dimensions emits a warning and the dimensions are kept as
#'   given (not swapped). If `paper_size` is also supplied it is ignored (with a
#'   warning). (2) Otherwise `paper_size` + `orientation` selects and orients a
#'   preset. (3) Otherwise the default (landscape letter) is used.
#' @param default_format Optional document-wide default formatting (a list,
#'   merged per key). Recognised keys:
#'   * `font_size_half_points` -- body font size in half-points (18 = 9 pt).
#'   * `row_height_twips` -- document-wide default **row height** for every
#'     table-shaped element (content table, page header/footer, title/footnote).
#'     `NULL` keeps the font-aware default.
#'   * `cell_padding_left_twips`, `cell_padding_right_twips` -- document-wide
#'     default **cell padding** (border-to-text distance), likewise applied to
#'     every element.
#'   * `markup` -- document-wide default cell-text **markup** (`"script"`,
#'     `"relational"`, `"all"`, or `"none"`; default `"script"`). Controls
#'     whether `^{}`/`_{}` render as super/subscript and whether `>=`/`<=` are
#'     converted to the `>=`/`<=` symbols. A per-table `rtftable(markup = )`
#'     overrides it. See [rtftable()].
#'   These are **defaults**: a per-module value -- `rtftable()` /
#'   `rtf_header()` / `rtf_footer()` / `rtf_table_style()` -- always overrides
#'   them. They can also be set globally as `rtfreporter.*` options (see
#'   [rtfreporter_options()]).
#'
#' @return An rtf_document object (S3 class) with structure:
#'   - document: list(font_table, color_table, page, default_format)
#'   - contents: list (initially empty, populated by rtf_tables/rtf_figures)
#'   - sections: list (initially empty, populated by rtf_section)
#'
#' @examples
#' \dontrun{
#' doc <- rtf_document()
#' }
#'
#' @export
rtf_document <- function(font_table = NULL, color_table = NULL, page = NULL,
                         default_format = NULL) {
  # Default clinical trial page used when none is supplied.  A *partial* `page`
  # is kept as given; any key left out (orientation, dimensions, margins) is
  # resolved to its default at render time -- including inferring the
  # orientation from the dimensions when it is omitted (see .orient_page()).
  if (is.null(page)) {
    page <- list(
      paper_size       = .opt("rtfreporter.page.paper_size"),
      orientation      = .opt("rtfreporter.page.orientation"),
      margin_top_in    = .opt("rtfreporter.page.margin_top_in"),
      margin_bottom_in = .opt("rtfreporter.page.margin_bottom_in"),
      margin_left_in   = .opt("rtfreporter.page.margin_left_in"),
      margin_right_in  = .opt("rtfreporter.page.margin_right_in")
    )
  }

  if (is.null(font_table)) {
    font_table <- list(list(name = .opt("rtfreporter.font")))
  }

  if (is.null(color_table)) {
    color_table <- c("#000000")
  }

  # Create immutable S3 object
  doc <- structure(
    list(
      document = list(
        font_table = font_table,
        color_table = color_table,
        page = page,
        default_format = default_format
      ),
      contents  = list(),
      titles    = list(),
      footnotes = list(),
      sections  = list()
    ),
    class = "rtf_document"
  )

  doc
}

# ============================================================================
# rtf_config() - Document-level settings
# ============================================================================

#' Configure document-level settings
#'
#' Update the **document-level** settings (font, colour, page, default format)
#' of an existing `rtf_document`, leaving its content, titles and sections
#' untouched. Only the arguments you pass are changed (`NULL` = no change).
#'
#' The point of `rtf_config()` is *deriving variants from an already-composed
#' document*. Build the report once -- add tables/figures and sections -- then
#' produce alternative outputs (a different paper size, font, or default text
#' size) by changing only the relevant setting and rendering each copy. Because
#' an `rtf_document` is immutable, each call returns a fresh copy and the
#' original is left intact, so the variants are independent.
#'
#' `page` and `default_format` are **merged per key**: passing
#' `page = list(width_in = 8.27, height_in = 11.69)` changes only those two keys
#' and keeps the document's existing orientation and margins. `font_table` and
#' `color_table` are replaced as a whole.
#'
#' @param doc An rtf_document object.
#' @param font_table Optional font table; replaces the current one.
#' @param color_table Optional colour table; replaces the current one.
#' @param page Optional page settings list (see [rtf_document()]); merged per
#'   key onto the current page settings.
#' @param default_format Optional document-wide default formatting; merged per
#'   key onto the current defaults. Recognised keys: `font_size_half_points`,
#'   `row_height_twips`, `cell_padding_left_twips`, `cell_padding_right_twips`
#'   (see [rtf_document()]). These are document-wide **defaults** that any
#'   per-module setting overrides.
#'
#' @return Modified rtf_document object (new copy, original unchanged).
#'
#' @examples
#' # Compose once, then render two paper-size variants from the SAME content.
#' base <- rtf_document() |>
#'   rtf_tables(data.frame(Parameter = "Age", Value = "75.1")) |>
#'   rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL))
#'
#' letter <- base                                   # landscape Letter (default)
#' a4     <- base |> rtf_config(page = list(width_in = 11.69, height_in = 8.27))
#'
#' # Only the page changed; the content/section are shared.
#' identical(letter$contents, a4$contents)
#'
#' @export
rtf_config <- function(doc, font_table = NULL, color_table = NULL, page = NULL,
                       default_format = NULL) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }

  # Create a copy (immutable pattern)
  doc_copy <- doc

  # Whole-object replacements.
  if (!is.null(font_table)) {
    doc_copy$document$font_table <- font_table
  }
  if (!is.null(color_table)) {
    doc_copy$document$color_table <- color_table
  }
  # Per-key merges, so "change only the paper size" keeps the other page keys.
  if (!is.null(page)) {
    doc_copy$document$page <- .merge_list(doc_copy$document$page, page)
  }
  if (!is.null(default_format)) {
    doc_copy$document$default_format <-
      .merge_list(doc_copy$document$default_format, default_format)
  }

  doc_copy
}

# ============================================================================
# Content Addition: rtf_tables() and rtf_figures()
# ============================================================================

#' Add content pages to document
#'
#' Append one or more content items as pages. **Each element of `tables`
#' becomes exactly one page**, holding a single table or figure.
#'
#' Table-formatting arguments (`col_rel_width`, `border`, `row_height_twips`,
#' ...) accepted by this function are used to build any bare `data.frame`
#' element of `tables`, and -- when passed **explicitly** -- also override the
#' matching field of any pre-built `rtftable()` element (for example the
#' output of [as_rtftables()]).  Arguments left at their default are not
#' applied to pre-built tables, so those keep their own / gt-derived settings.
#' `rtfplot()` elements are never modified.  (The `style` argument seeds
#' construction-time defaults only; it is not applied as an override to a
#' pre-built table.)
#'
#' @param doc An rtf_document object.
#' @param tables A list where each element is one page's content. Each
#'   element must be one of:
#'   - `data.frame`: simple table; the table-format arguments below apply.
#'   - `rtftable` object (from `rtftable()`): table with full formatting.
#'   - `rtfplot` object (from `rtfplot()`): embedded figure.
#'   - `gt_tbl` object (from the gt package): converted via
#'     `as.data.frame()` and treated like a `data.frame`. Pass
#'     `read_gt = TRUE` (or a vector of tokens) to also pull through
#'     gt's column labels, alignment, title/subtitle, and source notes.
#'     See `read_gt` below.
#'   - **gtsummary table** (`tbl_summary`, `tbl_regression`, `tbl_merge`,
#'     `tbl_stack`, etc.): automatically converted to a `gt_tbl` via
#'     `gtsummary::as_gt()` before any further processing. Pass
#'     `read_gt = TRUE` to pull through column labels, titles, source
#'     notes, footnotes, spanning headers, and hidden-column removal.
#'     Note: cell-level formatting (row indentation, bold group-header
#'     rows, footnote marks in cells) is **not** transferred to RTF.
#'     See [as_rtftable()] for details on gtsummary limitations.
#' @param col_rel_width,column_widths_twips,table_width_twips,table_width_pct_of_writable,table_width_pct,table_align Column-width and table-width settings applied to bare `data.frame` elements. See [rtftable()] for details.
#' @param col_header,col_header_align,spanning_header,col_spec,row_title,border,blank_rows,read_attributes,style Per-table content settings applied to bare `data.frame` elements. `row_title` names the row-heading columns (default: column 1) and sets the per-column default alignment (heading columns left, others centre). See [rtftable()] for details.
#' @param row_height_twips,row_height_exact,header_row_height_twips,blank_row_height_twips Row-height settings applied to bare `data.frame` elements. See [rtftable()] for details.
#' @param cell_padding_left_twips,cell_padding_right_twips,cell_valign Cell layout settings applied to bare `data.frame` elements. See [rtftable()] for details.
#' @param blank_row_normalize Blank-row normalisation applied to bare
#'   `data.frame` elements (default `c("detect", "collapse")`): `"detect"`
#'   renders an all-empty data row as a single full-width blank row, `"collapse"`
#'   reduces a run of consecutive blank rows to one. Pre-built `rtftable()`
#'   pages keep their own setting. See [rtftable()] for details.
#' @param markup Cell-text markup applied to bare `data.frame` elements
#'   (`"script"` super/subscript, `"relational"` `>=`/`<=` symbols, `"all"`,
#'   `"none"`). `NULL` (default) inherits the document default (`"script"`).
#'   Pre-built `rtftable()` pages keep their own setting. See [rtftable()].
#' @param titles `NULL` (default) or a list of length `length(tables)` **or
#'   length 1** (a single block applied to every page). Each element is a
#'   title **block**: either a character vector (one entry per row, default
#'   styling) or a list of rows, where a row is a string or a styled
#'   `list(text=, align=, bold=, italic=, underline=, color=, border=)`. An
#'   empty string (`""`) is a blank row. The block renders as a single-column
#'   table the same width as the content (so it lines up); title rows default
#'   to centred + bold.
#' @param footnotes `NULL` (default) or a list of length `length(tables)` or
#'   length 1 (common to all). Same block structure as `titles`; footnote rows
#'   default to left-aligned, and the first row carries a top rule (the
#'   separator) unless that row sets its own `border`.
#' @param auto_section Logical. When `TRUE` and `tables` is a **named** list,
#'   each name is used as a per-section heading appended to the common header
#'   defined by `rtf_section(secinfo = ...)` (called without a `page` argument).
#'   The document is then automatically split into one RTF section per named
#'   element. Unnamed items fall through to the previous section.
#'   Default `FALSE`.
#' @param section_label_align Alignment for the auto-appended section label row.
#'   One of `"left"` (default), `"center"`, or `"right"`.
#' @param read_gt **Legacy.**  Controls metadata extraction when a raw
#'   `gt_tbl` is handed *directly* to `rtf_tables()` (no pagination).  For
#'   new code, prefer converting up front with [as_rtftables()], which
#'   paginates *and* reads metadata, then pass the resulting list here --
#'   the page-level titles / footnotes flow through automatically (via the
#'   `rtf_titles` / `rtf_footnotes` attributes) with `read_gt` left at its
#'   default.  Allowed values:
#'   * `FALSE` (default) -- treat `gt_tbl` items as a rendered body only;
#'     ignore titles / labels / source notes.
#'   * `TRUE` -- read the render-relevant metadata: column labels,
#'     per-column alignment, spanning headers, widths, plus the page-level
#'     title / subtitle and footnote / source notes.  See [as_rtftables()]
#'     for the full *What is carried, by source* table.
#'   * A character vector of tokens -- selective opt-in.  See
#'     [as_rtftables()] for the token list.
#'   Explicit `rtf_tables()` / `rtf_titles()` / `rtf_footnotes()`
#'   values always override gt-extracted ones.
#'
#' @return Modified rtf_document with appended contents.
#'
#' @examples
#' \dontrun{
#' df1 <- data.frame(A = 1:3, B = c("x", "y", "z"))
#' df2 <- data.frame(A = 4:6, B = c("p", "q", "r"))
#'
#' # Three pages, shared formatting applied to both bare data.frames
#' doc <- rtf_document() %>%
#'   rtf_tables(
#'     list(df1, df2, rtfplot("fig.png")),
#'     col_rel_width    = c(1, 2),
#'     border           = "tfl",
#'     row_height_twips = 280L
#'   )
#' }
#'
#' @export
rtf_tables <- function(doc, tables,
                        col_header = NULL,
                        col_header_align = NULL,
                        spanning_header = NULL,
                        col_spec = NULL,
                        row_title = NULL,
                        border = "tfl",
                        blank_rows = NULL,
                        read_attributes = TRUE,
                        style = NULL,
                        col_rel_width = NULL,
                        column_widths_twips = NULL,
                        table_width_twips = NULL,
                        table_width_pct_of_writable = NULL,
                        table_width_pct = NULL,
                        table_align = "left",
                        row_height_twips = NULL,
                        row_height_exact = FALSE,
                        header_row_height_twips = NULL,
                        blank_row_height_twips = NULL,
                        cell_padding_left_twips = NULL,
                        cell_padding_right_twips = NULL,
                        cell_valign = "bottom",
                        blank_row_normalize = c("detect", "collapse"),
                        markup = NULL,
                        titles = NULL,
                        footnotes = NULL,
                        auto_section = FALSE,
                        section_label_align = "left",
                        read_gt = FALSE) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }

  # Auto-wrap a single content item so callers can write rtf_tables(tbl)
  # instead of rtf_tables(list(tbl)).  data.frame is IS a list in R, so it
  # needs an explicit guard; everything else that is not already a plain list
  # (rtftable, rtfplot, gt_tbl, gtsummary) is wrapped too.
  if (is.data.frame(tables) || !is.list(tables) ||
      inherits(tables, "rtftable") || inherits(tables, "rtfplot") ||
      .is_gt_tbl(tables) || .is_gtsummary_tbl(tables)) {
    tables <- list(tables)
  }

  # Which table-formatting arguments did the caller pass EXPLICITLY?  These
  # override the corresponding fields of any pre-built rtftable item (e.g.
  # the output of as_rtftables()); arguments left at their default do not
  # touch the rtftable's own / gt-derived values.  Detection via match.call()
  # so we can tell "passed border = 'tfl'" from "defaulted to 'tfl'".
  .fmt_args <- c("col_header", "col_header_align", "spanning_header",
                 "col_spec", "row_title", "border", "blank_rows", "style",
                 "col_rel_width", "column_widths_twips", "table_width_twips",
                 "table_width_pct_of_writable", "table_width_pct",
                 "table_align", "row_height_twips", "row_height_exact",
                 "header_row_height_twips", "blank_row_height_twips",
                 "cell_padding_left_twips", "cell_padding_right_twips",
                 "cell_valign")
  .explicit <- intersect(names(match.call())[-1L], .fmt_args)
  .overrides <- if (length(.explicit))
                  mget(.explicit, envir = environment()) else list()

  .is_content_item <- function(x) {
    is.data.frame(x) ||
      inherits(x, "rtftable") ||
      inherits(x, "rtfplot") ||
      .is_gt_tbl(x) ||
      .is_gtsummary_tbl(x)
  }

  # Validate each page-level item: exactly one content per page.
  for (i in seq_along(tables)) {
    item <- tables[[i]]
    if (!.is_content_item(item)) {
      stop("Item ", i,
           " must be a data.frame, rtftable(), rtfplot(), gt_tbl, or",
           " gtsummary table object. ",
           "Each list element corresponds to exactly one page (one content).",
           call. = FALSE)
    }
  }

  # -- gtsummary pre-conversion: gtsummary tables -> gt_tbl ---------------
  # Done before gt extraction so the existing gt pipeline handles them
  # uniformly.  Conversion uses gtsummary::as_gt() (the package's own
  # rendering layer); no gtsummary-internal slots are read directly.
  for (i in seq_along(tables)) {
    if (.is_gtsummary_tbl(tables[[i]])) {
      tables[[i]] <- .gtsummary_to_gt(tables[[i]])
    }
  }

  # -- gt_tbl handling: extract requested attributes ----------------------
  # `read_gt` is normalised once; the resolved token vector is used both
  # for per-table extraction and for the page-level title / source-note
  # pull-through done after table promotion.
  gt_tokens   <- .resolve_gt_tokens(read_gt)
  gt_extracts <- vector("list", length(tables))
  for (i in seq_along(tables)) {
    if (.is_gt_tbl(tables[[i]])) {
      gt_extracts[[i]] <- .gt_to_rtftable_kwargs(tables[[i]], tokens = gt_tokens)
      # Replace the gt_tbl in `tables` with its rendered data.frame so
      # the downstream loop treats it like a bare data.frame.
      tables[[i]] <- gt_extracts[[i]]$data
    }
  }

  # Promote bare data.frames to rtftable using the supplied formatting args.
  # NB: iterate over indices (not items) so we can look up the matching
  # gt_extracts slot per page.  We restore the original names() afterwards.
  tables_names <- names(tables)
  tables <- lapply(seq_along(tables), function(i) {
    item <- tables[[i]]
    if (is.data.frame(item)) {
      # If this slot originated from a gt_tbl, merge the extracted
      # col_header / col_spec / column_widths_twips / col_rel_width
      # into the user-supplied arguments (user always wins).
      gtx <- gt_extracts[[i]]
      eff_col_header <- if (!is.null(col_header))    col_header
                       else if (!is.null(gtx) && !is.null(gtx$col_header))
                         gtx$col_header
                       else NULL
      eff_col_spec   <- if (!is.null(gtx) && !is.null(gtx$col_spec))
                         .merge_col_spec(col_spec, gtx$col_spec)
                       else col_spec
      eff_col_widths <- if (!is.null(column_widths_twips))
                         column_widths_twips
                       else if (!is.null(gtx) && !is.null(gtx$column_widths_twips))
                         gtx$column_widths_twips
                       else NULL
      eff_col_rel    <- if (!is.null(col_rel_width))
                         col_rel_width
                       else if (!is.null(gtx) && !is.null(gtx$col_rel_width))
                         gtx$col_rel_width
                       else NULL
      # Phase D: cell_styles from gt extraction (user has no rtf_tables()-level
      # override; cell_styles can only be set on individual rtftable() objects).
      eff_cell_styles <- if (!is.null(gtx)) gtx$cell_styles else NULL
      rtftable(
        data                        = item,
        col_header                  = eff_col_header,
        col_header_align            = col_header_align,
        spanning_header             = spanning_header,
        col_spec                    = eff_col_spec,
        row_title                   = row_title,
        border                      = border,
        blank_rows                  = blank_rows,
        read_attributes             = read_attributes,
        style                       = style,
        col_rel_width               = eff_col_rel,
        column_widths_twips         = eff_col_widths,
        table_width_twips           = table_width_twips,
        table_width_pct_of_writable = table_width_pct_of_writable,
        table_width_pct             = table_width_pct,
        table_align                 = table_align,
        row_height_twips            = row_height_twips,
        row_height_exact            = row_height_exact,
        header_row_height_twips     = header_row_height_twips,
        blank_row_height_twips      = blank_row_height_twips,
        cell_padding_left_twips     = cell_padding_left_twips,
        cell_padding_right_twips    = cell_padding_right_twips,
        cell_valign                 = cell_valign,
        cell_styles                 = eff_cell_styles,
        blank_row_normalize         = blank_row_normalize,
        markup                      = markup
      )
    } else if (inherits(item, "rtftable")) {
      # Pre-built rtftable (e.g. from as_rtftables()): apply only the
      # explicitly-passed rtf_tables() formatting arguments as overrides;
      # everything else keeps the table's own / gt-derived settings.
      .override_rtftable_fields(item, .overrides)
    } else {
      item   # rtfplot or anything else passes through untouched
    }
  })
  names(tables) <- tables_names

  # When auto_section = TRUE, wrap each named item in an rtf_auto_section_item
  # sentinel so that .pipe_doc_to_r6_report() can build per-section headers.
  if (isTRUE(auto_section)) {
    tbl_names <- names(tables)
    if (!is.null(tbl_names) && any(nzchar(tbl_names))) {
      tables <- lapply(seq_along(tables), function(i) {
        nm <- tbl_names[[i]]
        if (!is.null(nm) && nzchar(nm)) {
          structure(
            list(content = tables[[i]], label = nm,
                 label_align = section_label_align),
            class = "rtf_auto_section_item"
          )
        } else {
          tables[[i]]
        }
      })
    }
  }

  # Validate titles / footnotes lengths
  .validate_parallel <- function(x, n, name) {
    if (is.null(x)) return(rep(list(NULL), n))
    if (!is.list(x)) {
      stop(sprintf("`%s` must be a list (or NULL).", name), call. = FALSE)
    }
    if (length(x) == 1L && n > 1L) return(rep(x, n))  # one block = common to all
    if (length(x) != n) {
      stop(sprintf("`%s` must have length %d (= length(tables)) or 1 (common to all).",
                   name, n), call. = FALSE)
    }
    x
  }
  titles    <- .validate_parallel(titles,    length(tables), "titles")
  footnotes <- .validate_parallel(footnotes, length(tables), "footnotes")

  # Pull through page-level title / source-note blocks.  Two sources, in
  # priority order (user-supplied `titles` / `footnotes` always win over
  # both):
  #   1. `rtf_titles` / `rtf_footnotes` attributes on a pre-built rtftable
  #      item -- this is how as_rtftables() carries gt's title / source
  #      notes onto each page.
  #   2. gt_extracts blocks, for a raw gt_tbl handed directly to rtf_tables()
  #      with read_gt = (legacy path).
  for (i in seq_along(tables)) {
    item <- tables[[i]]
    a_titles    <- attr(item, "rtf_titles",    exact = TRUE)
    a_footnotes <- attr(item, "rtf_footnotes", exact = TRUE)
    gtx <- gt_extracts[[i]]
    if (is.null(titles[[i]])) {
      if (!is.null(a_titles))                          titles[[i]] <- a_titles
      else if (!is.null(gtx) && !is.null(gtx$titles_block))
                                                       titles[[i]] <- gtx$titles_block
    }
    if (is.null(footnotes[[i]])) {
      if (!is.null(a_footnotes))                       footnotes[[i]] <- a_footnotes
      else if (!is.null(gtx) && !is.null(gtx$footnotes_block))
                                                       footnotes[[i]] <- gtx$footnotes_block
    }
  }

  # Create copy and append
  doc_copy <- doc
  doc_copy$contents  <- c(doc_copy$contents,  tables)
  doc_copy$titles    <- c(doc_copy$titles,    titles)
  doc_copy$footnotes <- c(doc_copy$footnotes, footnotes)
  doc_copy
}

#' Add figure content to document
#'
#' Append one or more image files (PNG/JPEG) as content pages. Each figure
#' creates one new page. Display dimensions and alignment apply to every
#' bare path in `figures`; elements already constructed via [rtfplot()] keep
#' their own settings.
#'
#' @param doc An rtf_document object.
#' @param figures A list whose elements are either character file paths to
#'   image files (PNG/JPEG) or pre-built `rtfplot` objects from [rtfplot()].
#' @param width_twips Display width in twips for bare paths.  `NULL` = full
#'   writable width.
#' @param height_twips Display height in twips for bare paths.  `NULL` =
#'   derived from the image's aspect ratio.
#' @param align Horizontal alignment for bare paths: `"center"` (default),
#'   `"left"`, or `"right"`.
#' @param titles,footnotes Optional lists of length `length(figures)` or
#'   length 1 (common to all figures). See [rtf_tables()] for the block
#'   structure (character vectors or per-row styled lists).
#'
#' @return Modified rtf_document with appended figure contents.
#'
#' @examples
#' \dontrun{
#' doc <- rtf_document() |>
#'   rtf_figures(list("scatter.png"), width_twips = 6000L, align = "center")
#' }
#'
#' @export
rtf_figures <- function(doc, figures,
                         width_twips = NULL, height_twips = NULL,
                         align = "center",
                         titles = NULL, footnotes = NULL) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }

  if (!is.list(figures)) {
    stop("`figures` must be a list of file paths or rtfplot() objects",
         call. = FALSE)
  }

  # Validate and promote each element to rtfplot.
  fig_objs <- lapply(seq_along(figures), function(i) {
    fig <- figures[[i]]
    if (inherits(fig, "rtfplot")) {
      return(fig)
    }
    if (!is.character(fig) || length(fig) != 1L) {
      stop("Item ", i,
           " must be a single character file path or an rtfplot() object",
           call. = FALSE)
    }
    rtfplot(path = fig, width_twips = width_twips,
            height_twips = height_twips, align = align)
  })

  .validate_parallel <- function(x, n, name) {
    if (is.null(x)) return(rep(list(NULL), n))
    if (!is.list(x))
      stop(sprintf("`%s` must be a list (or NULL).", name), call. = FALSE)
    if (length(x) == 1L && n > 1L) return(rep(x, n))  # one block = common to all
    if (length(x) != n)
      stop(sprintf("`%s` must have length %d (= length(figures)) or 1 (common to all).",
                   name, n), call. = FALSE)
    x
  }
  titles    <- .validate_parallel(titles,    length(figures), "titles")
  footnotes <- .validate_parallel(footnotes, length(figures), "footnotes")

  doc_copy <- doc
  doc_copy$contents  <- c(doc_copy$contents,  fig_objs)
  doc_copy$titles    <- c(doc_copy$titles,    titles)
  doc_copy$footnotes <- c(doc_copy$footnotes, footnotes)
  doc_copy
}

# ============================================================================
# rtf_titles() / rtf_footnotes() -- assign titles / footnotes to pages
# ============================================================================

#' Assign content titles to pages
#'
#' Replace the per-page title list with the supplied values.  `titles` must
#' have length equal to the number of pages already added via [rtf_tables()] /
#' [rtf_figures()], **or length 1** -- a single block is then applied to every
#' page (common title).
#'
#' Each element is a title **block**: either a character vector (one entry per
#' row, default styling) or a list of rows, where a row is a string or a styled
#' `list(text=, align=, bold=, italic=, underline=, color=, border=)`. An empty
#' string (`""`) is a blank row. The block renders as a single-column table the
#' same width as the content; title rows default to centred + bold.
#'
#' @param doc An rtf_document object.
#' @param titles A list of length = number of pages, or length 1 (common).
#'
#' @return Modified rtf_document.
#'
#' @examples
#' \dontrun{
#' doc <- rtf_document() %>%
#'   rtf_tables(list(df1, df2)) %>%
#'   rtf_titles(list(
#'     c("Table 14.1.1", "{HALF_BLANK_ROW}", "Safety Population"),
#'     "Table 14.1.2"
#'   ))
#' }
#'
#' @export
rtf_titles <- function(doc, titles) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }
  n <- length(doc$contents)
  if (n == 0L) {
    stop("Cannot set titles before any content has been added.", call. = FALSE)
  }
  if (!is.list(titles)) {
    stop("`titles` must be a list (one element per page).", call. = FALSE)
  }
  if (length(titles) == 1L && n > 1L) titles <- rep(titles, n)  # common to all
  if (length(titles) != n) {
    stop(sprintf("`titles` must have length %d (= number of pages) or 1 (common to all).",
                 n), call. = FALSE)
  }
  doc_copy <- doc
  doc_copy$titles <- titles
  doc_copy
}

#' Assign content footnotes to pages
#'
#' Same shape as [rtf_titles()]: a list with one block per page (or length 1,
#' common to all). Each block is a character vector or a list of rows (a string
#' or `list(text=, align=, bold=, italic=, underline=, color=, border=)`).
#' Footnote rows default to left-aligned, and the first row carries a top rule
#' (the separator) unless that row sets its own `border`. `NULL` per element
#' suppresses the footnote for that page.
#'
#' @param doc An rtf_document object.
#' @param footnotes A list of length = number of pages, or length 1 (common).
#'
#' @return Modified rtf_document.
#'
#' @examples
#' df <- data.frame(A = 1:2, B = c("x", "y"))
#' doc <- rtf_document() |>
#'   rtf_tables(df) |>
#'   rtf_footnotes(list(c("Source: ADaM ADSL")))
#'
#' @export
rtf_footnotes <- function(doc, footnotes) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }
  n <- length(doc$contents)
  if (n == 0L) {
    stop("Cannot set footnotes before any content has been added.", call. = FALSE)
  }
  if (!is.list(footnotes)) {
    stop("`footnotes` must be a list (one element per page).", call. = FALSE)
  }
  if (length(footnotes) == 1L && n > 1L) footnotes <- rep(footnotes, n)  # common to all
  if (length(footnotes) != n) {
    stop(sprintf("`footnotes` must have length %d (= number of pages) or 1 (common to all).",
                 n), call. = FALSE)
  }
  doc_copy <- doc
  doc_copy$footnotes <- footnotes
  doc_copy
}

# ============================================================================
# Section Definition: rtf_section()
# ============================================================================

#' Define sections for pages
#'
#' Map page numbers to sections with headers/footers.
#' Pages are automatically numbered based on content order (starting at 1).
#'
#' @param doc An rtf_document object.
#' @param page Integer or vector of page numbers to assign this section.
#'   - Single integer: one section starts at this page
#'   - Vector: assign multiple pages to sections (length must match secinfo)
#' @param secinfo Section information (one or more section definitions):
#'   - Single section: list(header = ..., footer = ...)
#'   - Multiple sections: list(sec1, sec2, ...) where each is a section list
#'
#' @return Modified rtf_document with section definitions added.
#'
#' @details
#' The `page` parameter identifies where each section starts. Pages are
#' auto-numbered from your content list (rtf_tables and rtf_figures).
#'
#' @examples
#' \dontrun{
#' doc <- rtf_document() %>%
#'   rtf_tables(list(df1, df2, df3)) %>%
#'   rtf_section(page = 1, secinfo = list(header = h1, footer = f1)) %>%
#'   rtf_section(page = 3, secinfo = list(header = h2, footer = f2))
#' }
#'
#' @export
rtf_section <- function(doc, page = NULL, secinfo) {
  if (!inherits(doc, "rtf_document")) {
    stop("`doc` must be an rtf_document object", call. = FALSE)
  }

  # Handle page = NULL: store as "_default" template used by auto_section.
  if (is.null(page)) {
    doc_copy <- doc
    doc_copy$sections[["_default"]] <- secinfo
    return(doc_copy)
  }

  # Normalize page to character for list indexing
  page <- as.character(page)

  # Create copy
  doc_copy <- doc

  # Handle single vs. multiple sections
  if (length(page) == 1) {
    # Single section
    if (is.list(secinfo) && !is.null(secinfo$header) || !is.null(secinfo$footer)) {
      # secinfo is a single section
      doc_copy$sections[[page]] <- secinfo
    } else if (is.list(secinfo) && length(secinfo) > 0 &&
               (is.list(secinfo[[1]]) || is.null(secinfo[[1]]))) {
      # secinfo might be a wrapped section or empty list
      doc_copy$sections[[page]] <- secinfo
    } else {
      stop("secinfo must be a list with header/footer fields", call. = FALSE)
    }
  } else {
    # Multiple pages, possibly multiple sections
    if (!is.list(secinfo)) {
      stop("When page is a vector, secinfo must be a list of section objects",
           call. = FALSE)
    }

    # Check if secinfo is a list of sections or a single section
    # If first element is a list (looks like a section), assume list of sections
    if (length(page) > 1 && length(secinfo) > 0) {
      if (is.list(secinfo[[1]]) || is.null(secinfo[[1]])) {
        # Likely list of section objects
        if (length(page) != length(secinfo)) {
          stop("Length of page (", length(page), ") must match length of secinfo (",
               length(secinfo), ")", call. = FALSE)
        }

        for (i in seq_along(page)) {
          doc_copy$sections[[page[i]]] <- secinfo[[i]]
        }
      } else {
        # Single section dict applied to all pages
        for (p in page) {
          doc_copy$sections[[p]] <- secinfo
        }
      }
    }
  }

  doc_copy
}

# ============================================================================
# S3 Methods for printing
# ============================================================================

#' Print an rtf_document object
#'
#' @param x An rtf_document object.
#' @param ... Additional arguments (unused).
#'
#' @return `x`, invisibly. Called for the side effect of printing a one-line
#'   summary (page count, sections defined, page size).
#'
#' @examples
#' print(rtf_document())
#'
#' @export
print.rtf_document <- function(x, ...) {
  cat("rtf_document object\n")
  cat("  Pages:", length(x$contents), "\n")
  cat("  Sections defined:", length(x$sections), "\n")
  cat("  Document page size:", x$document$page$width_in, "x",
      x$document$page$height_in, "inches\n")
  invisible(x)
}
