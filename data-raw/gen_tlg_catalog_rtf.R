# =============================================================================
# data-raw/gen_tlg_catalog_rtf.R
#
# Regenerate the example RTF files used in
# vignettes/articles/tlg-catalog.Rmd to a KNOWN folder, so you can open them
# in Word / LibreOffice and take screenshots for the article.
#
# Run from the repo root (with the dev package installed):
#     Rscript data-raw/gen_tlg_catalog_rtf.R
#
# Output: ./output/tlg/*.rtf  (the output/ directory is git-ignored).
# =============================================================================

library(rtfreporter)
library(rtables)
library(tern)
library(gtsummary)
library(tfrmt)
library(cards)
library(pharmaverseadam)
library(dplyr)
library(tidyr)

out_dir <- file.path("output", "tlg")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

adsl <- random.cdisc.data::cadsl

ae_adsl <- pharmaverseadam::adsl |>
  df_explicit_na()
ae_adae <- pharmaverseadam::adae |>
  df_explicit_na() |>
  var_relabel(AEBODSYS = "MedDRA System Organ Class",
              AEDECOD  = "MedDRA Preferred Term") |>
  filter(SAFFL == "Y")

make_header <- function(table_no, title2) {
  rtf_header(rows = list(
    c(l = "Hoge Co. Limited",   r = "CONFIDENTIAL"),
    c(l = "Protocol: RTF-101",  r = "Page {AUTO_PAGE} of {AUTO_TOTAL_PAGES}"),
    c(c = paste0("Table ", table_no, "  ", title2))
  ))
}
make_footer <- function(source_object, built_with) {
  rtf_footer(c(l = paste0(
    "Source object: ", source_object, " (", built_with, "), ",
    "converted to RTF by rtfreporter.  ",
    "CDISC pilot data (random.cdisc.data); layout after the pharmaverse ",
    "TLG examples.")))
}
demog_title <- list(c("Demographic and Baseline Characteristics",
                      "Safety Analysis Set"))

.write <- function(doc, file) {
  path <- file.path(out_dir, file)
  generate_rtfreport(doc, path, overwrite = TRUE)
  message("wrote ", path)
}

# ---- 1a. Demographics (tern + rtables) -------------------------------------
dm_tern <- build_table(
  basic_table(show_colcounts = TRUE) |>
    split_cols_by("ARM") |>
    add_overall_col("All Patients") |>
    analyze_vars(vars = c("AGE", "SEX", "RACE"),
                 .stats = c("mean_sd", "median", "range", "count_fraction")) |>
    append_topleft("Characteristic"),
  adsl)
out_tern <- file.path(out_dir, "tlg-demog-tern.rtf")
generate_rtfreport(
  rtf_document() |>
    rtf_section(page = 1, secinfo = list(
      header = make_header("14.1.1a", "Demographics (tern)"),
      footer = make_footer("rtables TableTree", "tern + rtables"))) |>
    rtf_tables(as_rtftables(dm_tern, blank_rows = "between_groups"),
               titles = demog_title),
  out_tern, overwrite = TRUE)
message("wrote ", out_tern)

# ---- 1b. Demographics (gtsummary) ------------------------------------------
dm_gts <- adsl |>
  select(ARM, AGE, SEX, RACE) |>
  tbl_summary(by = ARM,
              label = list(AGE = "Age (years)", SEX = "Sex", RACE = "Race"),
              statistic = list(all_continuous() ~ "{mean} ({sd})")) |>
  modify_header(label = "Characteristic") |>
  add_overall()
out_gts <- file.path(out_dir, "tlg-demog-gtsummary.rtf")
generate_rtfreport(
  rtf_document() |>
    rtf_section(page = 1, secinfo = list(
      header = make_header("14.1.1b", "Demographics (gtsummary)"),
      footer = make_footer("gt_tbl", "gtsummary::tbl_summary()"))) |>
    rtf_tables(as_rtftables(dm_gts, align_count_pct = TRUE,
                            blank_rows = "between_groups"),
               titles = demog_title),
  out_gts, overwrite = TRUE)
message("wrote ", out_gts)

