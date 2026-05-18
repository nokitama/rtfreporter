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
- `default_header`
  - Used when section header is not set
- `default_footer`
  - Used when section footer is not set
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
- Column count: 1 to 3.
- Layout: equal-width columns only.
- Width default: full writable width (between margins).
- Alignment default by column count:
  - 1 column: center (header) / left (footer)
  - 2 columns: left / right
  - 3 columns: left / center / right

#### Header/Footer row representation

A header or footer passed directly to `add_section(header=)`, `set_section_header()`,
or `set_section_footer()` is **a plain named character vector**:

```r
# Single section header/footer — plain named vector
add_section(header = c(l = "Protocol: RTF-101", r = "Page {PAGE} of {TOTAL_PAGES}"))
set_section_footer(sec, c(l = "Confidential"))
```

A document-level default header/footer (`set_default_header()`, `set_default_footer()`)
uses a **list with a `rows` element** whose values are plain named vectors — one vector
per row:

```r
# Multi-row document-wide header
set_default_header(list(
  rows = list(
    c(l = "Protocol: RTF-101", r = "Page {PAGE} of {TOTAL_PAGES}"),
    c(l = "Study Title",       r = "For Clinical Study Use Only")
  )
))

# Document-wide footer with top border
set_default_footer(list(
  rows = list(c(l = "Confidential - Internal Use Only")),
  top_border = TRUE
))
```

**Named vector keys and their alignment mapping**:

| Key | Alignment |
|-----|-----------|
| `l` | left      |
| `r` | right     |
| `c` | center    |
| (unnamed) | determined by column count (see defaults above) |

**Backward compatibility**: The legacy form `list(columns = c(...))` per row is still
accepted by the renderer but must not be used in new code.

#### Header/Footer dynamic fields

- Must support page tokens:
  - current page in section
  - total pages in section
  - current page in whole document
  - total pages in whole document
- Must support section-specific grouped header text (example: lab test name).
- Section break behavior must be supported for per-section header changes.

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
