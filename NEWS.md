# rtfreporter (development version)

## rtfreporter 0.0.40

### gt integration -- Phase C (completes the v0.1.0 roadmap)

Adds the final two `read_gt = ...` tokens from
`specs/gt-integration-spec.md`.  Combined with Phase A (v0.0.38) and
Phase B (v0.0.39), the GT bridge now supports **all nine** documented
tokens.  `read_gt = TRUE` automatically expands to the full set.

* **`"footnotes"`** -- table-level only.  Every `tab_footnote()`
  text (regardless of its anchor: column label, body cell,
  standalone, etc.) is flattened to plain text and prepended to the
  page footnote block.  When `"source_notes"` is also active,
  footnote texts come ABOVE source notes -- matching gt's vertical
  layout.  **Cell-mark injection is deferred to a later release.**

* **`"stub"`** -- two transformations:
    1. The groupname column (`gt(df, groupname_col = ...)`,
       boxhead `type == "row_group"`) is dropped from the data.
       Group-transition rows are then interleaved into the body
       wherever `_stub_df$group_id` changes; each transition row
       carries the group label in the leftmost cell.
    2. `tab_stubhead(label = ...)` is applied as the first
       column's header label, overriding any cols_label value for
       the stub column.

  Combines cleanly with `"hidden"` (both can drop columns) and with
  `"spanning"` (stubhead label lands on the bottom-row labels under
  the spanner stack).

### Vignette

`vignettes/gt-integration.Rmd` walks through the full workflow: a
quick-start, a TFL-style adverse-events example end-to-end (group
rows + stubhead + spanners + footnotes + source note), and the
explicit-argument precedence rules.

### Test additions

`tests/testthat/test-gt-adapter.R` gains 21 new tests for Phase C:
the two new extractors individually, the row-interleaver, four
`.gt_to_rtftable_kwargs()` integration paths (footnotes-only,
footnotes+source_notes, stub+col_header, stub+spanning, stub+hidden),
and one full end-to-end render with `read_gt = TRUE` that exercises
every Phase A/B/C token at once.

Full suite: 1092 PASS / 0 FAIL.

## rtfreporter 0.0.39

### gt integration -- Phase B

Adds the three "structural" tokens from `specs/gt-integration-spec.md`
on top of the Phase A vocabulary:

* **`"spanning"`** -- multi-level spanner labels from
  `gt_obj[["_spanners"]]` are stacked as additional rows ABOVE the
  column labels in `col_header`.  Higher `spanner_level` -> drawn
  higher in the rendered header.  Spanners that cover non-contiguous
  visible columns are skipped (rtfreporter requires contiguity).
* **`"widths"`** -- per-column widths from
  `gt_obj[["_boxhead"]]$column_width` are translated to one of:
  - `column_widths_twips` (when all values are `"NNpx"`), using
    1 px = 15 twips (the 96 dpi CSS convention).
  - `col_rel_width` (when all values are `"NN%"`).
  - `NULL` otherwise (mixed, missing, or unparsable).
* **`"hidden"`** -- columns whose `_boxhead$type == "hidden"` are
  dropped from the extracted data.frame, the column labels, the
  alignment vector, the widths, and the spanner column-index
  mapping (so spanner rows stay aligned with the visible columns).

`read_gt = TRUE` now expands to *all seven* Phase-A + Phase-B tokens
(was four).  Adding spanning / widths / hidden tokens is automatic
when upgrading: code that already wrote `read_gt = TRUE` becomes
strictly more powerful with no source changes.

Two-way independence:

* `"hidden"` can be used by itself -- it just shrinks the data.
* `"spanning"` without `"col_header"` falls back to using the data
  column names as the bottom row of the header stack.
* `"widths"` without `"hidden"` keeps the gt width vector at its
  original length; the renderer fails fast if the count mismatches
  the data.frame.

Precedence is unchanged: explicit `rtf_tables()` /
`rtftable()` arguments always beat the gt-extracted values, including
the new `column_widths_twips` / `col_rel_width` slots.

Test additions: 36 new tests in `tests/testthat/test-gt-adapter.R`
covering the three new extractors, the token resolver's new return
shape, three end-to-end render checks (including a combined
spanner + hidden + widths integration), and the precedence rule
for every new slot.

## rtfreporter 0.0.38

### gt integration -- Phase A (preparing v0.1.0)

