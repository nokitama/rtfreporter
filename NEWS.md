# rtfreporter (development version)

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
