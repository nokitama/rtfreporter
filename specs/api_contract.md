# API Contract (R and Python)

This document defines the shared API and behavior for the first milestone.
The R and Python implementations must provide equivalent objects, defaults,
and output behavior.

## v0.1.0 (draft)

### Public API (shared names)

- Class: `rtfreport`
- Function: `generate_rtfreport(report, file_path, ...)`

### Class model choice in R

- R class system: **R6** (selected)
- Reason:
  - The object is hierarchical (document -> section -> page) and mutable.
  - Builder-style workflows are simpler with reference semantics.
  - Closer to Python OOP behavior, making parity easier.
- Not selected now:
  - S4: strong formal typing, but more verbose for nested mutable document edits.

### Object hierarchy

`rtfreport` represents one RTF document and owns three levels:

- Document level
  - Global defaults and metadata
  - List of sections
- Section level
  - Optional section header/footer overrides
  - List of pages
- Page level
  - Title
  - Content blocks
  - Optional page-local footer notes

### Document-level specification

#### Core properties

- `font_table`
  - Default: Courier only
- `color_table`
  - Default: black only (`#000000`)
- `default_page`
  - Default paper: Letter
  - Default orientation: landscape
  - Default margins (clinical-friendly initial values):
    - top: 0.75 in
    - bottom: 0.75 in
    - left: 0.50 in
    - right: 0.50 in
- `default_format`
  - Common default formatting for header/footer/content tables
  - Must allow global settings with lower-level override
  - Example controlled fields:
    - font family and size
    - line spacing
    - paragraph spacing
    - border style
    - table cell height (global default)

#### Override precedence

Defaults are resolved with this order (lowest to highest):

1. document default
2. section override
3. page override
4. block-level override

### Section-level specification

#### Header/Footer structure

- Both header and footer are table-like containers.
- Column count: 1 to 3, determined by which keys are present in each row.
- Layout: equal-width columns only.
- Width default: full writable width (between margins). Absolute width can be
  specified in twips; percentage-based width is not supported.
- Alignment determined by column key:

| Key | Column | Alignment |
|-----|--------|-----------|
| `l` | left column | left |
| `c` | center column | center |
| `r` | right column | right |

**Column count rules:**
- Only `l` → 1 column (left)
- Only `c` → 1 column (center)
- Only `r` → 1 column (right)
- `l` + `r` (no `c`) → 2 columns (left, right)
- `c` present with `l` or `r` → **3 columns** (l, c, r); missing keys default to `""`
- `l` + `c` + `r` → 3 columns

- Unnamed elements: column count and alignment determined by count (1=center/left, 2=left/right, 3=left/center/right).

**Border defaults:**
- Header: no borders (`border = NULL`)
- Footer: top border on the first row only (`border = rtf_border_top()`)

**Row height:** One configurable value for all header/footer rows, set in
`inst/resources/rtf_commands.R` under `defaults$header_footer_row_height_twips`.

#### Header/Footer row representation

Section-level header/footer is specified in `add_section(header=, footer=)`,
`set_section_header()`, or `set_section_footer()` in one of these forms:

**Single-row shorthand** (plain named character vector):
```r
add_section(header = c(l = "Protocol: RTF-101", r = "Page {AUTO_PAGE} of {TOTAL_PAGES}"))
set_section_footer(sec, c(l = "Confidential"))
```

**Multi-row** (list with `rows` element):
```r
add_section(
  header = list(
    rows = list(
      c(l = "Protocol: RTF-101",  r = "HOGE company"),
      c(l = "Study Title",        r = "Page {AUTO_PAGE} of {TOTAL_PAGES}"),
      c(c = "Table 14.1.1 Demographic Summary"),
      c(l = "Cohort: Cohort 1")
    )
  ),
  footer = list(
    rows = list(c(l = "Confidential"))
  )
)
```

**Document-wide default header/footer has been removed.** Every section must
explicitly specify its header and footer. If a section is created without
specifying header or footer, it inherits the header/footer from the
immediately preceding section. If no previous section exists, no header/footer
is rendered for that section.

**Backward compatibility**: The legacy form `list(columns = c(...))` per row is
still accepted by the renderer but must not be used in new code.

#### Header/Footer object constructors

`rtf_header()` and `rtf_footer()` provide explicit control over borders, width,
and row height. Both return a plain list and are accepted wherever a plain
named vector is accepted.

