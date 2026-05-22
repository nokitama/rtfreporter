# rtfreporter — Requirements & Design Specification

**Version**: 0.1.0-draft  
**Created**: 2026-05-22  
**Language**: English (authoritative)  
**Status**: Active — decisions made in this document supersede earlier drafts

---

## 1. Overview

`rtfreporter` is an R package for generating clinical RTF reports (Tables, Figures, Listings — TFL) used in pharmaceutical clinical trials. A future Python package will provide equivalent functionality.

### 1.1 Goals

- Produce valid RTF documents conforming to the RTF 1.5 specification
- Support the Document → Section → Page → Content hierarchy required for multi-section clinical reports
- Provide a clean, user-facing S3 API with R6 kept strictly internal
- Support future Python parity without coupling the two implementations

### 1.2 Out of Scope (initial release)

- Merging multiple RTF files into one combined document (`assemble_rtf`) — planned for later
- Advanced table pagination (automatic page-break inside a table)
- `pageby` grouping (group-variable-driven page breaks inside a listing)
- Cell background color

---

## 2. Repository Structure

The R package lives at the **repository root**. Python lives in `python/`. Release guidelines in `specs/release_guidelines.md` should be updated to reflect this.

```
rtfreporter/             ← Git repository root = R package root
├── DESCRIPTION
├── NAMESPACE
├── r/                   ← R source files (*.R)
├── man/                 ← Generated Rd documentation
├── inst/
│   └── resources/
│       ├── rtf_commands.R          ← RTF control word templates
│       └── rtfreporter_defaults.R  ← Configurable defaults
├── tests/               ← R test scripts
├── vignettes/           ← Rmd vignettes
├── python/              ← Python package (future)
│   ├── pyproject.toml
│   └── src/rtfreporter/
└── specs/               ← Design documents (this folder)
```

---

## 3. API Design Decisions

### 3.1 Public API: S3 functions only

**Decision (2026-05-22)**: The public API exposed to users consists exclusively of S3 constructor functions and generic functions. R6 classes are internal implementation details and **must not appear in NAMESPACE exports or documentation**.

| Object | Public (exported) | Internal (not exported) |
|--------|-------------------|------------------------|
| RTF document | `rtfreport()` → S3 object | `RtfReport` R6 class |
| RTF table | `rtftable()` → S3 object | `RtfTable` R6 class |
| RTF figure | `rtfplot()` → S3 object | `RtfPlot` R6 class |
| Borders | `rtf_border()`, `rtf_border_side()`, `rtf_table_border()` (already S3 plain lists) | — |
| Header/Footer | `rtf_header()`, `rtf_footer()` (already S3 plain lists) | — |
| Writer | `generate_rtfreport()` | internal render functions |

### 3.2 Mutability model

**Decision (2026-05-22)**: Internal R6 objects are mutable (reference semantics). S3 wrapper functions modify the internal R6 object in-place and return the same S3 object (invisible where appropriate). This avoids expensive copies of large document objects.

```r
# User-facing code
report <- rtfreport()
report <- add_section(report, header = rtf_header(...), footer = rtf_footer(...))
report <- add_page(report, 1, title = "Table 14.1.1")
report <- add_table(report, 1, 1, rtftable(df, col_header = c("Item", "N", "Mean")))
generate_rtfreport(report, "output/t14_1_1.rtf")
```

### 3.3 Construction approach

**Decision (2026-05-22)**: Start from a fresh design. Current code in `r/` may be referenced for RTF rendering logic and resource file content, but new files will be written cleanly with the S3-first API.

---

## 4. RTF Document Structure

```
RTF Document
└── Document-level settings
    ├── Font table
    ├── Color table
    └── Page defaults (paper size, margins, font)
Section (1..n)
├── Section settings (\sectd)
├── Header (table, per section)
├── Footer (table, per section)
└── Pages (1..n)
    ├── Content title (centered bold text, multi-line)
    ├── Content (table | figure)
    └── Content footer (footnote text)
```