This release lays down the first slice of the
[gt](https://gt.rstudio.com) -> rtfreporter bridge described in
`specs/gt-integration-spec.md`.  A `gt_tbl` can now be passed straight
into `rtf_tables()`, and the package optionally reads four
"shape-preserving" gt attributes:

* **`col_header`** -- column labels from `gt_obj[["_boxhead"]]$column_label`
* **`alignment`**  -- per-column alignment from
  `gt_obj[["_boxhead"]]$column_align`
* **`titles`**     -- title + subtitle from `gt_obj[["_heading"]]`,
                      mapped to the page's `titles[[i]]` block
* **`source_notes`** -- source notes from
  `gt_obj[["_source_notes"]]`, mapped to the page's `footnotes[[i]]` block

#### New API

```r
# Accept a gt_tbl directly; pull every Phase-A attribute through.
doc |> rtf_tables(list(my_gt), read_gt = TRUE)

# Selective opt-in.
doc |> rtf_tables(list(my_gt), read_gt = c("col_header", "titles"))

# Standalone wrapper (returns a plain rtftable).
as_rtftable(my_gt, read = TRUE)
```

`read_gt = FALSE` (the new default) keeps every gt_tbl item treated as
a bare data.frame via `as.data.frame()` -- backward-compatible with
v0.0.37 code that already paginated gt's *rendered* table.

#### Precedence

Explicit `rtf_tables()` / `rtf_titles()` / `rtf_footnotes()` arguments
always beat the gt-extracted values.  Per-column `col_spec` entries
are deep-merged: a user-supplied `align = "left"` for column 1
overrides gt's column 1 alignment but leaves gt's alignment in
place for columns the user did not mention.

#### Forward compatibility

Tokens for Phase B (`"spanning"`, `"widths"`, `"hidden"`) and Phase C
(`"footnotes"`, `"stub"`) are recognised today but currently emit a
"not yet implemented" warning and are silently dropped.  Code written
against the full token list will Just Work once those phases land.

`gt` stays in `Suggests` -- the bridge guards with
`requireNamespace("gt")` and raises a clear error if a `gt_tbl` is fed
in without gt installed.  The 18 new tests in
`tests/testthat/test-gt-adapter.R` skip cleanly when gt is absent.

## rtfreporter 0.0.37

### Bug fix: phantom rule under header on assembled file's first page

When `assemble_rtf(toc = ...)` produced an assembled deliverable, the
first page of every source-file body section showed a faint horizontal
rule directly under the page header.

Root cause: `.insert_bookmark()` placed the bookmark/outline paragraph
**between `\sectd` and the section's page-property + header/footer
declarations**.  RTF parsers treat a paragraph emitted in that window
as part of the **previous** section's flow, so any lingering paragraph
state from the previous section's last paragraph (typically a footnote
with `\brdrt\brdrs\brdrw15`) bled onto the new section's header band
and was rendered as a thin rule.

The fix advances the insertion point past the section preamble
(`\sectd`, `\sbkpage...`, `{\header ...}`, `{\footer ...}`) so the
bookmark and outline paragraph land in the new section's BODY where
they belong.

### Hardened invisibility: `\sl1\slmult0` exact line spacing

The outline paragraph now also emits `\sl1\slmult0` -- exact line
spacing of 1 twip (~1/1440 inch).  This pins the paragraph's rendered
height to ~0 px regardless of the converter's `\fs` interpretation,
guaranteeing the outline label cannot push a borderline-fitting
table from one page onto a second.  `\cf2\fs2` are retained as
belt-and-braces (white text + 1-pt size).

### ydisctools alignment audit -- what we kept and what we adopted

After auditing Yenu's `ydisctools::assemble_rtf()` for the proven-good
RTF idioms, the conclusions are:

* **Adopted** -- white-on-white invisibility via `\cf2` (v0.0.36) and
  exact-line-spacing belt-and-braces (v0.0.37).
* **Adopted in spirit** -- bookmark + outline paragraph placed in a
  position that does not bleed into the new section's header band.
  (We place them AFTER the section preamble; ydisctools places them
  BEFORE `\sectd`.  Both approaches avoid the bleed; placement after
  preamble keeps the anchor on the correct page for `PAGEREF`
  resolution.)
* **Kept rtfreporter** -- multi-level `toc_heading()` / `toc_entry()`
  layout, `PAGEREF` fields for dynamic TOC page numbers (ydisctools
  bakes them statically), `\*\fldinst` per the RTF spec, full
  per-page static `{PAGE}` token support.