```r
rtf_header(
  rows,                       # named vector (single row) or list of named vectors
  border           = NULL,    # rtf_border or NULL = no border
  width_twips      = NULL,    # NULL = full writable width
  row_height_twips = NULL     # NULL = read from rtfreporter_defaults.R
)

rtf_footer(
  rows,
  border           = rtf_border_top(),  # footer default: top border on first row
  width_twips      = NULL,
  row_height_twips = NULL
)
```

**Deprecated parameters (kept for backward compatibility, emit a warning):**
- `top_border = TRUE/FALSE` in `rtf_header()`/`rtf_footer()` → use `border=` instead.

#### Border class hierarchy

Three constructor functions build border specifications.  All return plain
lists with a class attribute (not R6).

##### `rtf_border_side` — one edge

```r
rtf_border_side(
  style = "single",   # "single" | "double" | "thick" | "dash" | "dot"
  width = 15L,        # line width in twips (15 ≈ 0.5 pt)
  color = NULL        # NULL = black, or "#RRGGBB" hex string
)
```

##### `rtf_border` — four edges of one cell / row

```r
rtf_border(
  top    = NULL,   # NULL = no border, or rtf_border_side(...)
  bottom = NULL,
  left   = NULL,
  right  = NULL
)
```

Convenience constructors (all return an `rtf_border`):

| Function | Effect |
|---|---|
| `rtf_border_none()` | All four sides `NULL` (explicit "no border") |
| `rtf_border_top(style, width, color)` | Top side only |
| `rtf_border_bottom(style, width, color)` | Bottom side only |
| `rtf_border_box(style, width, color)` | All four sides |

##### `rtf_table_border` — per-zone border for a table

```r
rtf_table_border(
  header    = NULL,  # rtf_border for column-header rows
  spanning  = NULL,  # rtf_border for spanning-header rows
  body      = NULL,  # rtf_border for data rows
  first_row = NULL,  # rtf_border override for first data row (merged with body)
  last_row  = NULL   # rtf_border override for last data row  (merged with body)
)
```

Preset: `rtf_border_tfl()` returns the clinical-TFL standard border
(`header` top+bottom, `last_row` bottom, all others `NULL`).

##### Usage examples

```r
# Footer with a top dividing line (default)
rtf_footer(rows = list(l = "Company", r = "{AUTO_PAGE}/{AUTO_TOTAL_PAGES}"))

# Header with a thick-blue bottom line
rtf_header(
  rows   = list(c = "Study Title"),
  border = rtf_border(bottom = rtf_border_side("thick", 20L, "#003366"))
)

# Table with TFL borders (default)
rtftable(df)

# Custom table borders
rtftable(df, border = rtf_table_border(
  header   = rtf_border(top = rtf_border_side(), bottom = rtf_border_side()),
  last_row = rtf_border(bottom = rtf_border_side("double"))
))
```

##### Backward compatibility

| Old form | Behavior |
|---|---|
| `rtftable(border = "tfl")` | converted to `rtf_border_tfl()` |
| `rtftable(border = list(header = ...))` | plain list normalized internally |
| `rtf_footer(top_border = TRUE)` | deprecated warning + `border = rtf_border_top()` |
| `rtf_footer(top_border = FALSE)` | deprecated warning + `border = NULL` |

**Set/get methods on `rtfreport`:**
- `set_section_header(section_index, header)` — set or replace after creation
- `get_section_header(section_index)` — retrieve the stored header (may be `NULL`)
- `set_section_footer(section_index, footer)` — set or replace after creation
- `get_section_footer(section_index)` — retrieve the stored footer (may be `NULL`)

#### Header/Footer page tokens

| Token | Type | Behavior |
|-------|------|----------|
| `{AUTO_PAGE}` | Dynamic | Replaced with RTF `\chpgn` — page number updated per page by the RTF viewer |
| `{AUTO_TOTAL_PAGES}` | Dynamic | Replaced with RTF `NUMPAGES` field — total pages updated by the RTF viewer |
| `{PAGE}` | Static | Replaced with the first page number of the section at render time |
| `{TOTAL_PAGES}` | Static | Replaced with the total page count of the document at render time |

Prefer `{AUTO_PAGE}` and `{TOTAL_PAGES}` for typical clinical report headers:
`"Page {AUTO_PAGE} of {TOTAL_PAGES}"`.

`{AUTO_PAGE}` uses `\chpgn` (viewer-rendered dynamic field). `{TOTAL_PAGES}` uses
a static count computed when `generate_rtfreport()` is called.

