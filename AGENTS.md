# Agent Instructions for rtfreporter

## ⚠️ Mandatory first step

**Before modifying any code, test, or documentation, always read the specs files first.**

```
specs/api_contract.md               ← Public API definitions (R and Python)
specs/feature_proposal_20260515.md  ← Approved implementation specs
specs/release_guidelines.md         ← Release and packaging rules
```

The specs are the **single source of truth**. All R code, Python code, tests, and
vignettes must conform to the specs. If a spec and code disagree, the spec wins
unless the user explicitly asks to change the spec first.

---

## Workflow rule

1. **Read relevant spec sections** before writing any code.
2. **Update specs first** when a design decision changes (API shape, behavior,
   defaults, data structures).
3. **Then update** in this order:
   - R implementation (`R/`)
   - R help (`man/`, roxygen comments in `R/`)
   - R vignettes (`vignettes/`)
   - R tests (`tests/`)
   - Python implementation (`python/src/rtfreporter/`)
   - Python tests (`python/tests/`)
4. Never introduce an API pattern in code that is not documented in the specs.

---

## Repository structure

This repository **is the R package** (DESCRIPTION is at the root). R is the primary
language. Python is an experimental secondary implementation maintained in a
subdirectory.

```
rtfreporter/                        ← repo root = R package root (CRAN-ready layout)
├── AGENTS.md                       ← This file (read first)
├── DESCRIPTION                     ← R package manifest
├── NAMESPACE
├── LICENSE
├── README.md
├── rtfreporter.Rproj
│
├── R/                              ← R source files
│   ├── rtfreport.R
│   ├── rtf_border.R               ← Border class hierarchy (rtf_border_side, rtf_border, rtf_table_border)
│   ├── generate_rtfreport.R
│   ├── rtftable.R
│   ├── rtfplot.R
│   └── hello.R
│
├── man/                            ← R help files (*.Rd) — update when API changes
│   ├── rtfreport.Rd
│   ├── rtf_border.Rd               ← Border class docs (rtf_border_side, rtf_border, etc.)
│   ├── generate_rtfreport.Rd
│   ├── rtftable.Rd
│   ├── rtfplot.Rd
│   └── hello_rtfreporter.Rd
│
├── tests/                          ← R tests (run with Rscript tests/test_rtfreport.R)
│   ├── test_rtfreport.R            ← primary test suite (must pass before any commit)
│   ├── test_rtfreport_old.R        ← backward-compat test (do NOT modify)
│   ├── quickstart_examples.R
│   ├── feature_test.R
│   ├── multisection_demo.R
│   └── rowheight_demo.R
│
├── vignettes/
│   └── rtfreporter-quickstart.Rmd
│
├── inst/
│   └── resources/
│       └── rtf_commands.R          ← RTF command definitions (shared with Python via JSON)
│
├── specs/                          ← Source of truth — always update before code
│   ├── api_contract.md
│   ├── feature_proposal_20260515.md
│   └── release_guidelines.md
│
└── python/                         ← ⚠️ Experimental — NOT a published package yet
    ├── README.md
    ├── pyproject.toml
    ├── src/rtfreporter/
    │   ├── core.py
    │   └── resources/rtf_commands.json
    └── tests/
        └── test_core.py
```

---

## Python subdirectory — important notes

- Python is an **experimental secondary implementation**. R is primary.
- Python code is maintained here for **development and API parity tracking only**.
  It is **not published to PyPI** at this time.
- Python API must mirror the R API as closely as Python idioms allow.
- In the future, `python/` will be **migrated to a separate repository**
  (tentatively `rtfreporter-py`) and published to PyPI independently.
- When developing Python code, write it as if it will be published (clean API,
  docstrings, tests, pyproject.toml). Avoid making it depend on the R package
  structure; it should be self-contained within `python/`.
- The Python `AGENTS.md` (when created at migration time) should reference
  `specs/` from the R repository as the source of truth until Python has its own.

---

## Key API rules (summary — see specs for full detail)

### Border class hierarchy

Three constructor functions build border specs, shared across header/footer and tables.
Always use these; never create raw border lists.

