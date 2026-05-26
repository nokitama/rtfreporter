# Learning Notes — R6 vs S3 in `rtfreporter`

`rtfreporter` is also intended as a small but realistic case study in how to
choose between R6 and S3 inside a single R package. This file documents
**which class system each public concept uses, and why**.

The rule of thumb followed throughout the codebase:

> **Use S3 for data; use R6 for state.**
> Pick S3 by default; reach for R6 only when reference semantics, mutation,
> or method chaining genuinely improves the API. Then document the choice
> next to the class definition.

---

## Summary table

| Concept | Class system | File | Reason in one line |
|---|---|---|---|
| `rtf_border_side` | **S3** (list) | [`R/rtf_border.R`](R/rtf_border.R) | Tiny immutable value object (style + width + colour). |
| `rtf_border` | **R6** (since v0.0.13) | [`R/rtf_border.R`](R/rtf_border.R) | Builder pattern (`with_top()`, `apply_override()`) and shareable reference across many tables. |
| `rtf_table_border` | **S3** (list) | [`R/rtf_border.R`](R/rtf_border.R) | Passive grouping of borders by zone; no behaviour of its own; `dput()`-able. |
| `rtf_table_style` | **R6** | [`R/rtf_table_style.R`](R/rtf_table_style.R) | Shared mutable theme: define once, hand to many `rtftable()`s, tweak later → every referencing table reflects the change. |
| `rtfreport_r6` | **R6** | [`R/rtfreport.R`](R/rtfreport.R) | Build-time scaffold with `add_page()` / `add_section()` mutators; lives briefly between the pipe API and the renderer. |
| `rtftable_r6` | **R6** | [`R/rtftable.R`](R/rtftable.R) | Same reason: short-lived mutable scaffold with rich state. |
| `rtfplot_r6` | **R6** | [`R/rtfplot.R`](R/rtfplot.R) | Same reason; symmetric with `rtftable_r6`. |
| `rtf_page`, `rtf_sect` | **S3** (tagged lists) | [`R/rtfreport.R`](R/rtfreport.R) | Plain data records sitting inside `rtfreport_r6$pages` / `$sections`. |
| `rtf_document` (pipe API) | **S3** | [`R/pipe-composition.R`](R/pipe-composition.R) | Immutable functional composition — `%>%` returns a fresh copy each step. |
| `rtf_blank_rows_by_change` / `_by_rule` | **S3** (tagged lists) | [`R/blank_rows.R`](R/blank_rows.R) | Tiny specification records; no methods needed. |
| `rtf_auto_section_item` | **S3** (tagged list) | [`R/pipe-composition.R`](R/pipe-composition.R) | A render-time sentinel; pure data. |

---

## Why S3 is the default

S3 is R-idiomatic, lightweight, and has properties that matter for a data
manipulation / reporting package:

* **`dput()` / `str()` / `print()` show real content.** Debugging is easy.
* **`saveRDS()` / `loadRDS()` round-trip cleanly.** Environments inside R6
  objects can interact poorly with serialisation in subtle ways.
* **Pure values compose with `%>%`.** Each pipe step returns a new copy and
  reasoning is purely functional.
* **Type dispatch via `UseMethod()`** is enough for the common "different
  flavours of the same concept" pattern (e.g. `print.rtf_border_side()`).

So for **value-like things** — a single border edge, a list of zone
borders, a record of "rows where the value changes" — S3 is unambiguously
better.

---

## Why these things are R6

### 1. `rtf_border` — builder pattern + shared mutable defaults

A border has four sides. Three usage patterns make R6 nicer than S3:

```r
# Chained builder: mutate self, return self
b <- rtf_border()$set_top(rtf_border_side())$set_bottom(rtf_border_side("double"))

# Non-mutating derivation
b2 <- b$with_right(rtf_border_side("dot"))   # b unaffected

# Apply an override in place — every site referencing `b` sees the change
b$apply_override(some_other_border)
```

The same in pure S3 would either need a verbose, allocating helper
(`rtf_border_set_top(b, side)` returning a new list) or break the
"shared reference" use case.

Backward compatibility is preserved: the R6 class carries `classname =
"rtf_border"`, so existing code that does `inherits(x, "rtf_border")` and
`x$top` / `x[["top"]]` continues to work unchanged.

### 2. `rtf_table_style` — themes shared across many tables

This is the **canonical "you really want R6"** use case in `rtfreporter`:

```r
# Define a theme once
tfl <- rtf_table_style_tfl()

# Hand the same instance to dozens of tables
tables <- lapply(dfs, function(df) rtftable(df, style = tfl))

# Tweak the theme — every table picks it up
tfl$header_bold <- TRUE     # (or use a setter)
```

With S3 lists, each `rtftable()` call would snapshot a copy of the style.
Subsequent mutations would only affect later-constructed tables. R6's
reference semantics give the intuitive "global theme" behaviour.

For users who want immutable derivation, `style$clone_with(header_bold =
TRUE)` returns an independent copy — the best of both worlds.

### 3. `rtfreport_r6` / `rtftable_r6` / `rtfplot_r6` — build-time scaffolds

These are the internal objects produced by `.pipe_doc_to_r6_report()` for
the renderer to walk. Their construction loop calls `add_page()`,
`add_section()`, etc. — many small mutations to one object. R6 makes that
ergonomic. The pipe API on top is still immutable; users never see R6.

Note that these are deliberately **not exported**. The S3 wrappers
(`rtftable()`, `rtfplot()`) are the public API.

---

## When *not* to use R6

A few features of R6 look attractive in isolation but cost more than they
give for this package:

* **Active bindings** — useful for computed-on-access properties, but our
  fields are plain data. Active bindings would add a layer of indirection
  that obscures `str()` output.
* **Private fields** — encapsulation is rarely the bottleneck; documented
  conventions and `.foo` naming work fine here.
* **`finalize()`** — we never hold OS resources (files / connections /
  ports), so there is nothing to clean up.

---

## Migration patterns used here

When an S3 list-based concept was promoted to R6 (e.g. `rtf_border` in
v0.0.13), the following techniques kept user code working:

1. **Set `R6Class(classname = "rtf_border", ...)`** so the S3 class name is
   preserved. `inherits(x, "rtf_border")` continues to return `TRUE`.
2. **Keep the same constructor signature.** `rtf_border(top = ..., bottom
   = ...)` produces an R6 instance now, but reads identically at call
   sites.
3. **Audit `[[` / `$` access** at the call sites. R6 supports both —
   nothing to change.
4. **Audit *mutation* of fields.** Any internal helper that did
   `base$top <- new_top` on a list (creating an implicit copy) must now
   `clone()` first to avoid mutating shared references. See
   `.merge_rtf_border()` in [`R/rtf_border.R`](R/rtf_border.R) for the
   pattern.

---

## Further reading

* Advanced R, 2nd ed. — "Object-oriented programming" part:
  <https://adv-r.hadley.nz/oo.html>
* R6 vignette: <https://r6.r-lib.org/articles/Introduction.html>
* S7 (the new "official" formal OO system, not yet adopted here):
  <https://github.com/RConsortium/S7>
