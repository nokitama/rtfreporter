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
# them as ae_<framework>.png (same basename); see showcase-ae.Rmd / the
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
# PTs kept in the table: >= 3% of subjects in any treatment group.
.keep_pt <- adae |> dplyr::distinct(USUBJID, TRT01A, AEDECOD) |>
  dplyr::count(TRT01A, AEDECOD, name = "n") |>
  dplyr::mutate(p = 100 * n / as.integer(arm_n[as.character(TRT01A)])) |>
  dplyr::group_by(AEDECOD) |> dplyr::summarise(mx = max(p), .groups = "drop") |>
  dplyr::filter(mx >= 3) |> dplyr::pull(AEDECOD) |> as.character()
# Real SOC / PT pairs (a PT belongs to exactly one SOC).
.soc_pt <- adae |> dplyr::distinct(AESOC, AEDECOD) |>
  dplyr::mutate(dplyr::across(dplyr::everything(), as.character))

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

# Build the standalone-gtsummary AE table (used directly, and as the source for
# the flextable / huxtable conversions below).
ae_gtsummary_tbl <- function() {
  gtsummary::tbl_hierarchical(
      data = adae, variables = c(AESOC, AEDECOD), by = TRT01A,
      denominator = adsl, id = USUBJID, overall_row = TRUE,
      statistic = ~ "{n} ({p}%)",
      digits = gtsummary::everything() ~ list(p = 1)) |>
    gtsummary::filter_hierarchical(p >= 0.03) |>
    reorder_ae()
}

