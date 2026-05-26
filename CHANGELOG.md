# Changelog

All notable changes to rtfreporter are documented in this file. Changes are recorded for **major.minor** version releases only (v0.1.0, v0.2.0, etc.). Patch and development versions (v0.1.1, v0.0.6, v0.0.dev, etc.) are not recorded.

---

## v0.1.0 (TBD - when ready for public release)

> **Status**: Currently in development as v0.0.15. Will be released as v0.1.0 when complete.

### 🔴 Breaking Changes (v0.0.15)

#### Spanning rows: bold default flipped to FALSE; new optional `bold`, `italic`

Spanning-header cells were rendered in **bold** unconditionally.  They
now default to **normal** weight, matching the policy already adopted
for column-header rows in v0.0.11.  Three new optional per-cell fields
let callers opt in:

| Field | Default | Effect |
|---|---|---|
| `bold` | `FALSE` | Wrap label in `\b ... \b0`. |
| `italic` | `FALSE` | Wrap label in `\i ... \i0`. |
| `underline` | `FALSE` | Wrap label in `\ul ... \ulnone` (already existed). |

```r
spanning_header = list(
  list(from = 2, to = 3, label = "Drug A", underline = TRUE),               # plain weight, underlined
  list(from = 4, to = 5, label = "Drug B", underline = TRUE, bold = TRUE)   # bold + underlined
)
```

### 📋 Specification consolidation: column-header alignment

The cascade is unchanged from v0.0.12 but the contract is now pinned by
a dedicated test file ([tests/test-header-alignment.R](tests/test-header-alignment.R), 15 assertions):

1. **Default**: column-header alignment follows the data column's
   alignment (`col_spec[[j]]$align`).
2. **Spanning row**: alignment defaults to the leftmost covered
   column's resolved `header_align` (i.e. it inherits one level down
   the hierarchy).
3. **Per-table override**: `col_header_align` (scalar or length-ncol
   character vector) sets the table-wide header alignment.
4. **Per-column override**: `col_spec[[j]]$header_align` always wins.

### ✨ Features (v0.0.14)

#### Spanning rows inherit alignment from the level below

`spanning_header` cells previously rendered with a hard-coded `\qc`
(centre) alignment.  They now inherit the alignment of the level
immediately below — i.e. the leftmost covered column's `header_align`
(which itself cascades from `col_spec[[j]]$align`).  Resolution order
per spanning cell:

1. `sp$align` — explicit per-cell override.
2. `col_spec[[sp$from]]$header_align` — inherit from the level below.
3. `"center"` — final fallback.

```r
# Numeric columns are right-aligned;
# the spanning labels above them now follow suit by default.
rtftable(df,
  col_header = c("Item", "N", "Mean", "N", "Mean"),
  col_spec   = list(
    list(col = 1, align = "left"),
    list(col = 2, align = "right"),
    list(col = 3, align = "right"),
    list(col = 4, align = "right"),
    list(col = 5, align = "right")
  ),
  spanning_header = list(
    list(from = 2, to = 3, label = "Drug A (N=30)", underline = TRUE),
    list(from = 4, to = 5, label = "Drug B (N=30)", underline = TRUE)
  ))
# → "Drug A (N=30)" and "Drug B (N=30)" are right-aligned.
```

`list(from, to, label, underline, align = "center")` still works for an
explicit override.  Same rule applies to spanning rows declared inline
inside the `col_header` list.

### ✨ Features (v0.0.13 — Step C of the style/spec refactor)

#### `rtf_border` is now R6 (backward compatible)

The four-edge cell-border class is upgraded from an S3 list to an R6
object. The R6 instance still carries `class = "rtf_border"`, so
existing user code that does `inherits(x, "rtf_border")` and field
access via `x$top` / `x[["top"]]` continues to work.

The new R6 form adds chainable builder methods and explicit clone /
override semantics:

```r
b <- rtf_border()$set_top(rtf_border_side())$set_bottom(rtf_border_side("double"))

b2 <- b$with_right(rtf_border_side("dot"))   # non-mutating clone

b$apply_override(other_border)               # mutating in place
b3 <- b$override(other_border)               # non-mutating clone
```

This is the one place in rtfreporter where reference semantics are
intentionally exposed to users — see [LEARNING.md](LEARNING.md) for the
design rationale.

#### `rtf_table_style` — shared mutable theme (R6)

A new R6 class for **table-wide style templates that multiple tables
share by reference**. Define a "company TFL theme" once, hand the same
instance to many `rtftable()` calls, and tweak it later:

```r
tfl <- rtf_table_style_tfl()                 # built-in TFL preset

tables <- lapply(dfs, function(df) rtftable(df, style = tfl))

# Build new tables after a tweak picks up the change
tfl$header_bold <- TRUE
```