## rtfreporter 0.0.36

### Outline label is now hidden via white-on-white (`\cf2\fs2`)

v0.0.35 set the PDF-outline label to `\fs0` (font size 0) hoping for
zero rendered height.  **LibreOffice interprets `\fs0` as "use
default"** and renders the label at the body font size (~12 pt), which
made the source-file title appear *twice* near the top of each table
section.

Re-investigating Yenu's `ydisctools` showed the actual invisibility
mechanism there is `\cf<white>` (white text colour), not `\fs0`.
rtfreporter v0.0.36 adopts the same approach:

* `.build_color_table_rtf()` now always emits **white at colour-table
  index 2** (between black at 1 and any user colours at 3+).
* `.build_color_index_map()` shifts user colour indices by +2 so the
  hex-to-index lookup remains correct.
* `.insert_bookmark()` (assemble_rtf) renders the outline label with
  `\cf2\fs2` — white text at 1 pt — inside a balanced `{ ... }`
  group.  White-on-white is invisible regardless of the PDF
  converter's `\fs0` interpretation, and 1 pt keeps the line height
  to ~1 px so no vertical space leaks either.

Verified: the LibreOffice-rendered `output/demo/*_assembled_*.pdf`
files no longer show the source-file title above each body section,
and the PDF outline (bookmark panel) still lists all three sources.

## rtfreporter 0.0.35

### Outline label is now fully invisible (`\fs0`)

`.insert_bookmark()`'s outline-label paragraph now uses `\fs0` (font
size 0) instead of `\fs2` (1 pt).  v0.0.31's 1-pt text was faintly
visible at the top of each source-file body section; the new size-0
text occupies no rendered space at all while LibreOffice still
recognises the paragraph as a heading via `\outlinelevel`, so the PDF
outline / bookmark panel is unchanged.

This matches the trick used by Yenu's `ydisctools` (which combines
`\fs0` with a white `\cf` colour for double safety).

The corresponding regression test in `tests/testthat/test-assemble-rtf.R`
was updated to expect the `\fs0`-shaped balanced group.

## rtfreporter 0.0.34

### Bug fix: `{PAGE}` now increments across sub-pages of one rtf_section

In v0.0.32 `{PAGE}` was correctly switched from a dynamic field to a
static integer, but it baked the **rtf_section's first-page number**
into the header text — and an `rtf_section` whose `rtf_tables()` adds
multiple sub-pages emitted a single RTF `\header` block shared across
all of them.  Result: every sub-page in such a section showed "Page 1"
instead of 1, 2, 3, …

`generate_rtfreport()` now detects when a header or footer contains
`{PAGE}` and promotes every sub-page boundary inside that
rtf_section from a `\page` break to a `\sect` break, re-emitting
`\sectd` + page settings + `{\header}` + `{\footer}` for each sub-page
with the correct baked-in number.  AUTO-only headers stay on the cheap
one-`\header`-per-rtf_section path (no extra section breaks emitted).

Three new tests in `tests/testthat/test-page-tokens.R` lock the
behaviour:
* "Page 1 of 3", "Page 2 of 3", "Page 3 of 3" all present in a single
  3-sub-page section,
* `\sect` breaks are emitted at every sub-page boundary,
* AUTO-only headers still emit zero internal `\sect` breaks.

## rtfreporter 0.0.33

### Bug fix: character-format leak from cover / TOC / outline paragraphs

When `assemble_rtf()` was called with `cover = list(...)` or `toc = ...`,
the front-matter paragraphs emitted bare character-format properties
that bled across `\par` into the following body content:

* `.insert_bookmark()` emitted `\pard\plain\fs2\sa0\sb0\outlinelevel0 LABEL\par`
  — the `\fs2` (1-pt) outline-paragraph font carried forward into the
  body table, shrinking every cell's text to invisible.
* `.build_cover_section()` and `.build_toc_section()` emitted
  `\pard\qc\b\fs44 TEXT\b0\fs0\par` — the closing `\fs0` (size 0)
  similarly leaked.

The visible symptom: assembled PDFs / RTFs rendered table **borders**
correctly, but every cell appeared empty.  The pre-v0.0.31 (no-cover,
no-outline) path was unaffected, which is why older outputs looked fine.