# ---- 1c. Demographics (tfrmt) ----------------------------------------------
age_long <- adsl |>
  group_by(ARM) |>
  summarise(Mean = mean(AGE), SD = sd(AGE), .groups = "drop") |>
  pivot_longer(c(Mean, SD), names_to = "label", values_to = "value") |>
  mutate(group = "Age (years)", param = tolower(label))
cat_long <- function(var, group_lbl) {
  adsl |>
    count(ARM, !!sym(var)) |>
    group_by(ARM) |>
    mutate(pct = n / sum(n) * 100) |>
    ungroup() |>
    pivot_longer(c(n, pct), names_to = "param", values_to = "value") |>
    mutate(group = group_lbl, label = as.character(.data[[var]])) |>
    select(ARM, group, label, param, value)
}
dm_long <- bind_rows(age_long |> select(ARM, group, label, param, value),
                     cat_long("SEX", "Sex"), cat_long("RACE", "Race"))
dm_tfrmt <- print_to_gt(tfrmt(
  group = group, label = label, column = ARM, param = param, value = value,
  body_plan = body_plan(
    frmt_structure("Age (years)", ".default", frmt("xx.x")),
    frmt_structure(".default", ".default",
                   frmt_combine("{n} ({pct}%)",
                                n = frmt("xx"), pct = frmt("xx.x"))))),
  dm_long)
.write(
  rtf_document() |>
    rtf_section(page = 1, secinfo = list(
      header = make_header("14.1.1c", "Demographics (tfrmt)"),
      footer = make_footer("gt_tbl", "tfrmt"))) |>
    rtf_tables(as_rtftables(dm_tfrmt, blank_rows = "between_groups"),
               titles = demog_title),
  "tlg-demog-tfrmt.rtf")

ae_title <- list(c("Adverse Events by System Organ Class and Preferred Term",
                   "Safety Analysis Set"))

# ---- 2a. Adverse events (tern + rtables, paginated) ------------------------
split_fun <- drop_split_levels
ae_tern <- build_table(
  basic_table(show_colcounts = TRUE) |>
    split_cols_by("ACTARM") |>
    add_overall_col(label = "All Patients") |>
    analyze_num_patients(vars = "USUBJID", .stats = c("unique", "nonunique"),
      .labels = c(
        unique    = "Total number of patients with at least one adverse event",
        nonunique = "Overall total number of events")) |>
    split_rows_by("AEBODSYS", child_labels = "visible", nested = FALSE,
                  split_fun = split_fun, label_pos = "topleft",
                  split_label = obj_label(ae_adae$AEBODSYS)) |>
    summarize_num_patients(var = "USUBJID", .stats = c("unique", "nonunique"),
      .labels = c(
        unique    = "Total number of patients with at least one adverse event",
        nonunique = "Total number of events")) |>
    count_occurrences(vars = "AEDECOD", .indent_mods = -1L) |>
    append_varlabels(ae_adae, "AEDECOD", indent = 1L),
  df = ae_adae, alt_counts_df = ae_adsl)
ae_tern_pages <- as_rtftables(ae_tern, split = "group_safe", max_rows = 30,
                              blank_rows = "between_groups", align_count_pct = TRUE)
out_ae_tern <- file.path(out_dir, "tlg-ae-tern.rtf")
generate_rtfreport(
  rtf_document() |>
    rtf_section(page = 1, secinfo = list(
      header = make_header("14.3.1a", "Adverse Events (tern)"),
      footer = make_footer("rtables TableTree", "tern + rtables"))) |>
    rtf_tables(ae_tern_pages, titles = rep(ae_title, length(ae_tern_pages))),
  out_ae_tern, overwrite = TRUE)
message("wrote ", out_ae_tern, " (", length(ae_tern_pages), " pages)")

# ---- 2b. Adverse events (cards + tfrmt, paginated) -------------------------
ae_ard <- ard_stack_hierarchical(
  data = ae_adae, by = ACTARM, variables = c(AEBODSYS, AEDECOD),
  statistic = ~ c("n", "p"), denominator = ae_adsl, id = USUBJID,
  over_variables = TRUE, overall = TRUE)