Key RTF rule: **header and footer are per-section**, not per-page. To change header/footer on a page, a new section must begin.

---

## 5. Object Hierarchy

### 5.1 `rtfreport` — RTF document

Represents one RTF file. Created with `rtfreport()`.

**Document-level fields:**

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `font_table` | list | `list(list(name = "Courier"))` | Font definitions |
| `color_table` | character | `c("#000000")` | Hex color codes |
| `paper` | character | `"letter"` | Paper size |
| `orientation` | character | `"landscape"` | Page orientation |
| `margin_top` | numeric (in) | 0.75 | Top margin in inches |
| `margin_bottom` | numeric (in) | 0.75 | Bottom margin |
| `margin_left` | numeric (in) | 0.50 | Left margin |
| `margin_right` | numeric (in) | 0.50 | Right margin |
| `font_size` | numeric (pt) | 9 | Default font size |

**S3 functions operating on `rtfreport`:**

```r
rtfreport(...)                              # constructor — returns S3 object
add_page(report, title, new_section, header, footer, ...)  # see §5.2
add_table(report, rtftable_obj, ...)        # adds to last page
add_figure(report, rtfplot_obj, ...)        # adds to last page
generate_rtfreport(report, file_path, overwrite = FALSE)
```

**Mutability note:** Because the internal R6 object is mutable, `add_page()`, `add_table()`, and `add_figure()` modify the document in-place. The return value is the `report` object (invisibly), so `report <-` reassignment is optional but recommended for readability.

**Decision (2026-05-22): `add_section()` is abolished.** Sections are created implicitly via `add_page(new_section = TRUE)`. This simplifies the user API by eliminating the need to track section indices.

### 5.2 `add_page()` — Adding pages and sections

```r
add_page(
  report,
  title       = NULL,      # character: content title (centered bold, multi-line OK)
  new_section = FALSE,     # TRUE → insert section break before this page
  header      = NULL,      # rtf_header() — used only when new_section = TRUE
  footer      = NULL,      # rtf_footer() — used only when new_section = TRUE
  ...
)
```

**Section rules:**
- The **first** `add_page()` call **always** starts a new section (implicit `new_section = TRUE`). Even if `new_section = FALSE`, the first page creates the initial section.
- When `new_section = TRUE`, the supplied `header` and `footer` apply to this section.
- When `new_section = FALSE`, the new page inherits the header/footer of the current section.
- If `header`/`footer` is `NULL` with `new_section = TRUE`, the new section inherits from the preceding section.

**Typical workflow:**

```r
report <- rtfreport()

# Page 1 — first page always creates the first section
add_page(report,
  title       = "Table 14.1.1 Demographic Summary",
  new_section = TRUE,
  header = rtf_header(rows = list(
    c(l = "Protocol: XXX-001",  r = "Company Name"),
    c(l = "Study Title",        r = "Page {AUTO_PAGE} of {TOTAL_PAGES}")
  )),
  footer = rtf_footer(c(l = "Confidential - For Clinical Study Use Only"))
)
add_table(report, rtftable(df1, col_header = c("Parameter", "N", "Mean (SD)")))

# Page 2 — same section (header/footer inherited)
add_page(report, title = "Table 14.1.2 Medical History")
add_table(report, rtftable(df2))

# Page 3 — new section with different header/footer
add_page(report,
  title       = "Listing 16.2.1 Individual Data",
  new_section = TRUE,
  header = rtf_header(rows = list(
    c(l = "Protocol: XXX-001", r = "Company Name"),
    c(l = "Listing 16.2.1",   r = "Page {AUTO_PAGE} of {TOTAL_PAGES}")
  ))
)
add_table(report, rtftable(lst_df))

generate_rtfreport(report, "output/report.rtf")
```

### 5.3 Section (internal)

Not a standalone S3 object — stored internally as a list inside `rtfreport`. Created automatically when `add_page(new_section = TRUE)` is called.

| Field | Notes |
|-------|-------|
| `header` | `rtf_header()` object or `NULL` (inherits from previous section) |
| `footer` | `rtf_footer()` object or `NULL` (inherits from previous section) |
| `pages` | list of page objects |

