# Example RTF output

These `.rtf` files are the rendered output of the article
[*From pharmaverse tables to RTF reports*](https://ichirio.github.io/rtfreporter/articles/tlg-catalog.html).

Each file is produced by taking a table object built **verbatim** by the
official [pharmaverse examples](https://pharmaverse.github.io/examples/) and
running it through rtfreporter -- the statistics and formatting are the
pharmaverse example's; rtfreporter only adds the final RTF rendering step.

| File | Source table object | pharmaverse example |
|------|--------------------|---------------------|
| `pharmaverse-demographic-tern.rtf` | tern + rtables `TableTree` | [demographic](https://pharmaverse.github.io/examples/tlg/demographic.html) |
| `pharmaverse-demographic-gtsummary.rtf` | gtsummary + cards `gt_tbl` | demographic |
| `pharmaverse-demographic-tfrmt.rtf` | tfrmt + cards `gt_tbl` | demographic |
| `pharmaverse-adverse-events-tern.rtf` | tern + rtables `TableTree` (paginated) | [adverse events](https://pharmaverse.github.io/examples/tlg/adverse_events.html) |
| `pharmaverse-adverse-events-tfrmt.rtf` | tfrmt + cards `gt_tbl` (paginated) | adverse events |
| `pharmaverse-assembled.rtf` | the gtsummary demographics + multi-page tern adverse-events table, joined with `assemble_rtf()` (with a Table of Contents) | both |

Open them in Word / LibreOffice (or batch-convert to PDF).  To regenerate,
run `Rscript data-raw/gen_tlg_catalog_rtf.R` from the repository root.

## Screenshots

Screenshots of the first page of each `.rtf` are kept here next to the file,
with the same base name and a `.png` extension (e.g.
`pharmaverse-demographic-tern.png`).  The article copies the one it needs into
its own `figures/` folder at build time and displays it.  For the assembled
deliverable there are two: `pharmaverse-assembled-toc.png` (the Table of
Contents page) and `pharmaverse-assembled.png` (a body page).
