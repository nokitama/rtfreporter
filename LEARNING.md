# Learning Notes — S3 architecture in `rtfreporter`

`rtfreporter` is implemented entirely with S3 classes — there is no R6
anywhere in the package.  This document records *why*, because earlier
versions of the codebase mixed S3 and R6 and the path back to a uniform
S3 design is itself instructive.

The rule of thumb is now simply:

> **Use S3 for data.  Reach for R6 only when reference semantics,
> long-lived state, or method chaining genuinely improves the API —
> and `rtfreporter` has none of those.**

---

## Summary table

| Concept | Class system | File | Notes |
|---|---|---|---|
| `rtf_border_side` | **S3** (tagged list) | [`R/rtf_border.R`](R/rtf_border.R) | Tiny immutable value object (style + width + colour). |
| `rtf_border` | **S3** (tagged list) | [`R/rtf_border.R`](R/rtf_border.R) | Four-edge spec; derive variants with `rtf_border_with()`. |
| `rtf_table_border` | **S3** (tagged list) | [`R/rtf_border.R`](R/rtf_border.R) | Passive grouping of `rtf_border`s by zone. |
| `rtf_table_style` | **S3** (tagged list) | [`R/rtf_table_style.R`](R/rtf_table_style.R) | Bundle of table defaults; derive variants with `rtf_table_style_with()`. |
| `rtfreport` | **S3** (internal tagged list) | [`R/rtfreport.R`](R/rtfreport.R) | Internal scaffold built by the pipe adapter; the renderer consumes it. |
| `rtftable` | **S3** (tagged list) | [`R/rtftable.R`](R/rtftable.R) | Public content record built by `rtftable()`. |
| `rtfplot` | **S3** (tagged list) | [`R/rtfplot.R`](R/rtfplot.R) | Public content record built by `rtfplot()`. |
| `rtf_page`, `rtf_sect` | **S3** (tagged lists) | [`R/rtfreport.R`](R/rtfreport.R) | Data records sitting inside `rtfreport$pages` / `$sections`. |
| `rtf_document` (pipe API) | **S3** | [`R/pipe-composition.R`](R/pipe-composition.R) | Immutable functional composition — `%>%` returns a fresh copy each step. |
| `rtf_blank_rows_by_change` / `_by_rule` | **S3** (tagged lists) | [`R/blank_rows.R`](R/blank_rows.R) | Tiny specification records. |
| `rtf_auto_section_item` | **S3** (tagged list) | [`R/pipe-composition.R`](R/pipe-composition.R) | A render-time sentinel; pure data. |

---

## Why S3 (everywhere)

S3 is R-idiomatic, lightweight, and has properties that matter for a
data-manipulation / reporting package:

* **`dput()` / `str()` / `print()` show real content.** Debugging is easy
  and serialization (`saveRDS()` / `loadRDS()`) round-trips cleanly.
* **Pure values compose with `%>%`.** Each pipe step returns a new copy
  and reasoning is purely functional.
* **Copy-on-modify is the default.** A border or style handed to many
  tables can never be mutated through a back door.
* **No extra dependency.** S3 is part of base R; there is no `Imports:`
  cost.

---

## Why R6 was removed

Earlier versions used R6 for `rtfreport_r6`, `rtftable_r6`, `rtfplot_r6`,
`rtf_border`, and `rtf_table_style`.  Each of those choices was revisited
and found to be paying complexity without delivering anything in return.

### 1. `rtfreport_r6` / `rtftable_r6` / `rtfplot_r6` — short-lived scaffolds

These existed only inside `.pipe_doc_to_rtfreport()` and the renderer;
users never held one.  Construction did a few mutations
(`add_page()`, `add_section()`) and then the object was read once.  An
S3 list with functional helpers (`.rtfreport_add_page(rep, ...)`
returning a new copy) does the same job in fewer lines, with the bonus
that the result is `dput()`-able and serializable.

### 2. `rtf_border` (R6) — chained builders that nobody used

The R6 implementation exposed `$set_top()`, `$with_top()`,
`$apply_override()`, `$override()` etc.  Outside one internal call site
(`generate_rtfreport.R`'s spanning-row border resolution) and the
package's own tests, none of these were used.  The single internal site
was a one-liner that became `.merge_rtf_border(eff, rtf_border(bottom = ...))`
under the S3 design — simpler, not harder.  Users who do want
non-mutating derivation now call `rtf_border_with(b, top = ...)`.

### 3. `rtf_table_style` (R6) — the "shared mutable theme" that wasn't

This was billed as the canonical R6 win: define a theme once, hand the
same instance to many tables, mutate it, watch every table reflect the
change.  In practice this only worked for nested `rtf_border` mutations
that happened to be passed through `as_table_border()` unchanged.  Every
scalar field (`header_bold`, `header_align`, `cell_padding_*`, …) was
**snapshotted by the rtftable constructor at build time**, so mutating
the style after construction was silently ignored.  The promised
semantics were inconsistent; the simpler S3 model (build the style,
hand it to tables, derive variants with `rtf_table_style_with()`) is
honest about what actually happens.

---

## What this means for users

* All public objects are plain S3 lists.  `inherits(x, "rtf_border")`,
  field access via `x$top` / `x[["top"]]`, and `unclass(x)` all work as
  expected.
* To derive a border from another, use `rtf_border_with(b, bottom = ...)`.
* To derive a style from another, use `rtf_table_style_with(s, header_bold = TRUE)`.
* Multiple tables that share the same style snapshot defaults at
  construction.  To "change the theme", build a new style with
  `rtf_table_style_with()` and pass it to new tables — there is no
  hidden propagation.