**Header/footer inheritance rule**: If a section's header/footer is `NULL`, it inherits from the immediately preceding section. If no previous section exists and header/footer is `NULL`, nothing is rendered.

### 5.4 Page (internal)

Stored internally as a list inside a section.

| Field | Notes |
|-------|-------|
| `title` | Character vector (multi-line OK). Rendered as centered bold text. |
| `content` | Ordered list of content blocks (`rtftable` or `rtfplot`) |
| `footer_notes` | Character. Rendered as left-aligned text after content. |

### 5.5 `rtftable` — Table content

Represents a formatted data.frame for RTF rendering.

**Constructor:**
```r
rtftable(
  data,                          # data.frame (required)
  col_header        = NULL,      # column header spec (see §6.1)
  spanning_header   = NULL,      # spanning header spec (see §6.2)
  col_spec          = NULL,      # per-column formatting (see §6.3)
  border            = "tfl",     # border spec (see §7)
  blank_rows        = NULL,      # integer vector: positions for blank separator rows
  col_rel_width     = NULL,      # numeric vector: relative column widths
  column_widths_twips = NULL,    # integer vector: absolute column widths (twips)
  table_width_twips = NULL,      # total table width in twips
  table_width_pct_of_writable = NULL,  # fraction of writable area (0-1)
  row_height_twips  = 0L,        # 0 = auto; positive = minimum height
  row_height_exact  = FALSE,     # TRUE = exact/fixed height (clips content)
  header_row_height_twips = NULL,
  blank_row_height_twips  = NULL,
  cell_padding_left_twips  = 72L,  # ~0.05 in
  cell_padding_right_twips = 72L,
  cell_valign       = "bottom"   # "top" | "center" | "bottom"
)
```

### 5.6 `rtfplot` — Figure content

Represents an embedded PNG or JPEG image.

**Constructor:**
```r
rtfplot(
  path,                  # file path to PNG or JPEG
  width_twips  = NULL,   # NULL = full writable width
  height_twips = NULL,   # NULL = maintain aspect ratio
  align        = "center"  # "left" | "center" | "right"
)
```

---

## 6. Table Formatting Details

### 6.1 Column headers (`col_header`)

Accepted forms:
- `NULL` — use `names(data)` as a single header row
- Character vector: one element per column
- Pipe-delimited string: `"Treatment | N | Mean (SD)"`
- List of the above: multiple header rows

```r
# Single row
rtftable(df, col_header = c("Treatment", "N", "Mean (SD)"))

# Multiple header rows
rtftable(df, col_header = list(
  c("", "Arm A", "Arm B"),
  c("Item", "N", "Mean", "N", "Mean")
))
```

### 6.2 Spanning headers (`spanning_header`)

Visually merge adjacent column headers using full-width cells and optional underline. RTF does not support true cell merging; spanning is achieved by computing cumulative `\cellx` widths.

```r
rtftable(df,
  col_header = c("Item", "N", "Mean", "N", "Mean"),
  spanning_header = list(
    list(from = 2, to = 3, label = "Arm A", underline = TRUE),
    list(from = 4, to = 5, label = "Arm B", underline = TRUE)
  )
)
```

### 6.3 Per-column formatting (`col_spec`)

List of per-column specs. Each element is a named list with `col` (index or name) plus optional attributes:

| Attribute | Type | Default | Notes |
|-----------|------|---------|-------|
| `col` | int or chr | — | column index or name (required) |
| `align` | chr | `"left"` | `"left"`, `"center"`, `"right"` |
| `bold` | logical | `FALSE` | data cell bold |
| `italic` | logical | `FALSE` | data cell italic |
| `underline` | logical | `FALSE` | data cell underline |
| `indent_twips` | int | `0` | left indent for data cells |
| `header_bold` | logical | `TRUE` | header cell bold |
| `header_align` | chr | `"center"` | header cell alignment |
| `header_italic` | logical | `FALSE` | header cell italic |