ae_tot <- ard_stack_hierarchical(
  data = mutate(ae_adae, ACTARM = "All Patients"), by = ACTARM,
  variables = c(AEBODSYS, AEDECOD),
  denominator = mutate(ae_adsl, ACTARM = "All Patients"),
  statistic = ~ c("n", "p"), id = USUBJID,
  over_variables = TRUE, overall = TRUE) |>
  filter(group2 == "ACTARM" | variable == "ACTARM")
ae_card <- bind_ard(ae_ard, ae_tot) |>
  shuffle_card(fill_hierarchical_overall = "ANY EVENT") |>
  prep_big_n(vars = "ACTARM") |>
  prep_hierarchical_fill(vars = c("AEBODSYS", "AEDECOD"), fill = "ANY EVENT") |>
  mutate(ACTARM = ifelse(ACTARM == "Overall ACTARM", "All Patients", ACTARM))
ord_soc <- ae_card |>
  filter(ACTARM == "All Patients", stat_name == "n", AEDECOD == "ANY EVENT") |>
  arrange(desc(stat)) |> mutate(ord1 = row_number()) |> select(AEBODSYS, ord1)
ord_pt <- ae_card |>
  filter(ACTARM == "All Patients", stat_name == "n") |>
  group_by(AEBODSYS) |> arrange(desc(stat)) |>
  mutate(ord2 = row_number()) |> select(AEBODSYS, AEDECOD, ord2)
ae_card <- ae_card |>
  full_join(ord_soc, by = "AEBODSYS") |>
  full_join(ord_pt, by = c("AEBODSYS", "AEDECOD")) |>
  select(AEBODSYS, AEDECOD, ord1, ord2, stat, stat_name, ACTARM)
ae_tfrmt <- tfrmt_n_pct(
  n = "n", pct = "p",
  pct_frmt_when = frmt_when(
    "==1" ~ frmt("(100%)"), ">=0.995" ~ frmt("(>99%)"), "==0" ~ frmt(""),
    "<=0.01" ~ frmt("(<1%)"), "TRUE" ~ frmt("(xx.x%)", transform = ~ . * 100))) |>
  tfrmt(group = AEBODSYS, label = AEDECOD, param = stat_name, value = stat,
    column = ACTARM, sorting_cols = c(ord1, ord2),
    col_plan = col_plan("System Organ Class / Preferred Term" = AEBODSYS,
      Placebo, `Xanomeline High Dose`, `Xanomeline Low Dose`, -ord1, -ord2),
    row_grp_plan = row_grp_plan(row_grp_structure(
      group_val = ".default", element_block(post_space = " "))),
    big_n = big_n_structure(param_val = "bigN", n_frmt = frmt(" (N=xx)"))) |>
  print_to_gt(ae_card)
ae_tfrmt_pages <- as_rtftables(ae_tfrmt, split = "group_force", max_rows = 30,
                               blank_rows = "between_groups")
out_ae_tfrmt <- file.path(out_dir, "tlg-ae-tfrmt.rtf")
generate_rtfreport(
  rtf_document() |>
    rtf_section(page = 1, secinfo = list(
      header = make_header("14.3.1b", "Adverse Events (tfrmt)"),
      footer = make_footer("gt_tbl", "cards + tfrmt"))) |>
    rtf_tables(ae_tfrmt_pages, titles = rep(ae_title, length(ae_tfrmt_pages))),
  out_ae_tfrmt, overwrite = TRUE)
message("wrote ", out_ae_tfrmt, " (", length(ae_tfrmt_pages), " pages)")

# ---- 3. Assembled deliverable ----------------------------------------------
assemble_rtf(c(out_gts, out_ae_tern), file.path(out_dir, "tlg-assembled.rtf"),
             overwrite = TRUE)
message("wrote ", file.path(out_dir, "tlg-assembled.rtf"))

message("\nDone. Open the .rtf files in ", normalizePath(out_dir),
        "\nScreenshots (PNG) go to man/figures/ as:",
        "\n  tlg-demog-tern.png  tlg-demog-gtsummary.png  tlg-demog-tfrmt.png",
        "\n  tlg-ae-tern.png  tlg-ae-tfrmt.png  tlg-assembled.png")
