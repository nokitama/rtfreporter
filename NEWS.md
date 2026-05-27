# rtfreporter (development version)

## rtfreporter 0.0.22

### New features

* **`paginate()` — unified table-object to per-page data.frame list**
  ([#2](https://github.com/ichirio/rtfreporter/issues/2)).  Single S3
  entry point that converts a [gt::gt()] table, a plain `data.frame`,
  or a `list` of either into a list of data.frames sized for one
  RTF page each, ready to be passed to `rtf_tables()`.

  Splitting strategies:

  - `split = "none"` (default) — pass through as a single page.
  - `split = "rows"` — manual force-split at the row indices in
    `split_rows`.
  - `split = "group_safe"` — pack whole groups onto each page; spill on
    overflow.  A single group larger than `max_rows` is force-split
    with `(Cont.)` continuation rows.
  - `split = "group_force"` — cut every `max_rows`; when a cut lands
    inside a group, the next page begins with a `<label> (Cont.)`
    header row whose summary value cells are blanked out.

  Groups are either auto-detected from leading-whitespace indentation
  on the first column (default) or specified explicitly via
  `group_col =`.

  Blank-row positions can be supplied as an integer vector, as the
  keyword `"between_groups"` (auto-inserts a blank between detected
  groups), or as a `list(...)` combining both.  Positions are
  attached as an `rtf_blank_rows` attribute on each returned
  data.frame and consumed automatically by
  `rtftable(read_attributes = TRUE)`.

  Extending to a new table-object type is one S3 method:

  ```r
  paginate.your_class <- function(x, ...) {
    df <- ...extract a data.frame from x...
    paginate.data.frame(df, ...)
  }
  ```

  Added to `Suggests:`: `gt (>= 0.9.0)`.

## rtfreporter 0.0.21

### New features

* **Unified column-header API.** Multi-row column headers can now be
  written in a single uniform form using `pos =` cell specs, regardless
  of whether the top-most row is a spanning row or a plain label row.
  Previously the first row had to use either `col_header` (no spanning)
  or `spanning_header` (separate argument); now spanning at every level
  (including the first) is expressed the same way.

  - `col_cell(pos, label, ...)` — one cell.  `pos = 1` is a single
    column; `pos = c(2, 5)` spans data columns 2–5.  Positions always
    refer to the underlying data columns.
  - `rtf_col_header(row1, row2, ...)` — collect rows top-to-bottom.
  - `add_col_header_row(hdr, row, .position = c("bottom", "top"))` —
    incremental builder.

  Example:

  ```r
  rtftable(df, col_header = rtf_col_header(
    list(col_cell(1, ""), col_cell(c(2, 5), "Treatment")),
    list(col_cell(1, ""),
         col_cell(c(2, 3), "Drug A"),
         col_cell(c(4, 5), "Drug B")),
    c("Item", "N", "Mean", "N", "Mean")
  ))
  ```

  A bare list of `col_cell()`s is auto-wrapped as a single header row,
  so `col_header = list(col_cell(1, "Item"), col_cell(c(2, 3), "M (SD)"))`
  works.

  All previously-accepted forms (`c("A", "B", "C")`, mixed lists with
  `list(from, to, label, ...)` specs, and the standalone
  `spanning_header =` argument) continue to work unchanged.

### Default changes (potentially visible to existing reports)

* **Cell padding default lowered to 0 twips** (was 72 twips ≈ 0.05 inch
  on both sides).  Header, footer and content-table cells now sit flush
  against the cell border by default, matching the typical clinical
  TFL look.  Callers who want the old behaviour can opt in:
  `rtftable(..., cell_padding_left_twips = 72L, cell_padding_right_twips = 72L)`.
  Reflected in `inst/resources/rtfreporter_defaults.R`.
* **Document margins enlarged ~20%** to give a little more breathing
  room around the writable area:
    * top / bottom: 0.75 inch → **0.9 inch**
    * left / right: 0.5 inch → **0.6 inch**
  Callers passing explicit page metrics are unaffected.

## rtfreporter 0.0.20

### Infrastructure

* Added a `pkgdown` site published to GitHub Pages at
  <https://ichirio.github.io/rtfreporter/>.
* Migrated the test suite from bare `tests/test-*.R` scripts to
  `testthat` (edition 3) under `tests/testthat/`.
* Added GitHub Actions workflows for `R CMD check` (Ubuntu, macOS,
  Windows × R-release / devel / oldrel-1), `pkgdown` deployment, and
  test coverage reporting via `covr` + Codecov.
* `DESCRIPTION` modernised: full author/maintainer information, `URL`,
  `BugReports`, expanded `Description`, `Depends: R (>= 4.1)`, and
  optional `Suggests:` for `testthat` and `covr`.
* `LICENSE` converted to CRAN's `YEAR` / `COPYRIGHT HOLDER` template
  with the full MIT text moved to `LICENSE.md`.
* `README.md` rewritten with installation instructions, a runnable
  30-second example, and badges.
* Community files added: `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`,
  GitHub issue and pull-request templates.

## rtfreporter 0.0.19

### Breaking changes

* **Removed all R6 usage.** `rtftable_r6`, `rtfplot_r6`, `rtfreport_r6`,
  and the R6 versions of `rtf_border` and `rtf_table_style` are now
  plain S3 records. The class names lose the `_r6` suffix
  (`inherits(x, "rtftable")` etc.). `Imports: R6` was dropped from
  `DESCRIPTION`.
* The R6 method chains `b$set_top()` / `b$with_top()` /
  `b$apply_override()` / `b$override()` / `style$clone_with()` /
  `style$as_table_border()` are gone. Replacements:
  - `rtf_border_with(b, top = ..., bottom = ..., ...)` for
    non-mutating border derivation.
  - `rtf_table_style_with(style, ...)` for non-mutating style
    derivation.
  - `rtf_table_style(...)` is now called as a function (not
    `rtf_table_style$new(...)`).
* The "share a style instance, mutate it, see every existing table
  reflect the change" pattern no longer applies. Each `rtftable()`
  call snapshots the style fields it needs at construction time. Build
  a new style with `rtf_table_style_with()` and pass it to new tables.

### Other

* Public S3 print methods are now exported for `rtf_border`,
  `rtf_border_side`, `rtf_table_border`, and `rtf_table_style`.

## rtfreporter 0.0.18

* Data section now has **no default borders**. The TFL preset
  `rtf_border_tfl()` no longer paints a horizontal rule under the last
  data row; default borders belong to the column-header block only.
  Callers who want a bottom rule under the last data row can still set
  it explicitly:
  `rtf_table_border(last_row = rtf_border(bottom = rtf_border_side()))`.

## Earlier versions

See [`CHANGELOG.md`](CHANGELOG.md) for the detailed pre-v0.0.18
history.