### 6.4 Blank separator rows (`blank_rows`)

Integer vector. `0` = before the first data row; `k` = after data row `k`.

---

## 7. Border Design

### 7.1 Class hierarchy (already implemented, keep as-is)

Three S3 classes built from plain lists (no R6):

```
rtf_border_side   — one edge: style, width, color
rtf_border        — four edges: top, bottom, left, right (each NULL or rtf_border_side)
rtf_table_border  — table zones: header, spanning, body, first_row, last_row
```

**Constructors:**
```r
rtf_border_side(style = "single", width = 15L, color = NULL)
rtf_border(top = NULL, bottom = NULL, left = NULL, right = NULL)
rtf_table_border(header, spanning, body, first_row, last_row)

# Convenience
rtf_border_none()
rtf_border_top(style, width, color)
rtf_border_bottom(style, width, color)
rtf_border_box(style, width, color)
rtf_border_tfl()   # Clinical TFL preset
```

### 7.2 Clinical TFL preset (`rtf_border_tfl`)

```
header:    top = single, bottom = single
spanning:  NULL
body:      NULL
first_row: NULL
last_row:  bottom = single
```

### 7.3 Header/footer borders

- `rtf_header()` default: `border = NULL` (no border)
- `rtf_footer()` default: `border = rtf_border_top()` (top line above footer)

Per-row border specification is applied uniformly to all rows of the header/footer table (not per-row independently — this is a simplification; per-row border can be a future enhancement).

---

## 8. Header and Footer Design

### 8.1 Structure

Headers and footers are rendered as RTF tables. They support 1–3 columns, unlimited rows.

**Column count rules (based on named keys `l`, `c`, `r`):**

| Keys present | Columns |
|---|---|
| `l` only | 1 col (left-aligned) |
| `c` only | 1 col (center-aligned) |
| `r` only | 1 col (right-aligned) |
| `l` + `r` | 2 cols |
| `l` + `c`, `c` + `r`, or `l` + `c` + `r` | 3 cols (missing keys = `""`) |

Unnamed character vector: 1 element = center, 2 = left/right, 3 = left/center/right.

### 8.2 Constructors

```r
rtf_header(
  rows,                       # named chr vector (1 row) or list of named vectors
  border           = NULL,    # rtf_border or NULL
  width_twips      = NULL,    # NULL = full writable width
  row_height_twips = NULL     # NULL = from rtfreporter_defaults.R
)

rtf_footer(
  rows,
  border           = rtf_border_top(),
  width_twips      = NULL,
  row_height_twips = NULL
)
```

### 8.3 Page tokens

| Token | Behavior |
|-------|----------|
| `{AUTO_PAGE}` | `\chpgn` — dynamic per-page number (viewer-rendered) |
| `{AUTO_TOTAL_PAGES}` | RTF `NUMPAGES` field — dynamic total (viewer-rendered) |
| `{PAGE}` | Static first-page number of section (computed at render time) |
| `{TOTAL_PAGES}` | Static total page count (computed at render time) |

Recommended usage: `"Page {AUTO_PAGE} of {TOTAL_PAGES}"`

### 8.4 Row height

One configurable value applies to all header/footer rows. Default defined in `inst/resources/rtfreporter_defaults.R`:

```r
rtfreporter_defaults <- list(
  header_footer_row_height_twips = 360L  # ~0.25 inch, minimum height
)
```

---

## 9. Text Markup

In table cell content, the following inline markup is supported:

| Markup | RTF | Effect |
|--------|-----|--------|
| `^{text}` | `{\super text}` | Superscript |
| `_{text}` | `{\sub text}` | Subscript |
| `>=` | `蠅?` | ≥ |
| `<=` | `蠄?` | ≤ |
| `\n` | `\line ` | Line break within cell |

Non-ASCII characters are converted to `\uN?` RTF Unicode sequences.

---

## 10. RTF Resource Files

All RTF control words are defined in resource files, never hard-coded in renderer logic.