Every formatted paragraph in `.insert_bookmark()`, `.build_cover_section()`,
and `.build_toc_section()` is now wrapped in an RTF `{ ... }` group, so
its character-format state is local and cannot bleed into adjacent
content.  Regression tests in `tests/testthat/test-assemble-rtf.R`
lock the fix down structurally.

### Demo script — both no-cover and with-cover variants

`output/gen_assemble_demo.R` now produces **four** assembled outputs:

* `auto_assembled_default.{rtf,pdf}`   — AUTO sources, TOC only (no cover)
* `auto_assembled_full.{rtf,pdf}`      — AUTO sources, cover + TOC
* `static_assembled_default.{rtf,pdf}` — STATIC sources, TOC only (no cover)
* `static_assembled_full.{rtf,pdf}`    — STATIC sources, cover + TOC

The "default" variants reflect the common eCTD deliverable layout
where a cover page is *not* attached and the TOC alone serves as the
front matter.  No change to `assemble_rtf()`'s own default — `cover = NULL`
has always been the default.

## rtfreporter 0.0.32

### Bug fix: `{PAGE}` is now a STATIC integer (was incorrectly dynamic)

Previously `{PAGE}` was substituted with RTF's `\chpgn` dynamic field —
identical to `{AUTO_PAGE}`.  This contradicted the documented spec, which
states that `{PAGE}` should be a **static** integer baked in at render
time (the section's first-page number).  Effectively `{PAGE}` and
`{AUTO_PAGE}` produced indistinguishable output, defeating the purpose of
having two separate tokens.

`generate_rtfreport()` now substitutes `{PAGE}` with the literal
first-page number of the section being rendered.  Combined with the
already-static `{TOTAL_PAGES}`, the documented `Page {PAGE} of
{TOTAL_PAGES}` idiom now correctly emits e.g. `Page 1 of 3` as
literal text.

Token semantics — recap:

| Token                 | Kind    | Resolves to                       |
|-----------------------|---------|-----------------------------------|
| `{AUTO_PAGE}`         | dynamic | `\chpgn` (per-page, viewer)       |
| `{AUTO_TOTAL_PAGES}`  | dynamic | NUMPAGES field (viewer)           |
| `{SECTION_PAGES}`     | dynamic | SECTIONPAGES field (viewer)       |
| `{PAGE}`              | static  | section's first-page integer      |
| `{TOTAL_PAGES}`       | static  | document total page integer       |

A new `tests/testthat/test-page-tokens.R` file locks these semantics
with 7 dedicated tests.  `output/gen_assemble_demo.R` was rewritten to
produce two independent demo sets (an AUTO-only set and a STATIC-only
set), each with its own TOC/cover/PDF — reflecting realistic deployment
where a deliverable uses one numbering style throughout.

## rtfreporter 0.0.31

### `assemble_rtf()` — PDF outline / bookmark panel support

When `toc` is supplied, `assemble_rtf()` now also emits a tiny
`\outlinelevel0` paragraph next to each per-file bookmark.  RTF
viewers ignore it for display purposes (1-pt font, no surrounding
spacing), but RTF→PDF converters such as **LibreOffice** translate
the `\outlinelevel` mark into a real **PDF outline entry** — i.e.,
the bookmark panel on the left edge of an Adobe Reader / Word
window.  This makes the assembled deliverable navigable in PDF
form, satisfying a common eCTD leaf-file expectation.

The outline label is taken from the corresponding `toc_entry()`'s
`label` when present; otherwise it falls back to
`sub(".rtf$", "", basename(file))`.  `toc = NULL` emits no outline
paragraphs (output is unchanged from v0.0.30).

### Static `{TOTAL_PAGES}` documented + tested across assembly

Tests now lock the two distinct token semantics in
`assemble_rtf()`:

* **`{AUTO_PAGE}` / `{AUTO_TOTAL_PAGES}` / `{PAGE}`** — all emit
  RTF *dynamic field codes* (`\chpgn` and `NUMPAGES`).  They
  recompute correctly across the assembled document.
* **`{TOTAL_PAGES}`** — baked into the source as a literal integer
  at render time.  After assembly it still reflects only the
  source file's own page count (the documented limitation).

## rtfreporter 0.0.30

### `assemble_rtf()` — multi-level TOC, auto-extraction, cover page, page numbering

Building on v0.0.29's clickable TOC, this release covers the
remaining requests for a full deliverable-package workflow.

**`toc = "auto"`** — auto-extract each input file's title (the
first centred-bold paragraph emitted by `.render_title_text()`)
and use it as a TOC entry.  Falls back to the file's basename if
no title is detected.