```r
# Single edge
s <- rtf_border_side(style = "single", width = 15L, color = NULL)
# style: "single" | "double" | "thick" | "dash" | "dot"
# color: NULL (black) or "#RRGGBB"

# Four edges for one cell/row
b <- rtf_border(top = s, bottom = NULL, left = NULL, right = NULL)

# Convenience shortcuts (all return rtf_border)
rtf_border_none()             # all NULL
rtf_border_top(style, width, color)   # top only
rtf_border_bottom(style, width, color)
rtf_border_box(style, width, color)   # all four sides

# Per-zone table border
tb <- rtf_table_border(
  header    = rtf_border(top = rtf_border_side(), bottom = rtf_border_side()),
  spanning  = NULL,
  body      = NULL,
  first_row = NULL,
  last_row  = rtf_border(bottom = rtf_border_side())
)

# TFL clinical preset
tb <- rtf_border_tfl()
```

### Header/Footer constructors

```r
hdr <- rtf_header(
  rows = list(
    c(l = "Protocol: RTF-101", r = "HOGE company"),
    c(l = "Study Title",       r = "Page {AUTO_PAGE} of {TOTAL_PAGES}")
  )
  # border = NULL (default: no border)
)
ftr <- rtf_footer(
  c(l = "Confidential")
  # border = rtf_border_top() (default: top dividing line)
)
report$add_section(header = hdr, footer = ftr)
```

Custom footer border:
```r
ftr <- rtf_footer(c(l = "Confidential"), border = rtf_border(top = rtf_border_side("thick", 20L, "#003366")))
```

Shorthand (single row, uses default border):
```r
report$add_section(
  header = c(l = "Protocol: RTF-101", r = "Page {AUTO_PAGE} of {TOTAL_PAGES}"),
  footer = c(l = "Confidential")
)
```

**Deprecated**: `top_border = TRUE/FALSE` still works but emits a warning.
Use `border = rtf_border_top()` / `border = NULL` instead.


### Header/Footer get/set methods

```r
# Set (after section creation)
report$set_section_header(sec_idx, hdr)
report$set_section_footer(sec_idx, ftr)

# Get
hdr <- report$get_section_header(sec_idx)
ftr <- report$get_section_footer(sec_idx)
```

### Header/Footer row format

Named keys: `l` = left, `r` = right, `c` = center.

**Column-count rules:**
- Only `l` / `c` / `r` → 1 column
- `l` + `r` (no `c`) → 2 columns
- `c` with `l` or `r`, or all three → 3 columns (missing keys fill with `""`)

Legacy `list(columns = c(...))` is accepted for backward compatibility but
**must not be written in new code**.

### Page tokens

| Token | Behavior |
|-------|----------|
| `{AUTO_PAGE}` | `\chpgn` — dynamic page number (recommended) |
| `{PAGE}` | Alias for `{AUTO_PAGE}` |
| `{TOTAL_PAGES}` | Static total page count at render time |
| `{AUTO_TOTAL_PAGES}` | Alias for `{TOTAL_PAGES}` |

Recommended: `"Page {AUTO_PAGE} of {TOTAL_PAGES}"`.

Tests must **not** assert literal page numbers. Instead:
```r
stopifnot(grepl("\\chpgn",  rtf_txt, fixed = TRUE))  # {AUTO_PAGE}
stopifnot(grepl(" of 2",    rtf_txt, fixed = TRUE))  # {TOTAL_PAGES}
```

---

## Running tests

```powershell
# R — from repo root
cd c:\Yrepo\rtfreporter
Rscript tests/test_rtfreport.R

# Python — from python/ subdirectory
cd c:\Yrepo\rtfreporter\python
python -m pytest tests/
```

All tests in `tests/test_rtfreport.R` must pass before any PR or release.

---

## Vignette rendering (pre-built HTML)

Vignettes must be **pre-rendered to HTML** before release so that users on
CRAN/GitHub can read them without re-running the code.

**When to render:**  Run this whenever `vignettes/rtfreporter-quickstart.Rmd`
changes, and always before tagging a release.

```powershell
# from repo root
cd c:\Yrepo\rtfreporter
Rscript -e "rmarkdown::render('vignettes/rtfreporter-quickstart.Rmd', output_dir = 'inst/doc')"
```

The generated `inst/doc/rtfreporter-quickstart.html` (and `.R` sidecar) must be
committed alongside the `.Rmd` source.

**Checklist before release:**
1. Update `vignettes/rtfreporter-quickstart.Rmd` if API changed.
2. Run the render command above and confirm no errors.
3. `git add inst/doc/` and commit together with other release changes.
4. Bump version in `DESCRIPTION`, commit, tag, push.
