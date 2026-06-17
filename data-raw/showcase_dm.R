# data-raw/showcase_dm.R
# ---------------------------------------------------------------------------
# Generate the Demographics (DM) showcase RTFs: the SAME demographics report
# built from several table frameworks, all rendered to RTF by rtfreporter.
#
# Each framework writes data-raw/showcase/rtf/dm_<framework>.rtf .  The PNG
# snapshots for the article are created MANUALLY from these RTFs (open in Word,
# export/screenshot) and saved to
#   vignettes/articles/figures/showcase/dm_<framework>.png
# (same basename as the RTF).
#
# Run with:  Rscript data-raw/showcase_dm.R
# ---------------------------------------------------------------------------

suppressMessages({
  library(dplyr)
  devtools::load_all(".", quiet = TRUE)   # rtfreporter (dev)
})

rtf_dir <- "data-raw/showcase/rtf"
dir.create(rtf_dir, showWarnings = FALSE, recursive = TRUE)

# -- Common analysis data ---------------------------------------------------
# Safety-style population: the three randomised arms (drop screen failures).
arm_levels <- c("Placebo", "Xanomeline Low Dose", "Xanomeline High Dose")
adsl <- pharmaverseadam::adsl |>
  filter(TRT01A %in% arm_levels) |>
  mutate(
    TRT01A = factor(TRT01A, levels = arm_levels),
    SEX    = factor(SEX, levels = c("F", "M"), labels = c("Female", "Male")),
    RACE   = factor(RACE, levels = c(
      "WHITE", "BLACK OR AFRICAN AMERICAN", "ASIAN",
      "AMERICAN INDIAN OR ALASKA NATIVE"),
      labels = c("White", "Black or African American", "Asian",
                 "American Indian or Alaska Native"))
  )

arm_n <- table(adsl$TRT01A)

# -- Shared report furniture (identical for every framework) ----------------
dm_titles <- list(c(
  "Table 14.1.1",
  "Summary of Demographic and Baseline Characteristics",
  "Safety Population"))
dm_footnotes <- list(c(
  "Percentages are based on the number of subjects in each treatment group.",
  "Source: ADSL"))

# Render an already-built page object (rtftable / framework table) to RTF.
render_show <- function(pages, name, ...) {
  if (!is.list(pages) || inherits(pages, "rtftable")) pages <- list(pages)
  doc <- rtf_document(page = list(paper_size = "letter", orientation = "portrait")) |>
    rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL)) |>
    rtf_tables(pages, titles = dm_titles, footnotes = dm_footnotes, ...)
  out <- file.path(rtf_dir, paste0(name, ".rtf"))
  generate_rtfreport(doc, out, overwrite = TRUE)
  cat(sprintf("  wrote %s (%d bytes)\n", out, file.size(out)))
}

cat("Generating DM showcase RTFs...\n")

# Run a framework block; report but do not abort on error.
try_block <- function(name, expr) {
  tryCatch(force(expr),
           error = function(e) cat(sprintf("  [SKIP] %s: %s\n", name, conditionMessage(e))))
}

# ===========================================================================
# A. gtsummary (standalone)  -- build-and-read (read_meta)
# ===========================================================================
local({
  library(gtsummary)
  tbl <- adsl |>
    select(TRT01A, AGE, SEX, RACE) |>
    tbl_summary(
      by = TRT01A,
      label = list(AGE = "Age (years)", SEX = "Sex", RACE = "Race"),
      statistic = list(
        all_continuous()  ~ "{mean} ({sd})",
        all_categorical() ~ "{n} ({p}%)"),
      digits = list(AGE ~ c(1, 2))
    ) |>
    modify_header(all_stat_cols() ~ "**{level}**  \nN = {n}")
  render_show(as_rtftables(tbl, read_meta = TRUE), "dm_gtsummary")
})

# ===========================================================================
# B. rtables / tern  -- build-and-read (read_meta)
# ===========================================================================
local({
  library(rtables); library(tern)
  vars <- c("AGE", "SEX", "RACE")
  var_labels <- c(AGE = "Age (years)", SEX = "Sex", RACE = "Race")
  lyt <- basic_table(show_colcounts = TRUE) |>
    split_cols_by("TRT01A") |>
    analyze_vars(
      vars = vars, var_labels = var_labels,
      .stats = c("mean_sd", "median", "range", "count_fraction"))
  tbl <- build_table(lyt, adsl)
  render_show(as_rtftables(tbl, read_meta = TRUE), "dm_rtables")
})

# ===========================================================================
# C. cards / cardx + gtsummary (ARD workflow)  -- build-and-read
# ===========================================================================
try_block("gtsummary-ARD", local({
  library(cards); library(gtsummary)
  ard <- ard_stack(
    data = adsl,
    .by = TRT01A,
    ard_continuous(variables = AGE, statistic = ~ list(mean = mean, sd = sd)),
    ard_categorical(variables = c(SEX, RACE)),
    .total_n = TRUE)
  tbl <- tbl_ard_summary(
    ard, by = TRT01A,
    label = list(AGE = "Age (years)", SEX = "Sex", RACE = "Race"),
    statistic = list(AGE = "{mean} ({sd})",
                     all_categorical() ~ "{n} ({p}%)"))
  render_show(as_rtftables(tbl, read_meta = TRUE), "dm_gtsummary_ard")
}))