```r
assemble_rtf(c("t14_1_1.rtf", "t14_2_1.rtf"), "out.rtf",
             toc = "auto", overwrite = TRUE)
```

**Structured / multi-level TOC** via two new helper constructors:

* **`toc_heading(label, level)`** — non-clickable section heading
  rendered bold without a page number.
* **`toc_entry(label, file, level)`** — clickable entry pointing
  to a per-source-file bookmark.  `file =` can be a path that
  appears in `input_files`, an integer 1-based index, or `NULL`
  (consume the next file in declaration order).

```r
assemble_rtf(
  c("t14_1_1.rtf", "t14_2_1.rtf", "l16_1.rtf"),
  "tfl_package.rtf",
  toc = list(
    toc_heading("EFFICACY ANALYSES"),
    toc_entry("Table 14.1.1 Demographics"),       # auto-bound to file 1
    toc_heading("SAFETY ANALYSES"),
    toc_entry("Table 14.2.1 Adverse Events"),     # auto-bound to file 2
    toc_heading("LISTINGS"),
    toc_entry("Listing 16.1 Subject Disposition") # auto-bound to file 3
  ),
  overwrite = TRUE
)
```

**`toc_page_numbering`** controls how the TOC pages number themselves:

* `"none"` (default) — Arabic numbering flows continuously
  from page 1 (TOC counts as page 1, body continues from there).
* `"roman"` — TOC pages use lowercase Roman numerals (i, ii, iii);
  body restarts at 1 with Arabic numerals.
* `"decimal"` — TOC pages and body pages each start at 1.

The body-restart is achieved by injecting `\pgnrestart\pgndec`
right after the first body section's `\sectd`.

**`cover = list(...)`** — optional cover page section before the
TOC.  Recognised fields: `title`, `subtitle`, `date`, `version`,
`meta` (character vector).  Each is rendered as a centred line
with size hierarchy (title 22pt → meta 10pt).  Any field that is
`NULL` or empty is silently skipped.

```r
assemble_rtf(
  c("t14_1_1.rtf", "t14_2_1.rtf"),
  "tfl_package.rtf",
  cover = list(
    title    = "Study XYZ-001",
    subtitle = "Final Statistical Report",
    date     = "2026-05-29",
    version  = "v1.0",
    meta     = c("Confidential", "Prepared by ACME Pharma")
  ),
  toc                = "auto",
  toc_page_numbering = "roman",
  overwrite          = TRUE
)
```

### Backward compatibility

`toc = NULL` AND `cover = NULL` AND `toc_page_numbering = "none"`
still produces a byte-for-byte identical output to the v0.0.28
behaviour — locked by a regression test.

## rtfreporter 0.0.29

### `assemble_rtf()` — clickable Table of Contents + bookmarks

`assemble_rtf()` gains a TOC option for the common "deliverable
package" workflow.  Pass a character vector of labels (one per
input file) to render a clickable Table of Contents on the front
page of the assembled document:

```r
assemble_rtf(
  input_files = c("t14_1_1.rtf", "t14_2_1.rtf", "l16_1.rtf"),
  output_file = "tfl_package.rtf",
  toc         = c("Table 14.1.1 Demographics",
                  "Table 14.2.1 Adverse Events",
                  "Listing 16.1 Subject Disposition"),
  overwrite   = TRUE
)
```

* Each TOC entry is an **RTF `HYPERLINK` field** pointing to a
  per-source-file bookmark inserted right after that section's
  `\sectd`.  Clicking the entry in Word / Pages jumps to the
  corresponding table.
* Each row also ends with a `PAGEREF` field, so the page number
  next to each entry is **calculated by the viewer** when the file
  opens — no hard-coded numbers, no stale TOC.
* Bookmark names auto-derive from each input file's basename
  (sanitised to `^[A-Za-z][A-Za-z0-9_]{0,31}$`).  Duplicate-name
  clashes (two files called `x.rtf` in different folders) are
  resolved automatically with `_1` / `_2` suffixes.
* `toc_leader = "dot"` (default) draws a dotted leader between
  each label and its page number; `"none"` leaves whitespace.
* `bookmark_prefix` (default `"tfl_"`) lets you namespace
  bookmarks when later combining multiple assembled outputs.