`style$clone_with(field = value, ...)` returns a non-mutating
derivation. `style$as_table_border()` converts the zone borders into
the existing `rtf_table_border` form consumed by the renderer.

The `style` argument was added to `rtftable()` and the corresponding
flow on `rtf_tables()`. Explicit arguments always take precedence over
the style's defaults.

#### Per-column border in `col_spec`

`col_spec` entries gain a `border` slot (`rtf_border()` instance) that
overrides the zone border for that column on the column-header row.
Useful for the clinical-TFL idiom of drawing a bottom line under one
group of columns only.

```r
rtftable(df,
  border   = rtf_table_border(header = rtf_border(top = rtf_border_side(),
                                                    bottom = rtf_border_side())),
  col_spec = list(
    list(col = "Total",
         border = rtf_border(bottom = rtf_border_side("double", 20L)))
  ))
```

The renderer merges (zone border × column border) per cell so each
column header cell can have its own border profile.

#### LEARNING.md

A new top-level document, [LEARNING.md](LEARNING.md), explains the R6
vs S3 design decisions across the package. Useful for the package's
secondary goal of being a small but realistic case study in R object
systems.

### ✨ Features (v0.0.12 — Step B of the style/spec refactor)

#### `blank_rows`: three combinable specification modes

The `blank_rows` argument now accepts three orthogonal specification
modes that can be freely combined inside a list (positions are unioned,
deduplicated, and sorted):

1. **Integer positions** — `c(0, 5, -1)`. `0` is before the first data
   row, `k` is after row `k`, and `-1` means "after the last data row".
   Out-of-range integers warn and are dropped.

2. **By variable change** — `blank_rows_by_change(cols, ...)`. Inserts
   a blank separator whenever the value of any listed column differs
   from the previous row. `include_before_first` and
   `include_after_last` (both `TRUE` by default) add rows at the start
   and end.

3. **By rule** — `blank_rows_by_rule(col, pattern, where)`. Inserts a
   blank row before or after every data row whose value in `col`
   matches the regular expression `pattern`.

```r
rtftable(df, blank_rows = list(
  c(-1),                                            # after the last row
  blank_rows_by_change("Visit",
    include_before_first = FALSE,
    include_after_last   = FALSE),                  # at every Visit change
  blank_rows_by_rule("Parameter", "^Total", "before")
))
```

#### `read_attributes = TRUE`: data-frame attribute fallback

`rtftable()` (and the same path inside `rtf_tables()`) now reads
recognised attributes off the input data frame as fallback defaults.
The first attribute consumed is `attr(data, "rtf_blank_rows")` —
its numeric value seeds `blank_rows` when the argument is left `NULL`.
Set `read_attributes = FALSE` to suppress.

This is intentionally an extensible mechanism: future attributes
(`rtf_col_header_align`, `rtf_col_spec`, ...) can be added without
changing call sites.

#### `col_header_align`: cascade rule for column-header alignment

`rtftable()` gains a `col_header_align` argument. The default
`header_align` for column headers now **inherits the data alignment**
(`col_spec[[j]]$align`) instead of the previous hard-coded `"center"`.

Resolution precedence (highest first):

1. `col_spec[[j]]$header_align`   (per-column override)
2. `col_header_align[j]`          (table-wide; scalar or length-ncol)
3. `col_spec[[j]]$align`          (inherit data alignment)

#### `col_header`: spanning rows mixed with label rows

`col_header` can now be a list whose elements are either:

* character vectors — regular label rows, one entry per data column;
* spanning rows — `list(list(from, to, label, underline), ...)`, with
  the same structure that has always been accepted by
  `spanning_header`.

This makes multi-row column headers with spanning groups expressible
inline:

```r
rtftable(df, col_header = list(
  # Row 1: spanning header
  list(
    list(from = 2, to = 3, label = "Drug A (N=30)", underline = TRUE),
    list(from = 4, to = 5, label = "Drug B (N=30)", underline = TRUE)
  ),
  # Row 2: regular labels
  c("Item", "N", "Mean", "N", "Mean")
))
```

The standalone `spanning_header` argument is retained for backward
compatibility.

### 🔴 Breaking Changes (v0.0.11)

#### Magic blank-row tokens removed; title / footnote return to text paragraphs

The short-lived `{HALF_BLANK_ROW}` / `{BLANK_ROW}` magic tokens introduced in
v0.0.9 are removed. Blank rows inside titles, footnotes, and
`rtf_header()` / `rtf_footer()` rows are now expressed with the empty string
`""` only, and there is no half-height shortcut. (Per-row twips control is
deferred to a later release.)

Rendering changes:

