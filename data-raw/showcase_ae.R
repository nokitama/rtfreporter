# data-raw/showcase_ae.R
# ---------------------------------------------------------------------------
# Generate the Adverse Events (AE) showcase RTFs: an AE summary rendered to RTF
# by rtfreporter, in the same production-style layout as the demographics
# showcase (Letter landscape; sponsor / protocol / page number / title in the
# running header; analysis note / program path / run time in the footer).
#
# First cut: rtables / tern (the pharma-standard AE table builder).  Additional
# frameworks (cards + tfrmt, Tplyr, gtsummary tbl_hierarchical) are planned as a
# follow-up under the #146 tracker -- hierarchical AE tables differ enough per
# framework (overall / SOC-subtotal / PT structure, pruning, sorting) to warrant
# their own cut.
#
# The table:
#   * Number of SUBJECTS with at least one treatment-emergent AE (TEAE),
#     counted by treatment group, shown as n (xx.x%).
#   * "Subjects with any adverse event" overall on top, then by System Organ
#     Class (SOC) and, indented under each SOC, by Preferred Term (PT).
#   * Limited to AEs occurring in >= 5% of subjects in ANY treatment group, so
#     the table is a readable couple of pages (the overall / SOC subtotals are
#     still over ALL TEAEs).
#   * Rows ordered by subject count (descending); ties broken alphabetically.
#   * Forced to span >= 2 pages with group_force pagination, so a SOC that
#     straddles a page boundary repeats its label with " (Cont.)".
#
# Each framework writes inst/rtf-examples/showcase/ae_<framework>.rtf .  PNG
# snapshots are captured MANUALLY (open the .rtf in Word) and saved next to
# them as ae_<framework>.png (same basename); see showcase.Rmd / the
# data-raw/showcase_placeholders.R note.
#
# Run with:  Rscript data-raw/showcase_ae.R
# ---------------------------------------------------------------------------

suppressMessages({
  library(dplyr)
  devtools::load_all(".", quiet = TRUE)   # rtfreporter (dev)
})

rtf_dir <- "inst/rtf-examples/showcase"
dir.create(rtf_dir, showWarnings = FALSE, recursive = TRUE)

# -- Common analysis data ---------------------------------------------------
arm_levels <- c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose")
adsl <- pharmaverseadam::adsl |>
  filter(TRT01A %in% arm_levels) |>
  mutate(TRT01A = factor(TRT01A, levels = arm_levels))
# Treatment-emergent AEs only, in the same three arms.
adae <- pharmaverseadam::adae |>
  filter(TRT01A %in% arm_levels, TRTEMFL == "Y") |>
  mutate(TRT01A = factor(TRT01A, levels = arm_levels))
arm_n  <- table(adsl$TRT01A)
ANY_AE <- "Subjects with any adverse event"

# -- Shared report furniture (identical to the DM showcase) -----------------
sponsor  <- "Acme Biopharma, Inc."
protocol <- "Protocol ABC-2026-001"
run_dt   <- "2026-06-17 09:14"

ae_header <- function() rtf_header(rows = list(
  c(l = sponsor,  r = "Page {AUTO_PAGE} of {AUTO_TOTAL_PAGES}"),
  c(l = protocol, r = "Status: Draft"),
  c(c = "Table 14.3.1"),
  c(c = "Treatment-Emergent Adverse Events Occurring in >= 2.5% of Subjects in Any Treatment Group"),
  c(c = "by System Organ Class and Preferred Term -- Safety Population"),
  c(c = "")
))
ae_footer <- function(program) rtf_footer(rows = list(
  c(l = "Note: A subject with multiple events within a category is counted once for that category. Percentages use the number of subjects in the safety population per group."),
  c(l = paste0("Program: ", program), r = paste0("Generated: ", run_dt)),
  c(l = "Source: ADSL, ADAE", r = "CONFIDENTIAL")
))

# Identical column header / widths / alignment for every framework.
ae_col_header <- c("System Organ Class /\nPreferred Term",
                   paste0(arm_levels, "\nN = ", as.integer(arm_n)))
