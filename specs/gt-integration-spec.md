# GT integration specification (v0.1.0 roadmap)

## Goal

Allow users to feed a `gt::gt_tbl` object directly to `rtf_tables()` and
have rtfreporter optionally read GT's column labels, spanners, title,
source notes, alignment, and other table-level configuration -- so the
user does not have to re-state them.

> **Default behaviour is unchanged.**  All GT attribute extraction is
> opt-in via a single argument `read_gt =` (Boolean or selective vector).

---

## 1. How GT stores its configuration

After studying the gt v1.3 source under `R/dt_*.R`, every component of a
`gt_tbl` lives at a stable named slot.  All slots are accessible via the
public `[[` operator (gt's internal `dt__get()` is just `data[[key, exact = TRUE]]`).

| GT slot               | Field accessor (public)             | Shape                                                                 |
|-----------------------|--------------------------------------|------------------------------------------------------------------------|
| `_boxhead`            | `gt_obj[["_boxhead"]]`               | tibble(var, type, column_label, column_units, column_pattern, column_align, column_width, hidden_px) |
| `_heading`            | `gt_obj[["_heading"]]`               | list(title, subtitle, preheader)                                       |
| `_spanners`           | `gt_obj[["_spanners"]]`              | tibble(vars, spanner_label, spanner_units, spanner_pattern, spanner_id, spanner_level, gather, built) |
| `_source_notes`       | `gt_obj[["_source_notes"]]`          | list of (character or markdown_text)                                    |
| `_footnotes`          | `gt_obj[["_footnotes"]]`             | tibble(locname, grpname, colname, locnum, rownum, colnum, footnotes, placement) |
| `_stub_df`            | `gt_obj[["_stub_df"]]`               | tibble(rownum_i, row_id, group_id, group_label, indent, built_group_label) |
| `_stubhead`           | `gt_obj[["_stubhead"]]`              | list(label)                                                            |
| `_row_groups`         | `gt_obj[["_row_groups"]]`            | character vector of group ids in display order                          |

The rendered body (formulas applied, `fmt_*` substitutions resolved) is
exposed via the **public** S3 method:

```r
as.data.frame(gt_obj)   # -> data.frame, characters in cell form
```

This is the only public API gt offers for "give me the visible table."
We will use it as the data source.

---

## 2. New rtfreporter API

### 2.1 Single entry point

```r
rtf_tables(doc, tables, ..., read_gt = FALSE)
```

`tables` may now contain `gt_tbl` objects mixed freely with data.frames
and `rtftable()` results.

* `read_gt = FALSE` (default) -- The `gt_tbl` is converted via
  `as.data.frame()` and treated like a bare data.frame.  All explicit
  formatting arguments (`col_header`, `col_spec`, `border`, ...) win.
  This is the **safe default**: identical to v0.0.x behaviour modulo
  the implicit `as.data.frame()`.
* `read_gt = TRUE` -- Every GT attribute listed in Section 3 below is
  read and used to fill in `col_header`, `col_spec`, `titles[[i]]`,
  and `footnotes[[i]]` for the corresponding page (unless the user
  has already supplied that attribute explicitly).
* `read_gt = c("col_header", "titles", ...)` -- selective opt-in.
  Only the listed attributes are read; the rest fall back to the
  default behaviour.

Resolution precedence (highest wins):

    explicit rtf_tables() argument
      > explicit titles[[i]] / footnotes[[i]] / col_spec entries
      > GT-extracted value
      > rtfreporter default

### 2.2 Selective opt-in vocabulary

| Token              | What it imports                                         |
|--------------------|---------------------------------------------------------|
| `"col_header"`     | column labels (`_boxhead$column_label`)                 |
| `"spanning"`       | multi-level spanner header (`_spanners`)                |
| `"alignment"`      | per-column alignment (`_boxhead$column_align`)          |
| `"widths"`         | per-column width (`_boxhead$column_width`, in px)       |
| `"hidden"`         | drop columns with `_boxhead$type == "hidden"`           |
| `"titles"`         | title + subtitle (`_heading$title`, `_heading$subtitle`)|
| `"source_notes"`   | source notes (`_source_notes`)                          |
| `"footnotes"`      | mark-based footnotes (`_footnotes`)                     |
| `"stub"`           | stub column + group rows (`_stub_df`, `_stubhead`)      |

`read_gt = TRUE` is shorthand for `c("col_header", "spanning",
"alignment", "titles", "source_notes")` -- the five items that
unambiguously map to existing rtfreporter slots without changing the
output's shape.

`"widths"`, `"hidden"`, `"footnotes"`, `"stub"` are opt-in only
because they materially change the row/column structure.

### 2.3 Standalone helper (for `rtftable()`)

```r
as_rtftable(gt_obj, read = TRUE, ...)
```

Identical to `rtftable(as.data.frame(gt_obj), ...)` but applies the
GT->rtftable attribute mapping before constructing the rtftable.
Returned object is a plain `rtftable` -- the `gt_tbl` is consumed
once, no live dependency on gt at render time.

---

## 3. Per-attribute mapping rules

### 3.1 col_header (`"col_header"`)

```r
boxh <- gt_obj[["_boxhead"]]
visible <- boxh[boxh$type != "hidden", ]
labels <- vapply(visible$column_label,
                 function(x) as.character(x[[1]]), character(1))
```

Use `labels` as the *bottom row* of `rtf_col_header`.  If the user
also opted in to `"spanning"`, the spanner labels go *above* this row
(Section 3.2).

### 3.2 spanning header (`"spanning"`)

```r
spans <- gt_obj[["_spanners"]]
visible_vars <- visible$var
# spans$spanner_level: 1, 2, ...  Higher level -> rendered ABOVE lower.
```

For each `spanner_level`, build a row of `col_cell(pos = match(vars, visible_vars), label = spanner_label)`.
Concatenate top-to-bottom in **descending** `spanner_level` order, then
append the bottom row from 3.1.

### 3.3 alignment (`"alignment"`)

```r
col_align <- visible$column_align       # "left" / "center" / "right"
# Fed into col_spec[[j]]$align unless the user supplied col_spec already.
```

### 3.4 widths (`"widths"`)

```r
widths_px <- vapply(visible$column_width,
                    function(w) if (length(w)) as.numeric(w[[1]]) else NA_real_,
                    numeric(1))
# Convert px -> twips: 1 px = 15 twips (CSS-style 96 dpi convention).
widths_twips <- round(widths_px * 15)
# Only apply when all are non-NA; otherwise fall back to col_rel_width
# proportional split.
```

### 3.5 hidden (`"hidden"`)

```r
visible_mask <- boxh$type != "hidden"
df_visible   <- as.data.frame(gt_obj)[, boxh$var[visible_mask], drop = FALSE]
```

This is the **only** GT attribute that changes the data.frame shape,
which is why it's opt-in.

### 3.6 titles (`"titles"`)

```r
heading <- gt_obj[["_heading"]]
title_rows <- c(heading$title, heading$subtitle, heading$preheader)
```

Set as `titles[[i]]` (the page's title block).  Preheader is rendered
above title in gt; we honour that.

### 3.7 source notes (`"source_notes"`)

```r
src <- gt_obj[["_source_notes"]]
src_text <- vapply(src, as.character, character(1))   # markdown_text -> chr
```

Append to `footnotes[[i]]`.  If `"footnotes"` is also opted in (3.8),
source notes come *after* the cell-level footnote block.

### 3.8 footnotes (`"footnotes"`)

```r
fn_df <- gt_obj[["_footnotes"]]
# Sort by colnum / rownum, build "{mark} {text}" rows
# Mark generation follows gt's footnote_glyphs: "a", "b", "c", ...
```

This is the most invasive opt-in because cell-level footnotes also need
mark *insertion* into the corresponding cell.  v0.1.0 will support
**table-level only** (i.e. emit the footnote text rows but *not* inject
marks into cells).  Cell-mark injection is deferred to a later release.

### 3.9 stub (`"stub"`)

```r
stub_df <- gt_obj[["_stub_df"]]
stubhead <- gt_obj[["_stubhead"]]
```

Becomes the leftmost column with:
* `stubhead$label` as its `col_header` label,
* group rows (`group_label != NA`) as bold spanning rows above the
  group's data,
* `indent` (in em-style increments) translated to leading non-breaking
  spaces in the cell text.

Stub support requires the **multi-DF mode** of `rtftable()` so each
group becomes a sub-table; deferred to v0.1.0-late or v0.2.0 unless
critical.

---

## 4. Implementation phases

### Phase A -- MVP for v0.0.38

Just enough for the headline use cases:

* `as_rtftable()` helper that takes a `gt_tbl` and applies the
  selected attributes.
* `rtf_tables()` accepts `gt_tbl` in its `tables = list(...)` argument
  via `as.data.frame()` (with or without `read_gt`).
* Support tokens: `"col_header"`, `"alignment"`, `"titles"`,
  `"source_notes"`.
* `read_gt = TRUE` expands to all four.

Scope -- 4 files, ~200 LOC:
* `R/gt_adapter.R` -- new file with extraction + mapping functions.
* `R/pipe-composition.R` -- accept gt_tbl in `rtf_tables()`.
* `R/wrappers.R` -- new `as_rtftable()` export.
* `tests/testthat/test-gt-adapter.R` -- unit + end-to-end tests.

### Phase B -- v0.0.39

Add the more structural opt-ins:

* `"spanning"` (multi-level spanner -> rtf_col_header rows)
* `"widths"` (column_width -> column_widths_twips)
* `"hidden"` (drop hidden columns from data)

### Phase C -- v0.0.40 (shipped)

* `"footnotes"` (table-level only; cell-mark injection deferred)
* `"stub"` (drops groupname_col, interleaves group rows, applies
  stubhead label to col 1)
* Vignette: `vignette("gt-integration", package = "rtfreporter")`
* `pkgdown` reference section for `as_rtftable()` and `read_gt`.

---

## 5. Edge cases / decisions

### 5.1 Gt depends on gt (Suggests, not Imports)

`gt` stays in `Suggests` (already there).  The adapter functions guard
with `requireNamespace("gt", quietly = TRUE)` and raise an informative
error if `gt` is missing when a `gt_tbl` is fed in.

### 5.2 markdown_text fields

GT's title / subtitle / source_notes can be plain character OR
`markdown_text` (`md()`).  We extract the raw text via
`as.character()` -- the markdown will not be rendered (gt renders to
HTML; rtfreporter doesn't have a markdown subsystem).  A future
enhancement could parse common spans (bold, italic) into rtfreporter's
`^{...}` / `_{...}` markup, but that's out of scope for v0.1.0.

### 5.3 Built vs unbuilt gt_tbl

`as.data.frame.gt_tbl` calls `build_data()` internally, so we always
get the *formatted* cell text -- `fmt_number()`, `fmt_percent()`, etc.
all applied.  No need for the user to call `gt::build()` manually.

### 5.4 Bookmarking / cross-references

GT's footnote marks are tied to specific cells.  Implementing
cell-mark injection in v0.1.0 would require us to thread mark
characters through `rtftable()`'s cell renderer, which is a wider
change than the rest of the adapter.  Deferred to v0.2.0.

### 5.5 Multi-DF / paginated source

When a single `gt_tbl` produces a very long table that would span
multiple rtfreporter "pages," GT itself doesn't paginate -- the rtfreporter
side already handles that via `paginate()`.  Behavior unchanged:
the GT cell formatting is applied once, then `paginate()` slices.

---

## 6. Test plan

* **Unit tests** for each extraction helper (`.extract_col_labels`,
  `.extract_heading`, `.extract_spanners`, `.extract_source_notes`,
  `.extract_alignment`, `.extract_widths`, `.extract_hidden_mask`,
  `.extract_footnotes_text`, `.extract_stub`).
* **Integration tests** that wrap a small `gt::gt(mtcars)`-style
  example, run it through `rtf_tables(..., read_gt = TRUE)`, render
  to RTF, and grep for the expected substrings (column labels,
  spanner labels, title, source-note text).
* **No-gt skip**: every test skips with
  `skip_if_not_installed("gt")` so CRAN runs that don't have gt
  pass cleanly.

Aim: 100% line coverage of `R/gt_adapter.R`, no regressions in any
other module.

---

## 7. Open questions

1. **`column_width` unit interpretation.**  gt stores px (with unit
   strings like `"100px"` or `"15%"`).  Percentages are relative to the
   table width.  For the Phase B implementation we will:
   * Parse `"NN px"` -> NN, multiply by 15 to get twips.
   * Parse `"NN%"` -> fraction, feed into `col_rel_width`.
   * Mixed -> warn, fall back to equal distribution.

2. **Markdown stripping vs preservation.**  Title `md("**Demographics**")`
   is rendered as bold in HTML.  For v0.1.0 we strip to plain
   `"Demographics"`.  Should we instead translate `**...**` to `^{...}`
   markup?  (Note: rtfreporter has no bold-in-text markup yet either;
   that would itself need to be added.)

3. **`as_rtftable()` argument naming.**  Should the import argument be
   `read = TRUE` (short) or `read_gt = TRUE` (explicit)?  In the
   wrapper, `read_gt` is redundant since the input is already known to
   be a gt_tbl, so `read = TRUE` is fine and reads naturally.