* **Title** is back to ordinary RTF paragraphs (was a 1-column table in
  v0.0.9–v0.0.10). Each element of the character vector becomes one
  `\par`. `""` yields a blank paragraph at the document font size.
  `title = NULL` (the default) emits one blank centred paragraph; use
  `title = character(0)` to suppress the block entirely. The default
  alignment is centre and non-empty lines are bold.
* **Footnote** is now also a paragraph block (was a 1×1 table, then a
  N×1 table). Each element is one paragraph; the first paragraph carries
  the top border (`\brdrt\brdrs\brdrw15`) acting as the visual separator
  from the content above.
* **`rtf_header()` / `rtf_footer()`** rows no longer recognise magic
  tokens. `c(c = "")` is a normal-height empty row.

#### Column-header bold default flipped to `FALSE`

`rtftable()` previously rendered column headers in bold. The default is
now normal weight (`header_bold = FALSE`). Set it via `col_spec` per
column to restore bold.



#### Header / footer cells now share the content-table cell padding

Cells emitted by `rtf_header()` / `rtf_footer()` were rendered without
`\li` / `\ri` padding, while content-table cells used 72 twips on both
sides — so header text sat flush against the cell border. v0.0.10 emits
the same `\li{pad_l}\ri{pad_r}` for header and footer cells (and for the
half-blank row variant). Defaults come from
`inst/resources/rtfreporter_defaults.R`:

```r
default_cell_padding_left_twips  = 72L
default_cell_padding_right_twips = 72L
```

`rtf_header()` and `rtf_footer()` gain `cell_padding_left_twips` /
`cell_padding_right_twips` arguments for per-block overrides (NULL =
inherit from the resource file).

### ✨ Features

#### Title and footnote blocks: per-row rendering + magic blank-row tokens

Titles and footnotes are now rendered as N×1 RTF tables (one row per
element of the character vector). Two magic tokens control blank rows in
title, footnote, `rtf_header()`, and `rtf_footer()` row content:

| Token | Effect |
|---|---|
| `"{HALF_BLANK_ROW}"` | Empty row at half the default row height |
| `"{BLANK_ROW}"` (or just `""`) | Empty row at the default row height |

Default title behaviour changed: a page with `title = NULL` now emits one
`{HALF_BLANK_ROW}` automatically so there is always a small visual gap
between the page header and the content.  Use `title = character(0)` to
suppress the title block entirely.

```r
rtf_tables(doc, list(df1, df2),
  titles    = list(c("Table 14.1.1", "{HALF_BLANK_ROW}", "Safety Population"),
                   "Table 14.1.2"),
  footnotes = list(c("Note 1: foo.", "{HALF_BLANK_ROW}", "Note 2: bar."),
                   NULL)
)
```

#### `rtf_tables()` / `rtf_figures()` gain `titles` and `footnotes` arguments

Each is a list parallel to `tables` / `figures`. Per-element `NULL`
falls back to the default (title = one `{HALF_BLANK_ROW}`, footnote =
no block).

#### `rtf_titles()` / `rtf_footnotes()` standalone setters

Replace per-page titles / footnotes after content has been added. Length
must equal the current number of pages.

### 🔴 Breaking Changes

#### Default row height is now font-size-aware and unified across elements

Previously the package shipped two unrelated default row heights:
the RTF page header / footer used `360` twips (from
`rtfreporter_defaults.R`), while table bodies emitted **no** `\trrh` at all
when `row_height_twips` was left at its `0L` default. Footnotes had no row
height either. As a result, raising the document font size left the visual
layout out of sync.

In v0.0.8 every table-shaped element (RTF header, RTF footer, table column
header rows, table data rows, blank separator rows, footnote rows) shares a
single, font-size-aware default looked up from
`inst/resources/rtfreporter_defaults.R`:

```r
default_row_height_twips_by_font_half_points = list(
  "16" = 210L,   #  8pt
  "18" = 230L,   #  9pt  ← package default
  "20" = 250L,   # 10pt
  "22" = 270L,   # 11pt
  "24" = 290L,   # 12pt
  ...
)
```

Admins can edit the table (or the linear fallback below it) without
touching package code. Explicit per-element values still take precedence.

**Migration:** Existing code that explicitly sets `row_height_twips = 280L`
(etc.) is unaffected. Code relying on `row_height_twips = 0L` to mean
"automatic / no `\trrh`" continues to work — `0L` is still accepted as the
legacy value. The new default behaviour applies whenever
`row_height_twips` is `NULL` (the new default in `rtftable()` /
`rtf_tables()`).

---

#### `default_format` now propagates from `rtf_document()` to the renderer