ae_col_spec <- c(
  list(list(col = 1L, align = "left",   header_align = "center")),
  lapply(2:4, function(j) list(col = j, align = "center", header_align = "center")))
ae_widths   <- c(0.52, 0.16, 0.16, 0.16)
AE_MAX_ROWS <- 32L

# Wrap a paginated list of rtftable pages into the AE document and write it.
render_ae <- function(pages, name) {
  program <- paste0("/prod/abc/tfl/t_14_3_1_", name, ".R")
  doc <- rtf_document(page = list(paper_size = "letter", orientation = "landscape")) |>
    rtf_section(page = 1, secinfo = list(header = ae_header(), footer = ae_footer(program))) |>
    rtf_tables(pages)
  out <- file.path(rtf_dir, paste0(name, ".rtf"))
  generate_rtfreport(doc, out, overwrite = TRUE)
  cat(sprintf("  wrote %s (%d pages, %d bytes)\n", out, length(pages), file.size(out)))
}

try_block <- function(name, expr) {
  tryCatch(force(expr),
           error = function(e) cat(sprintf("  [SKIP] %s: %s\n", name, conditionMessage(e))))
}

cat("Generating AE showcase RTFs...\n")

# ===========================================================================
# A. rtables / tern  -- build-and-read (read_meta)
# ===========================================================================
# Three levels, each an INDEPENDENT distinct-subject count (so a level never
# equals the sum of the level below it -- a subject with two PTs in one SOC is
# counted once for the SOC):
#   * overall "any AE"      -- analyze_num_patients(), the top row.
#   * SOC (level 1)         -- the count sits ON the SOC name row, via a content
#                              summary (summarize_row_groups + child_labels
#                              "hidden") so there is no separate subtotal row.
#   * SOC / PT (level 2)    -- count_occurrences(), indented under the SOC.
# Build on the FULL TEAE data, then prune PT rows to >= 2.5% (overall / SOC
# counts stay over all TEAEs), and sort by subject count.  Alphabetical factor
# levels + a stable sort break ties A -> Z.
try_block("tern", local({
  library(rtables); library(tern)
  adae_f <- adae |>
    mutate(AESOC   = factor(AESOC,   levels = sort(unique(AESOC))),
           AEDECOD = factor(AEDECOD, levels = sort(unique(AEDECOD))))
  # Content function: distinct subjects with any AE in this SOC, per column.
  soc_count <- function(df, labelstr, .N_col, ...) {
    n <- length(unique(df$USUBJID))
    in_rows(rcell(c(n, n / .N_col), format = "xx (xx.x%)"), .labels = labelstr)
  }
  lyt <- basic_table(show_colcounts = TRUE) |>
    split_cols_by("TRT01A") |>
    analyze_num_patients(vars = "USUBJID", .stats = "unique",
                         .labels = c(unique = ANY_AE)) |>
    split_rows_by("AESOC", child_labels = "hidden", nested = FALSE,
                  split_fun = drop_split_levels) |>
    summarize_row_groups(cfun = soc_count) |>
    count_occurrences(vars = "AEDECOD", .indent_mods = 1L)
  tbl <- build_table(lyt, df = adae_f, alt_counts_df = adsl) |>
    prune_table(keep_rows(has_fraction_in_any_col(atleast = 0.025))) |>
    sort_at_path(path = c("AESOC"),               scorefun = cont_n_allcols) |>
    sort_at_path(path = c("AESOC", "*", "AEDECOD"), scorefun = score_occurrences)
  pages <- as_rtftables(tbl, split = "group_force", max_rows = AE_MAX_ROWS,
                        blank_rows = "between_groups",
                        cell_format = fmt_count_paren_bare,
                        col_header = ae_col_header, col_spec = ae_col_spec,
                        col_rel_width = ae_widths, row_height_twips = 200)
  render_ae(pages, "ae_tern")
}))

cat("Done.  Capture PNGs into", rtf_dir, "to replace the article placeholders.\n")