### `inst/resources/rtf_commands.R`

Defines the `rtf_commands` list with sections:
- `document` — file header, font/color table templates, section/page break markers, header/footer wrappers
- `paragraph` — left/center/right paragraph templates
- `table` — row start/end, cell boundary, border, row height templates
- `alignment` — `\ql`, `\qr`, `\qc`
- `border` — side prefixes and style codes
- `cell_valign` — vertical alignment commands
- `text_decor` — bold, italic, underline, super, sub on/off pairs
- `picture` — PNG and JPEG `\pict` templates
- `fields` — dynamic page number field templates

### `inst/resources/rtfreporter_defaults.R`

Defines the `rtfreporter_defaults` list:
- `header_footer_row_height_twips` — default row height for header/footer rows

---

## 11. Width Resolution Order

For table width, highest precedence wins:

1. `column_widths_twips` (absolute, per-column)
2. `table_width_twips` (absolute, total)
3. `table_width_pct_of_writable` (fraction of writable area)
4. Full writable width (page width minus left and right margins)

If `column_widths_twips` length differs from number of columns, rendering fails with a clear error.

---

## 12. `generate_rtfreport()` Behavior

```r
generate_rtfreport(report, file_path, overwrite = FALSE)
```

1. Validate `report` object structure (sections, pages, content blocks)
2. Resolve color table from all border colors used in the document
3. Compute total page count (static)
4. For each section:
   a. Emit `\sectd` (section defaults)
   b. Emit `{\header ...}` and `{\footer ...}` once per section
   c. For each page:
      - Emit centered bold title (if any)
      - Emit content blocks in order
      - Emit page footer notes (if any)
      - Emit `\page` between pages and `\sect` between sections
5. Emit document close `}`
6. Write to `file_path` using `useBytes = TRUE`

---

## 13. Documentation Requirements

- All exported S3 functions must have English Roxygen2 documentation
- Parameter descriptions, return values, and at least one `@examples` block
- A quickstart vignette (`vignettes/rtfreporter-quickstart.Rmd`) in English
- A vignette for clinical TFL patterns (`vignettes/rtfreporter-tfl.Rmd`) in English (planned)

---

## 14. Decisions Log

| Date | Decision | Notes |
|------|----------|-------|
| 2026-05-22 | Public API: S3 functions only, R6 internal | User request |
| 2026-05-22 | Mutability: R6 mutable internally; S3 functions return same object | Avoids copy cost |
| 2026-05-22 | Constructor: `rtfreport()`, `rtftable()`, `rtfplot()` | S3 style |
| 2026-05-22 | Directory: R package at repository root | Keep current layout |
| 2026-05-22 | Approach: rewrite from clean design | Current code used as reference only |
| 2026-05-22 | First deliverable: specs/ document | This file |
| 2026-05-22 | Header/footer per-row border: uniform only (future: per-row) | Simplification |
| 2026-05-22 | `assemble_rtf()`, `pageby`, cell bg color: out of scope v1 | Planned later |
| 2026-05-22 | `add_section()` abolished; sections created via `add_page(new_section=TRUE)` | Simplifies API |
| 2026-05-22 | `add_table()` / `add_figure()` always append to the last added page | No index tracking needed |
| 2026-05-22 | First `add_page()` always creates first section regardless of `new_section` | RTF always needs ≥1 section |

---

## 15. Open Questions (to be resolved in next session)

1. **S3 add_section return value**: Should `add_section()` return the modified report (invisible) AND the section index as an attribute, or return a list `list(report, section_index)`? → Need to decide for ergonomics.
2. **Pipe support**: Should we support `|>` chaining? If so, all add_* functions must return the report invisibly.
3. **Default font size**: Confirmed 9pt (9pt = 18 half-points in RTF `\fs18`). Document this in resource file.
4. **Vignette build**: Pre-built HTML in `inst/doc/` vs. build-on-install. Keep pre-built for now.
5. **AGENTS.md**: There is an AGENTS.md in the root — review its content to ensure it remains consistent with new design.