Previously, `default_format = list(font_size_half_points = 24L, ...)` passed
to `rtf_document()` was stored on the S3 object but the pipe-to-R6 adapter
dropped it, so the renderer always used the built-in 9pt default. v0.0.8
wires `default_format` through to the R6 report so font size, line spacing,
etc. actually take effect (and feed the new row-height lookup above).

---

### 🔴 Breaking Changes

#### Pipe API formatting moved into `rtf_tables()` / `rtf_figures()`

The four standalone format functions did not actually affect rendered RTF
output — values were stored but never read by the renderer. They are now
deprecated and replaced by formatting arguments on the constructor functions:

```r
# Old (v0.0.6, never worked):
doc <- rtf_document() %>%
  rtf_tables(list(df1, df2)) %>%
  rtf_table_format(pages = "all", border = "tfl", row_height_twips = 280L)

# New (v0.0.7):
doc <- rtf_document() %>%
  rtf_tables(list(df1, df2),
             border = "tfl", row_height_twips = 280L,
             col_rel_width = c(2, 1, 1))
```

Affected functions: `rtf_table_format()`, `rtf_header_format()`,
`rtf_footer_format()`, `rtf_figure_format()`. They remain available as
`.Deprecated()` no-ops; planned for removal in a future release.

**Migration:** Move each formatting argument directly onto `rtf_tables()` or
`rtf_figures()` (for shared defaults across bare `data.frame` / path items),
or onto `rtftable()` / `rtfplot()` (for per-item control). For header/footer
border and row height, set them on `rtf_header()` / `rtf_footer()` directly.

---

#### One content per page enforced

Each element of `rtf_tables()` / `rtf_figures()` now corresponds to exactly
one page (one table **or** one figure). The previously documented but
silently broken pattern `list(df1, list(rtfplot(...), rtftable(df2)))`
(multiple items on one page) is rejected at validation time.

**Migration:** Place each table / figure on its own page (consecutive pages
in the same section share the section header).

---

#### `rtf_figures()` runtime bug fixed

Previously crashed at render time because paths were wrapped in `list(path)`
but the renderer expected `rtfplot_r6` objects. Paths are now promoted to
`rtfplot_r6`, and `width_twips` / `height_twips` / `align` may be supplied
to `rtf_figures()` directly. Pre-built `rtfplot()` objects in `figures` are
accepted unchanged.

---

### 🔴 Breaking Changes

#### R6 classes are now private; public API is S3 functions only

Previously, users called R6 class constructors directly:
```r
# Old (v0.0.5):
report <- rtfreport$new()
tbl    <- rtftable$new(df, ...)
fig    <- rtfplot$new("path/to/img.png")
```

In v0.1.0, use S3 wrapper functions:
```r
# New (v0.1.0):
report <- rtfreport()
tbl    <- rtftable(df, ...)
fig    <- rtfplot("path/to/img.png")
```

**Migration:** Replace all `ClassName$new(...)` with `ClassName(...)`.  
**Reason:** Cleaner public API; internal R6 classes renamed to `rtftable_r6`, `rtfplot_r6`, `rtfreport_r6` for clarity.

---

#### Content type auto-detection; explicit `type` field no longer required

Previously, `add_page()` required explicit block specifications with `type`:
```r
# Old (v0.0.5):
report$add_page(
  section_index = sec,
  content = list(
    list(type = "table", data = rtftable$new(df, ...)),
    list(type = "figure", data = rtfplot$new("img.png"))
  )
)
```

In v0.1.0, objects are auto-detected from their class:
```r
# New (v0.1.0):
report$add_page(
  section_index = sec,
  content = list(
    rtftable(df, ...),
    rtfplot("img.png")
  )
)
```

**Auto-detection rules:**
- `rtftable_r6` → `type = "table"`
- `rtfplot_r6` → `type = "figure"`
- `data.frame` → `type = "table"`
- File path (`character(1)`) → `type = "figure"`

**Migration:** Simplify content lists by passing objects directly. Backward compatibility: explicit `type` field still works internally.

---

### ✨ Features

#### Multi-line content titles and footer notes

`title` and `footer_notes` in `add_page()` now accept character vectors for multiple lines:
```r
report$add_page(
  section_index = sec,
  title = c("Line 1", "Line 2"),
  footer_notes = c("Note 1", "Note 2")
)
```

---

### 🔧 Internal Changes

- R6 classes renamed for clarity:
  - `rtftable` → `rtftable_r6`
  - `rtfplot` → `rtfplot_r6`
  - `rtfreport` → `rtfreport_r6`
- New internal helper `.normalize_content_item()` for block type auto-detection
- S3 wrapper functions created in `r/wrappers.R`

---

## v0.0.5 and earlier

Not recorded (pre-v0.1.0).