# gtsummary indents PTs via a styling rule that as_flex_table() / as_hux_table()
# turn into cell padding -- which rtfreporter's flextable / huxtable adapters do
# not read as a row label indent.  Bake the indent into the label TEXT (NBSP, so
# it survives), and drop the styling rule so it is not applied twice.
bake_indent <- function(tbl, n = 4L) {
  tb <- tbl$table_body
  pt <- tb$variable == "AEDECOD"
  tb$label[pt] <- paste0(strrep(" ", n), tb$label[pt])
  tbl$table_body <- tb
  tbl$table_styling$indent <- tbl$table_styling$indent[0, ]
  tbl
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
  tbl <- ae_gtsummary_tbl()
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

# ===========================================================================
# D. Tplyr  -- transpose-and-set (body from Tplyr; metadata set in rtfreporter)
# ===========================================================================
# Tplyr counts the distinct subjects; we assemble the layout ourselves (the
# transpose-and-set philosophy): an overall any-AE row, then per SOC the SOC
# count on the SOC row, then the indented PT rows.  The column header, widths
# and alignment are supplied to rtfreporter, not read from the framework.
try_block("Tplyr", local({
  library(Tplyr)
  varcols <- paste0("var1_", arm_levels)
  rn <- function(df) df |>
    dplyr::rename_with(~ arm_levels, dplyr::all_of(varcols))

  soc <- tplyr_table(adae, TRT01A) |>
    set_pop_data(adsl) |> set_pop_treat_var(TRT01A) |>
    add_layer(group_count(AESOC) |> set_distinct_by(USUBJID) |>
                set_format_strings(f_str("xx (xx.x%)", distinct_n, distinct_pct))) |>
    build() |> dplyr::transmute(AESOC = as.character(row_label1),
                                dplyr::across(dplyr::all_of(varcols))) |> rn()
  pt <- tplyr_table(adae, TRT01A) |>
    set_pop_data(adsl) |> set_pop_treat_var(TRT01A) |>
    add_layer(group_count(AEDECOD, by = vars(AESOC)) |> set_distinct_by(USUBJID) |>
                set_format_strings(f_str("xx (xx.x%)", distinct_n, distinct_pct))) |>
    build() |> dplyr::transmute(AESOC = as.character(row_label1),
                                AEDECOD = as.character(row_label2),
                                dplyr::across(dplyr::all_of(varcols))) |>
    dplyr::semi_join(.soc_pt, by = c("AESOC", "AEDECOD")) |>
    dplyr::filter(AEDECOD %in% .keep_pt) |> rn()

  any_n <- adae |> dplyr::distinct(TRT01A, USUBJID) |> dplyr::count(TRT01A)
  ov <- vapply(arm_levels, function(a) {
    n <- any_n$n[match(a, as.character(any_n$TRT01A))]
    sprintf("%d (%.1f%%)", n, 100 * n / as.integer(arm_n[a]))
  }, character(1))

  rows <- list(setNames(data.frame(ANY_AE, t(ov), check.names = FALSE,
                                   stringsAsFactors = FALSE),
                        c("Characteristic", arm_levels)))
  for (s in sort(unique(pt$AESOC))) {
    sc <- soc |> dplyr::filter(AESOC == s)
    rows[[length(rows) + 1]] <- setNames(
      data.frame(s, sc[, arm_levels], check.names = FALSE, stringsAsFactors = FALSE),
      c("Characteristic", arm_levels))
    pts <- pt |> dplyr::filter(AESOC == s) |>
      dplyr::arrange(match(AEDECOD, .pt_order))
    if (nrow(pts))
      rows[[length(rows) + 1]] <- setNames(
        data.frame(paste0("    ", pts$AEDECOD), pts[, arm_levels],
                   check.names = FALSE, stringsAsFactors = FALSE),
        c("Characteristic", arm_levels))
  }
  disp <- dplyr::bind_rows(rows)

  pages <- as_rtftables(disp, col_header = ae_col_header, split = "group_force",
                        max_rows = AE_MAX_ROWS, blank_rows = "between_groups",
                        cell_format = fmt_ae_cell, col_spec = ae_col_spec,
                        col_rel_width = ae_widths, row_height_twips = 200)
  render_ae(pages, "ae_tplyr")
}))

# ===========================================================================
# E. cards + tfrmt  -- build-and-read (formatted by a tfrmt spec)
# ===========================================================================
# tfrmt renders a row with the SAME `group` and `label` value as a single line
# that ALSO carries its statistic -- so giving each SOC a row with
# group = label = <SOC> puts the SOC count ON the SOC row, exactly like the
# others; the PT rows (group = SOC, label = PT) are the indented children, and
# the overall row is its own one-row group.  We complete the arm x row grid so a
# zero cell is a real 0 (printed bare), and sort SOCs alphabetically / PTs by
# subject count.
try_block("cards-tfrmt", local({
  library(tidyr); library(tfrmt)
  N         <- as.integer(arm_n[arm_levels]); names(N) <- arm_levels
  real_pairs <- .soc_pt |> dplyr::filter(AEDECOD %in% .keep_pt)
  kept_socs  <- sort(unique(real_pairs$AESOC))

  pt_c <- adae |> dplyr::distinct(TRT01A, USUBJID, AESOC, AEDECOD) |>
    dplyr::count(TRT01A, AESOC, AEDECOD, name = "n") |>
    dplyr::mutate(AESOC = as.character(AESOC), AEDECOD = as.character(AEDECOD)) |>
    dplyr::semi_join(real_pairs, by = c("AESOC", "AEDECOD")) |>
    tidyr::complete(TRT01A, tidyr::nesting(AESOC, AEDECOD), fill = list(n = 0)) |>
    dplyr::mutate(p = n / N[as.character(TRT01A)])
  soc_c <- adae |> dplyr::distinct(TRT01A, USUBJID, AESOC) |>
    dplyr::count(TRT01A, AESOC, name = "n") |>
    dplyr::mutate(AESOC = as.character(AESOC)) |>
    dplyr::filter(AESOC %in% kept_socs) |>
    tidyr::complete(TRT01A, AESOC = kept_socs, fill = list(n = 0)) |>
    dplyr::mutate(p = n / N[as.character(TRT01A)])
  ov_c <- adae |> dplyr::distinct(TRT01A, USUBJID) |> dplyr::count(TRT01A, name = "n") |>
    dplyr::mutate(p = n / N[as.character(TRT01A)])

  long <- dplyr::bind_rows(
      ov_c  |> dplyr::transmute(group = ANY_AE, label = ANY_AE,
                                column = as.character(TRT01A), n, p),
      soc_c |> dplyr::transmute(group = AESOC,  label = AESOC,
                                column = as.character(TRT01A), n, p),
      pt_c  |> dplyr::transmute(group = AESOC,  label = AEDECOD,
                                column = as.character(TRT01A), n, p)) |>
    tidyr::pivot_longer(c(n, p), names_to = "param", values_to = "value") |>
    dplyr::mutate(
      ord1   = ifelse(group == ANY_AE, 0L, match(group, kept_socs)),
      ord2   = ifelse(label == group, 0L, match(label, .pt_order)),
      column = factor(column, levels = arm_levels),
      group  = factor(group, levels = c(ANY_AE, kept_socs)))

  spec <- tfrmt(
    group = group, label = label, column = column, param = param, value = value,
    sorting_cols = c(ord1, ord2),
    body_plan = body_plan(frmt_structure(".default", ".default",
      frmt_combine("{n} ({p}%)", n = frmt("x"),
                   p = frmt("x.x", transform = ~ . * 100)))),
    col_plan = col_plan(group, label, Placebo, `Xanomeline Low Dose`,
                        `Xanomeline High Dose`, -ord1, -ord2))
  g <- print_to_gt(spec, long)

  pages <- as_rtftables(g, read_meta = TRUE, split = "group_force",
                        max_rows = AE_MAX_ROWS, blank_rows = "between_groups",
                        cell_format = fmt_ae_cell,
                        col_header = ae_col_header, col_spec = ae_col_spec,
                        col_rel_width = ae_widths, row_height_twips = 200)
  render_ae(pages, "ae_tfrmt")
}))

# ===========================================================================
# F. gtsummary -> flextable  -- convert, then read the flextable
# ===========================================================================
# No need to rebuild: gtsummary::as_flex_table() converts the AE table to a
# flextable, which rtfreporter reads via its flextable adapter.  We bake the PT
# indent into the label text first (see bake_indent()).
try_block("flextable", local({
  library(gtsummary); library(flextable)
  ft <- gtsummary::as_flex_table(bake_indent(ae_gtsummary_tbl()))
  pages <- as_rtftables(ft, split = "group_force", max_rows = AE_MAX_ROWS,
                        blank_rows = "between_groups", cell_format = fmt_ae_cell,
                        col_header = ae_col_header, col_spec = ae_col_spec,
                        col_rel_width = ae_widths, row_height_twips = 200)
  render_ae(pages, "ae_flextable")
}))

# ===========================================================================
# G. gtsummary -> huxtable  -- convert, then read the huxtable
# ===========================================================================
try_block("huxtable", local({
  library(gtsummary); library(huxtable)
  hx <- gtsummary::as_hux_table(bake_indent(ae_gtsummary_tbl()))
  pages <- as_rtftables(hx, split = "group_force", max_rows = AE_MAX_ROWS,
                        blank_rows = "between_groups", cell_format = fmt_ae_cell,
                        col_header = ae_col_header, col_spec = ae_col_spec,
                        col_rel_width = ae_widths, row_height_twips = 200)
  render_ae(pages, "ae_huxtable")
}))

cat("Done.  Capture PNGs into", rtf_dir, "to replace the article placeholders.\n")
