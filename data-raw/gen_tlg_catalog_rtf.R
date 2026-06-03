# =============================================================================
# data-raw/gen_tlg_catalog_rtf.R
#
# Regenerate the example RTF files used in
# vignettes/articles/tlg-catalog.Rmd to a KNOWN folder, so you can open them
# in Word / LibreOffice and take screenshots for the article.
#
# The table objects are the pharmaverse example objects (demographic + adverse
# events), built verbatim; rtfreporter only adds the RTF-rendering step.
#
# Run from the repo root (with the dev package installed):
#     Rscript data-raw/gen_tlg_catalog_rtf.R
#
# Output: ./output/tlg/*.rtf  (the output/ directory is git-ignored).
# =============================================================================

library(rtfreporter)
library(tern)
library(rtables)
library(gtsummary)
library(tfrmt)
library(cards)
library(forcats)
library(dplyr)

out_dir <- file.path("output", "tlg")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

adsl <- pharmaverseadam::adsl
adae <- pharmaverseadam::adae

make_header <- function(table_no, title2) {
  rtf_header(rows = list(
    c(l = "Hoge Co. Limited",   r = "CONFIDENTIAL"),
    c(l = "Protocol: RTF-101",  r = "Page {AUTO_PAGE} of {AUTO_TOTAL_PAGES}"),
    c(c = paste0("Table ", table_no, "  ", title2))
  ))
}
make_footer <- function(built_with) {
  rtf_footer(c(l = paste0(
    "Table object built with ", built_with,
    " (pharmaverse example); rendered to RTF by rtfreporter.")))
}
demog_title <- list(c("Demographic and Baseline Characteristics",
                      "Safety Analysis Set"))
ae_title <- list(c("Adverse Events by System Organ Class and Preferred Term",
                   "Safety Analysis Set"))

.write <- function(doc, file, npages = NULL) {
  path <- file.path(out_dir, file)
  generate_rtfreport(doc, path, overwrite = TRUE)
  message("wrote ", path, if (!is.null(npages)) paste0(" (", npages, " pages)"))
  path
}

# ---- 1a. Demographics (tern + rtables) -------------------------------------
adsl2 <- adsl |> df_explicit_na()
vars <- c("AGE", "AGEGR1", "SEX", "RACE")
var_labels <- c("Age (yr)", "Age group", "Sex", "Race")
dm_tern <- build_table(
  basic_table(show_colcounts = TRUE) |>
    split_cols_by(var = "ACTARM") |>
    add_overall_col("All Patients") |>
    analyze_vars(vars = vars, var_labels = var_labels),
  adsl2)
out_dm_tern <- .write(
  rtf_document() |>
    rtf_section(page = 1, secinfo = list(
      header = make_header("14.1.1a", "Demographics (tern)"),
      footer = make_footer("tern + rtables"))) |>
    rtf_tables(as_rtftables(dm_tern, blank_rows = "between_groups"),
               titles = demog_title),
  "tlg-demog-tern.rtf")

# ---- 1b. Demographics (gtsummary + cards) ----------------------------------
theme_gtsummary_compact()
ard <- ard_stack(adsl,
  ard_continuous(variables = AGE),
  ard_categorical(variables = c(AGEGR1, SEX, RACE)),
  .by = ACTARM, .attributes = TRUE)
dm_gts <- tbl_ard_summary(cards = ard, by = ACTARM,
  include = c(AGE, AGEGR1, SEX, RACE), type = AGE ~ "continuous2",
  statistic = AGE ~ c("{N}", "{mean} ({sd})",
                      "{median} ({p25}, {p75})", "{min}, {max}")) |>
  bold_labels() |>
  modify_header(all_stat_cols() ~ "**{level}**  \nN = {n}") |>
  modify_footnote(everything() ~ NA)
out_dm_gts <- .write(
  rtf_document() |>
    rtf_section(page = 1, secinfo = list(
      header = make_header("14.1.1b", "Demographics (gtsummary)"),
      footer = make_footer("gtsummary + cards"))) |>
    rtf_tables(as_rtftables(dm_gts, blank_rows = "between_groups"),
               titles = demog_title),
  "tlg-demog-gtsummary.rtf")

# ---- 1c. Demographics (tfrmt + cards) --------------------------------------
ard <- ard_stack(adsl,
  ard_continuous(variables = AGE,
    statistic = ~ continuous_summary_fns(c("N", "mean", "sd", "min", "max"))),
  ard_categorical(variables = c(AGEGR1, SEX, RACE)),
  .by = ACTARM, .overall = TRUE, .total_n = TRUE)
ard_tbl <- ard |>
  shuffle_card(fill_overall = "Total") |>
  prep_big_n(vars = "ACTARM") |>
  prep_combine_vars(vars = c("AGE", "AGEGR1", "SEX", "RACE")) |>
  prep_label() |>
  group_by(ACTARM, stat_variable) |>
  mutate(across(c(variable_level, label), ~ ifelse(stat_name == "N", "n", .x))) |>
  ungroup() |> unique() |>
  mutate(ord1 = fct_inorder(stat_variable) |> fct_relevel("SEX", after = 0) |> as.numeric(),
         ord2 = ifelse(label == "n", 1, 2)) |>
  mutate(stat_variable = case_when(
    stat_variable == "AGE"    ~ "Age (YEARS) at First Dose",
    stat_variable == "AGEGR1" ~ "Age Group (YEARS) at First Dose",
    stat_variable == "SEX"    ~ "Sex",
    stat_variable == "RACE"   ~ "High Level Race", .default = stat_variable)) |>
  select(ACTARM, stat_variable, label, stat_name, stat, ord1, ord2) |> unique()
