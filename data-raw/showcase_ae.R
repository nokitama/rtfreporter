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
  c(c = "Treatment-Emergent Adverse Events Occurring in >= 3% of Subjects in Any Treatment Group"),
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
  list(list(col = 1L, align = "left",   header_align = "left")),
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

# -- Canonical orderings, shared by every framework so the tables match --------
# Preferred Terms ordered by total distinct subjects (all arms) descending, ties
# A -> Z.  Because a PT belongs to a single SOC, this also orders the PTs within
# each SOC.  SOCs themselves are always alphabetical.
.pt_tot   <- adae |> distinct(USUBJID, AEDECOD) |>
  dplyr::count(AEDECOD, name = "tot")
.pt_order <- .pt_tot |> dplyr::arrange(dplyr::desc(tot), AEDECOD) |>
  dplyr::pull(AEDECOD) |> as.character()

# Cell format shared by the read-meta frameworks: collapse a zero cell
# "0 (0.0%)" to a bare "0" (so SOC and PT zeros match), then align the column.
fmt_ae_cell <- function(x, nbsp = " ") {
  z <- grepl("^[[:space:]]*0[[:space:]]*\\([[:space:]]*0(\\.0)?%?[[:space:]]*\\)[[:space:]]*$", x)
  x[z] <- "0"
  fmt_count_paren_bare(x, nbsp = nbsp)
}

# Reorder a gtsummary hierarchical table_body to the canonical order: SOC blocks
# alphabetical, PTs within each block by `.pt_order`, the overall row kept on top
# (and relabelled to match tern).  gtsummary always lists PTs alphabetically and
# sort_hierarchical() would also reorder the SOCs, so we reorder the body once.
reorder_ae <- function(tbl, pt_order = .pt_order,
                       overall_label = ANY_AE) {
  tb <- tbl$table_body
  tb$label[tb$variable == "..ard_hierarchical_overall.."] <- overall_label
  is_soc <- tb$variable == "AESOC"
  blk     <- cumsum(is_soc)
  block_ids <- sort(unique(blk[blk > 0]))
  soc_lab   <- vapply(block_ids, function(b) tb$label[blk == b & is_soc][1], character(1))
  new <- which(blk == 0)
  for (b in block_ids[order(soc_lab)]) {
    rows    <- which(blk == b)
    soc_row <- rows[tb$variable[rows] == "AESOC"]
    pt_rows <- rows[tb$variable[rows] == "AEDECOD"]
    pt_rows <- pt_rows[order(match(tb$label[pt_rows], pt_order))]
    new <- c(new, soc_row, pt_rows)
  }
  tbl$table_body <- tb[new, ]
  tbl
}