### Page-level specification

- `title`
- `content` (ordered blocks)
  - `table` / `listing`
    - data frame payload
    - column header metadata
    - display metadata
  - `figure`
    - image file path
    - supported formats (initial): PNG, JPEG
- `footer_notes`
  - table footer or figure-specific footer text

### Function specification

`generate_rtfreport(report, file_path, ...)` converts one `rtfreport` object
to one RTF file.

### Convenience builder specification

`add_section_from_dataframes(...)` creates one section and appends one page per
data frame in a list.

#### Shared signature

- R
  - `rtfreport$new()` returns an object exposing
    `add_section_from_dataframes(data_list, section_header = NULL,
    section_footer = NULL, page_titles = NULL, block_type = "table",
    page_footer_notes = NULL, metadata = NULL)`
- Python
  - `rtfreport()` returns an object exposing
    `add_section_from_dataframes(data_list, section_header=None,
    section_footer=None, page_titles=None, block_type="table",
    page_footer_notes=None, metadata=None)`

#### Required behavior

- `data_list` must be a non-empty list-like collection of data-frame objects.
- The method must create one section.
- The method must create one page per element of `data_list` in order.
- Each page must contain one block of type `table` or `listing`.
- If `page_titles` is omitted, titles should be derived from names/labels when
  available, otherwise a simple ordinal title may be used.
- If `page_footer_notes` is supplied as a single value, it should be reused for
  all pages; if supplied as a list/vector, values should be matched by position.
- `metadata`, when supplied, should be applied to each created block unless a
  future implementation supports per-page metadata lists.
- The method must return the created section index.

#### Required behavior

- Validate object structure before writing.
- Resolve inherited defaults and overrides.
- Render headers/footers/page content in order.
- Write valid RTF syntax.
- Fail with clear messages for invalid figure path, unsupported content type,
  or missing required metadata.

### Language-specific signatures (first implementation)

- R
  - Constructor: `rtfreport$new(...)`
  - Writer: `generate_rtfreport(report, file_path, overwrite = FALSE)`
- Python
  - Constructor: `rtfreport(...)`
  - Writer: `generate_rtfreport(report, file_path, overwrite=False)`

### Out of scope for v0.1.0

- Merging multiple RTF files into a single final file.
- Full Word-compatible field-code coverage for all vendors.
- Advanced table pagination controls beyond minimum required splitting.

## Resource-driven RTF rendering rules (applies to both R and Python)

### 1) RTF command strings must not be hard-coded in renderer logic

- All RTF control words and templates used for writing the final document
  must be loaded from resource files.
- Renderer code can only reference logical keys (example: `row_start`,
  `paragraph_left`) and must not embed raw control words in-line.
- Resource files should be grouped by meaning so maintenance is simple.

Recommended grouping:

- `document`:
  - file header, font table shell, color table shell, section/page break markers
- `paragraph`:
  - left/center/right paragraph prefixes and paragraph terminators
- `table`:
  - row start, row end, cell boundary templates, cell content templates,
    border templates, row height template

### 2) Metadata-driven layout for table/listing blocks

- Table/listing rendering must be controlled by metadata merged from:
  1. document-level `default_format`
  2. page-level options (if provided)
  3. block-level `metadata`
- Supported metadata keys (minimum):
  - `table_width_twips`: table width in twips
  - `table_width_pct_of_writable`: table width as writable-area percentage
    (0.0 to 1.0)
  - `row_height_twips`: exact/target row height in twips
  - `column_widths_twips`: optional vector/list of explicit column widths
- Width resolution order (highest precedence first):
  1. `column_widths_twips`
  2. `table_width_twips`
  3. `table_width_pct_of_writable`
  4. fallback to writable width
- If `column_widths_twips` is provided and length differs from number of columns,
  rendering must fail with a clear message.

### 3) Automatic report generation from resources + metadata

- Final RTF output must be produced by combining:
  - resource command templates, and
  - resolved metadata values.
- This rule applies to document shells, page titles, headers/footers, and
  table/listing rows.
- Cell height and table width controls are therefore data-driven and not
  hard-coded.

### Open confirmation items (must be fixed before implementation)

1. Default font size for TFL output (proposal: 9 pt).
2. Default line spacing (proposal: single).
3. Minimum required metadata for table/listing blocks.
4. Page numbering display default in footer:
   - proposal: `Page X of Y` (document scope).
5. Whether section-level numbering should be enabled by default or opt-in.