dm_tfrmt <- tfrmt(group = stat_variable, label = label, param = stat_name,
  value = stat, column = ACTARM, sorting_cols = c(ord1, ord2),
  body_plan = body_plan(
    frmt_structure(".default", ".default", frmt("xxx")),
    frmt_structure(".default", ".default",
      frmt_combine("{n} ({p}%)", n = frmt("xxx"),
                   p = frmt("xx", transform = ~ . * 100)))),
  big_n = big_n_structure(param_val = "bigN", n_frmt = frmt(" (N=xx)")),
  col_plan = col_plan(-starts_with("ord")),
  col_style_plan = col_style_plan(col_style_structure(
    col = c("Placebo", "Xanomeline High Dose", "Xanomeline Low Dose", "Total"),
    align = "left")),
  row_grp_plan = row_grp_plan(row_grp_structure(
    ".default", element_block(post_space = " ")))) |>
  print_to_gt(ard_tbl)
.write(
  rtf_document() |>
    rtf_section(page = 1, secinfo = list(
      header = make_header("14.1.1c", "Demographics (tfrmt)"),
      footer = make_footer("tfrmt + cards"))) |>
    rtf_tables(as_rtftables(dm_tfrmt, blank_rows = "between_groups"),
               titles = demog_title),
  "tlg-demog-tfrmt.rtf")

# ---- AE data prep ----------------------------------------------------------
adsl_ae <- adsl |> df_explicit_na()
adae_ae <- adae |> df_explicit_na() |>
  var_relabel(AEBODSYS = "MedDRA System Organ Class",
              AEDECOD  = "MedDRA Preferred Term") |>
  filter(SAFFL == "Y")

# ---- 2a. Adverse events (tern + rtables, paginated) ------------------------
split_fun <- drop_split_levels
ae_tern <- build_table(
  basic_table(show_colcounts = TRUE) |>
    split_cols_by(var = "ACTARM") |>
    add_overall_col(label = "All Patients") |>
    analyze_num_patients(vars = "USUBJID", .stats = c("unique", "nonunique"),
      .labels = c(
        unique    = "Total number of patients with at least one adverse event",
        nonunique = "Overall total number of events")) |>
    split_rows_by("AEBODSYS", child_labels = "visible", nested = FALSE,
                  split_fun = split_fun, label_pos = "topleft",
                  split_label = obj_label(adae_ae$AEBODSYS)) |>
    summarize_num_patients(var = "USUBJID", .stats = c("unique", "nonunique"),
      .labels = c(
        unique    = "Total number of patients with at least one adverse event",
        nonunique = "Total number of events")) |>
    count_occurrences(vars = "AEDECOD", .indent_mods = -1L) |>
    append_varlabels(adae_ae, "AEDECOD", indent = 1L),
  df = adae_ae, alt_counts_df = adsl_ae)
ae_tern_pages <- as_rtftables(ae_tern, split = "group_safe", max_rows = 30,
                              blank_rows = "between_groups", align_count_pct = TRUE)
out_ae_tern <- .write(
  rtf_document() |>
    rtf_section(page = 1, secinfo = list(
      header = make_header("14.3.1a", "Adverse Events (tern)"),
      footer = make_footer("tern + rtables"))) |>
    rtf_tables(ae_tern_pages, titles = rep(ae_title, length(ae_tern_pages))),
  "tlg-ae-tern.rtf", length(ae_tern_pages))

# ---- 2b. Adverse events (cards + tfrmt, paginated) -------------------------
ae_ard <- ard_stack_hierarchical(
  data = adae_ae, by = ACTARM, variables = c(AEBODSYS, AEDECOD),
  statistic = ~ c("n", "p"), denominator = adsl_ae, id = USUBJID,
  over_variables = TRUE, overall = TRUE)
ae_tot <- ard_stack_hierarchical(
  data = mutate(adae_ae, ACTARM = "All Patients"), by = ACTARM,
  variables = c(AEBODSYS, AEDECOD),
  denominator = mutate(adsl_ae, ACTARM = "All Patients"),
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
ae_tfrmt <- tfrmt_n_pct(n = "n", pct = "p",
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
.write(
  rtf_document() |>
    rtf_section(page = 1, secinfo = list(
      header = make_header("14.3.1b", "Adverse Events (tfrmt)"),
      footer = make_footer("tfrmt + cards"))) |>
    rtf_tables(ae_tfrmt_pages, titles = rep(ae_title, length(ae_tfrmt_pages))),
  "tlg-ae-tfrmt.rtf", length(ae_tfrmt_pages))

# ---- 3. Assembled deliverable ----------------------------------------------
assemble_rtf(c(out_dm_gts, out_ae_tern), file.path(out_dir, "tlg-assembled.rtf"),
             overwrite = TRUE)
message("wrote ", file.path(out_dir, "tlg-assembled.rtf"))

message("\nDone. Open the .rtf files in ", normalizePath(out_dir),
        "\nScreenshots (PNG) go to man/figures/ as:",
        "\n  tlg-demog-tern.png  tlg-demog-gtsummary.png  tlg-demog-tfrmt.png",
        "\n  tlg-ae-tern.png  tlg-ae-tfrmt.png  tlg-assembled.png")
