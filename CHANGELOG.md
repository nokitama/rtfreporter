# Changelog

All notable changes to rtfreporter are documented in this file. Changes are recorded for **major.minor** version releases only (v0.1.0, v0.2.0, etc.). Patch and development versions (v0.1.1, v0.0.6, v0.0.dev, etc.) are not recorded.

---

## v0.1.0 (TBD - when ready for public release)

> **Status**: Currently in development as v0.0.6. Will be released as v0.1.0 when complete.

### 🔴 Breaking Changes

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