The pre-existing call shape (`assemble_rtf(input_files,
output_file, overwrite)`) is unchanged.  `toc = NULL` (the
default) produces a byte-for-byte identical output to the
pre-v0.0.29 behaviour — covered by a regression test.

The originally-proposed *combined-document page number in the
footer* feature was **withdrawn**: injecting it into the existing
footer would shift the rest of the footer downward, and a separate
footer band would clash with the source documents' own footers.
Use `{AUTO_PAGE}` / `{AUTO_TOTAL_PAGES}` in your `rtf_footer()`
when you generate each source file instead — those are dynamic
fields that already recompute across the assembled document.

## rtfreporter 0.0.28

### Coverage lift — Phase 1 of 3 (67% → 73%)

Backfill of the four files that were at 0% coverage:

* `R/assemble_rtf.R` (0% → **95%**) — five new tests cover the
  happy path (2-file and N-file concatenation), input-count
  validation, missing-file detection, overwrite guard, and
  rejection of non-rtfreporter RTFs (no `\sectd`).
* `R/rtfplot.R` (0% → **56%**) — six new tests cover construction
  from a PNG, propagation of `width_twips` / `height_twips` /
  `align`, file-not-found / unsupported-extension errors,
  invalid-align rejection, and end-to-end embedding into a
  generated RTF via `rtf_figures()` (checking the output contains
  `\pict` and `\pngblip`).  A 74-byte hand-rolled 1x1 RGB PNG is
  constructed inside the test, so no graphics device is required.
* `R/text_width.R` (0% → **93%**) — eleven new tests cover
  `text_width_in()` (length parity, NA handling, linear scaling
  with character count, scaling with `size_half_points`, font
  variants including unknown-font fallback) and `auto_col_widths()`
  (per-column integer widths, exact scaling to `table_width_twips`,
  header-text inclusion, `min_col_width_twips` floor, pipe-string
  header).
* `R/zzz.R` (0% → **100%**) — four new tests cover the `.onLoad`
  hook's namespace presence, its idempotent re-invocation, the
  populated `.rtf_theme_class` R6 generator after package load,
  and the no-op re-init via `.init_rtf_theme_class()`.

Per-file post-Phase-1 coverage:

  R/wrappers.R                   100%
  R/zzz.R                        100%
  R/assemble_rtf.R                95%
  R/plot.R                        94%
  R/text_width.R                  93%
  R/format_count_pct.R            93%
  R/set_blank_rows.R              92%
  R/paginate.R                    90%
  R/blank_rows.R                  78%
  R/generate_rtfreport.R          77%
  R/pipe-composition.R            75%
  R/rtf_table_style.R             75%
  R/rtftable.R                    66%
  R/rtfreport.R                   62%
  R/col_header.R                  59%
  R/rtfplot.R                     56%
  R/rtf_border.R                  52%
  R/rtf_theme.R                   15%
  TOTAL                          73.04%

53 new test expectations; total **455 PASS** under `devtools::test()`.

### Codecov floor locked at 70%

`codecov.yml` switched the project-level status from
`informational: true / target: auto` to `informational: false /
target: 70%`.  Any PR that drops total coverage below 70% will now
fail the CI check, preventing silent erosion as new features land.

Phase 2 (target 80%) and Phase 3 (target 90%) will land closer to
v0.1.0 / v0.2.x respectively.

## rtfreporter 0.0.27

### `format_count_pct()` — right-align the 100% branch

The 100% branch used to render `" 30 (100) "` (closing paren in
column 9, trailing space at column 10), so it did not line up with
the other paren-bearing branches.  It now renders `" 30  (100)"` —
an extra space before `(` so the closing paren sits at column 10
just like `" 14 (50.0)"` and `"  5  (5.0)"`.  All paren-bearing
rows now share the same right edge.

## rtfreporter 0.0.26

### New utility functions extracted from `paginate()`

* **`format_count_pct(count, pct, pct_unit, nbsp)`** — produces
  uniform-width `"n (xx.x)"` strings from numeric `count` and `pct`
  vectors.  Port of the reference helper from Issue \#2 (clinical
  TFL column alignment).  Four width branches:
  count-only when count is `NA` or `0`, `n (100)` at exactly 100%,
  one-digit pct gets an extra space (`n  (X.Y)`), two-digit pct
  uses `n (XX.Y)`.  Padding spaces become NBSP (`U+00A0`) by
  default so RTF / Word does not collapse them.