# Prepend an "any adverse event" overall row to a gtsummary hierarchical
# table_body.  tbl_ard_hierarchical() has no overall_row argument, so we add the
# row ourselves with the distinct-subject any-AE count per arm.
add_any_ae_row <- function(tbl, label = ANY_AE) {
  N     <- as.integer(arm_n[arm_levels])
  anyae <- adae |> dplyr::distinct(TRT01A, USUBJID) |> dplyr::count(TRT01A)
  vals  <- vapply(seq_along(arm_levels), function(i) {
    n <- anyae$n[match(arm_levels[i], as.character(anyae$TRT01A))]
    if (is.na(n)) n <- 0L
    sprintf("%d (%.1f%%)", n, 100 * n / N[i])
  }, character(1))
  tb  <- tbl$table_body
  row <- tb[1, ]; row[seq_len(ncol(row))] <- NA
  row$variable <- "..ard_hierarchical_overall.."
  row$row_type <- "level"
  row$label    <- label
  row$stat_1   <- vals[1]; row$stat_2 <- vals[2]; row$stat_3 <- vals[3]
  tbl$table_body <- dplyr::bind_rows(row, tb)
  # The injected row inherits the default level indent; un-indent it via the
  # public API so it lines up with the SOC rows.
  gtsummary::modify_indent(tbl, columns = "label",
                           rows = variable == "..ard_hierarchical_overall..",
                           indent = 0L)
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
  # A zero count prints as a bare "0" (no parentheses), matching how
  # count_occurrences() renders the PT rows -- so both levels format 0 the same.
  soc_count <- function(df, labelstr, .N_col, ...) {
    n <- length(unique(df$USUBJID))
    cell <- if (n == 0L) rcell(0L, format = "xx")
            else         rcell(c(n, n / .N_col), format = "xx (xx.x%)")
    in_rows(cell, .labels = labelstr)
  }
  lyt <- basic_table(show_colcounts = TRUE) |>
    split_cols_by("TRT01A") |>
    analyze_num_patients(vars = "USUBJID", .stats = "unique",
                         .labels = c(unique = ANY_AE)) |>
    split_rows_by("AESOC", child_labels = "hidden", nested = FALSE,
                  split_fun = drop_split_levels) |>
    summarize_row_groups(cfun = soc_count) |>
    count_occurrences(vars = "AEDECOD", .indent_mods = 1L)
  # SOC (level 1) stays in alphabetical order (the factor levels above); only the
  # PTs within each SOC are ordered by subject count (all arms), ties A -> Z.
  tbl <- build_table(lyt, df = adae_f, alt_counts_df = adsl) |>
    prune_table(keep_rows(has_fraction_in_any_col(atleast = 0.03))) |>
    sort_at_path(path = c("AESOC", "*", "AEDECOD"), scorefun = score_occurrences)
  pages <- as_rtftables(tbl, split = "group_force", max_rows = AE_MAX_ROWS,
                        blank_rows = "between_groups",
                        cell_format = fmt_count_paren_bare,
                        col_header = ae_col_header, col_spec = ae_col_spec,
                        col_rel_width = ae_widths, row_height_twips = 200)
  render_ae(pages, "ae_tern")
}))

# ===========================================================================
# B. gtsummary (standalone)  -- build-and-read (read_meta)
# ===========================================================================
# tbl_hierarchical() builds the whole thing: overall_row = the any-AE row, each
# SOC row carries its own subject count, PTs are indented beneath.  We keep only
# PTs >= 3% in any arm (filter_hierarchical) and reorder to the canonical order.
try_block("gtsummary", local({
  library(gtsummary)
  tbl <- tbl_hierarchical(
      data = adae, variables = c(AESOC, AEDECOD), by = TRT01A,
      denominator = adsl, id = USUBJID, overall_row = TRUE,
      statistic = ~ "{n} ({p}%)", digits = everything() ~ list(p = 1)) |>
    filter_hierarchical(p >= 0.03) |>
    reorder_ae()
  pages <- as_rtftables(tbl, read_meta = TRUE, split = "group_force",
                        max_rows = AE_MAX_ROWS, blank_rows = "between_groups",
                        cell_format = fmt_ae_cell,
                        col_header = ae_col_header, col_spec = ae_col_spec,
                        col_rel_width = ae_widths, row_height_twips = 200)
  render_ae(pages, "ae_gtsummary")
}))

# ===========================================================================
# C. cards / cardx + gtsummary (ARD workflow)  -- build-and-read
# ===========================================================================
# Compute the hierarchical Analysis Results Dataset with cards, then summarise it
# with gtsummary::tbl_ard_hierarchical() -- the same table, ARD-first.
try_block("gtsummary-ARD", local({
  library(cards); library(gtsummary)
  ard <- ard_stack_hierarchical(
    data = adae, variables = c(AESOC, AEDECOD), by = TRT01A,
    denominator = adsl, id = USUBJID)
  tbl <- tbl_ard_hierarchical(
      cards = ard, variables = c(AESOC, AEDECOD), by = TRT01A,
      statistic = ~ "{n} ({p}%)") |>
    filter_hierarchical(p >= 0.03) |>
    add_any_ae_row() |>
    reorder_ae()
  pages <- as_rtftables(tbl, read_meta = TRUE, split = "group_force",
                        max_rows = AE_MAX_ROWS, blank_rows = "between_groups",
                        cell_format = fmt_ae_cell,
                        col_header = ae_col_header, col_spec = ae_col_spec,
                        col_rel_width = ae_widths, row_height_twips = 200)
  render_ae(pages, "ae_gtsummary_ard")
}))

cat("Done.  Capture PNGs into", rtf_dir, "to replace the article placeholders.\n")