# ===========================================================================
# D. Tplyr  -- transpose-and-set (body only; metadata set in rtfreporter)
# ===========================================================================
try_block("Tplyr", local({
  library(Tplyr)
  built <- tplyr_table(adsl, TRT01A) |>
    add_layer(group_desc(AGE, by = "Age (years)") |>
                set_format_strings(
                  "Mean (SD)" = f_str("xx.x (xx.xx)", mean, sd),
                  "Median"    = f_str("xx.x", median),
                  "Min, Max"  = f_str("xx, xx", min, max))) |>
    add_layer(group_count(SEX, by = "Sex") |>
                set_format_strings(f_str("xx (xx.x%)", n, pct))) |>
    add_layer(group_count(RACE, by = "Race") |>
                set_format_strings(f_str("xx (xx.x%)", n, pct))) |>
    build()

  # Tplyr returns body strings in var1_<arm> columns plus row_label1 (group) and
  # row_label2 (stat).  Approach B: reshape into a labelled body and set ALL the
  # presentation (column header, alignment) in rtfreporter.
  val_cols <- paste0("var1_", arm_levels)
  body <- built[order(built$ord_layer_index, built$ord_layer_1, built$ord_layer_2), ]
  disp <- do.call(rbind, lapply(split(body, body$row_label1), function(g) {
    grp <- g$row_label1[1]
    hdr <- data.frame(Characteristic = grp, stringsAsFactors = FALSE)
    hdr[val_cols] <- ""
    rows <- data.frame(Characteristic = paste0("  ", g$row_label2),
                       stringsAsFactors = FALSE)
    rows[val_cols] <- lapply(val_cols, function(c) g[[c]])
    rbind(hdr, rows)
  }))
  # Keep the demographic order (Age, Sex, Race) rather than alphabetical split().
  disp <- disp[order(match(sub("^  ", "", disp$Characteristic),
                           c("Age (years)", "Mean (SD)", "Median", "Min, Max",
                             "Sex", "Female", "Male",
                             "Race", "White", "Black or African American",
                             "Asian", "American Indian or Alaska Native"))), ]
  names(disp) <- c("Characteristic", arm_levels)
  rownames(disp) <- NULL

  col_header <- c("Characteristic",
                  paste0(arm_levels, "\nN = ", as.integer(arm_n)))
  render_show(rtftable(disp, col_header = col_header), "dm_tplyr")
}))

# ===========================================================================
# E. tfrmt  -- build-and-read (metadata-driven; long summary -> gt)
# ===========================================================================
try_block("tfrmt", local({
  library(tfrmt); library(tidyr)

  cont <- adsl |>
    group_by(column = TRT01A) |>
    summarise(Mean = mean(AGE), SD = sd(AGE), Median = median(AGE),
              Min = min(AGE), Max = max(AGE), .groups = "drop") |>
    pivot_longer(c(Mean, SD, Median, Min, Max),
                 names_to = "param", values_to = "value") |>
    mutate(group = "Age (years)",
           label = recode(param, Mean = "Mean (SD)", SD = "Mean (SD)",
                          Min = "Min, Max", Max = "Min, Max"))

  cat_long <- function(var, grp) {
    adsl |>
      group_by(column = TRT01A, label = .data[[var]]) |>
      summarise(n = n(), .groups = "drop_last") |>
      mutate(pct = 100 * n / sum(n)) |>
      ungroup() |>
      pivot_longer(c(n, pct), names_to = "param", values_to = "value") |>
      mutate(group = grp, label = as.character(label))
  }
  long <- bind_rows(cont, cat_long("SEX", "Sex"), cat_long("RACE", "Race"))

  spec <- tfrmt(
    group = group, label = label, column = column, param = param, value = value,
    body_plan = body_plan(
      frmt_structure(group_val = ".default", label_val = ".default", frmt("xx.x")),
      frmt_structure(group_val = ".default", label_val = "Mean (SD)",
                     frmt_combine("{Mean} ({SD})",
                                  Mean = frmt("xx.x"), SD = frmt("xx.xx"))),
      frmt_structure(group_val = ".default", label_val = "Min, Max",
                     frmt_combine("{Min}, {Max}",
                                  Min = frmt("xx"), Max = frmt("xx"))),
      frmt_structure(group_val = c("Sex", "Race"), label_val = ".default",
                     frmt_combine("{n} ({pct}%)",
                                  n = frmt("xx"), pct = frmt("xx.x")))))
  long$column <- factor(long$column, levels = arm_levels)
  g <- print_to_gt(spec, long)
  render_show(as_rtftables(g, read_meta = TRUE), "dm_tfrmt")
}))

# -- Placeholder snapshots --------------------------------------------------
# The article embeds a PNG snapshot per RTF (made MANUALLY in Word).  Until a
# real snapshot exists, drop a "pending" placeholder so the pkgdown article
# still builds.  Existing PNGs are NEVER overwritten.
fig_dir <- "vignettes/articles/figures/showcase"
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
for (rtf in list.files(rtf_dir, pattern = "\\.rtf$", full.names = TRUE)) {
  nm  <- sub("\\.rtf$", "", basename(rtf))
  png <- file.path(fig_dir, paste0(nm, ".png"))
  if (file.exists(png)) next
  grDevices::png(png, width = 1000, height = 640, res = 120)
  op <- graphics::par(mar = c(0, 0, 0, 0)); on.exit(graphics::par(op), add = TRUE)
  graphics::plot.new(); graphics::rect(0, 0, 1, 1, col = "#f4f4f4", border = "#cccccc")
  graphics::text(0.5, 0.6, paste0("Snapshot pending: ", nm), cex = 1.4)
  graphics::text(0.5, 0.42, paste0("Open ", nm, ".rtf in Word and replace this PNG"),
                 cex = 1.0, col = "#666666")
  grDevices::dev.off()
  cat(sprintf("  placeholder %s\n", png))
}

cat("Done.\n")