* **`realign_count_pct(strings, nbsp)`** — same width policy but
  starting from already-formatted strings (e.g. those `gt` emits
  in the rendered body).  Cells matching `"n (xx.x)"` are parsed
  and reformatted; non-matching cells pass through unchanged.

* **`set_blank_rows(df, blank_rows, blank_row_first, blank_row_end,
  group_col)`** — exposes the blank-row attribute logic that
  `paginate()` had internally.  Takes ONE data.frame (already at
  page size), resolves the blank spec, and writes the result onto
  `attr(df, "rtf_blank_rows")` for `rtftable(read_attributes = TRUE)`
  to consume.  Use this when you already do your own paging and only
  need the blank-row mechanism.

### `paginate()` integration

* `paginate(..., align_count_pct = TRUE)` runs
  `realign_count_pct()` on every character column other than column 1
  *before* splitting, so every page inherits the cleaned-up cells.
  Default is `FALSE` (no automatic rewriting).
* Internally, `paginate()` now delegates the per-page blank-row
  work to `set_blank_rows()`; the two APIs cannot drift apart.

## rtfreporter 0.0.25

### `paginate()` — list-name propagation, `split = "by_value"`, clearer help

* **Named-list inputs round-trip through `paginate()`.**  When the
  input is a `list` whose elements have names, those names are now
  carried through to the output:

    * input → 1 page  → the chunk keeps the input name
    * input → many pages → chunks named `<name>.1`, `<name>.2`, …
    * unnamed input → no name (as before)

  So `paginate(list("Table 14.1.1" = tbl1, "Table 14.2.1" = tbl2))`
  returns a 2-element named list, and the names flow on to
  `rtf_tables(pages, auto_section = TRUE)` if you choose to use it.

* **New `split = "by_value"` mode.**  One page per detected group,
  *never* packed.  Each returned page is named by the group's label
  (the indented col-1 text when `group_col = NULL`, otherwise the
  value of `df[[group_col]]`).  Combine with
  `rtf_tables(pages, auto_section = TRUE)` to render one RTF section
  per group value (e.g. one section per study visit).  A group that
  exceeds `max_rows` is internally force-split with `(Cont.)` and
  the sub-chunks get suffixed names (`<label>.1`, `<label>.2`, …).

* The page-name (when present) is also surfaced in
  `attr(., "rtf_paginate_meta")$page_name` for programmatic access.

* **`?paginate` reference page reformatted.**  Each `@param` now
  stands on its own paragraph with enumeration bullets where
  appropriate, instead of running together as a single dense block.
  Two new worked examples (sections 6–7) show the `"by_value"` mode
  and the named-list round-trip.

## rtfreporter 0.0.24

### `paginate()` — preserve the input's class chain (tibble in → tibble out)

* `paginate(<gt_tbl>)` no longer down-grades the extracted body to a
  plain `data.frame`.  Since `gt::extract_body()` returns a tibble
  and gt-based workflows are tibble-native, every returned page is
  now also a tibble (`tbl_df` / `tbl` / `data.frame`).
* `paginate(<tibble>)` likewise returns tibbles on every page,
  including pages that came out of the group-force continuation path
  (where an internal `rbind()` would otherwise drop the tibble class).
* `paginate(<data.frame>)` still returns plain data.frames, as
  before.

Implementation: the input's `class()` chain is captured once and
re-applied to each returned chunk after the splitter has finished.

## rtfreporter 0.0.23

### `paginate()` enhancements

* **`blank_row_first = TRUE` / `blank_row_end = TRUE`** — new
  per-page boolean arguments that auto-insert a blank row at the top
  / bottom of *every* returned page (positions `0` and `nrow(chunk)`
  respectively).  Combine with `blank_rows = "between_groups"` to
  get the clinical-TFL pattern of blank-before-each-group +
  blank-at-page-edges.
* **Indent-based grouping clarified.**  The auto-detected group
  semantics (default `group_col = NULL`) are now explicitly
  documented as indent-based: only rows whose first column starts
  with a non-space character open a new top-level group; rows with
  leading whitespace (any depth) stay in the current group.
  Multi-level layouts like

  ```
  group1
      sub-row 1
      sub-row 2
          sub-sub-row 3
  group2
      ...
  ```

  therefore split / blank correctly out of the box, using `group1`
  and `group2` as the unit.

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

# Earlier versions

See [`CHANGELOG.md`](CHANGELOG.md) for the detailed pre-v0.0.18 history.
