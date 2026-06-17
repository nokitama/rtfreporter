# data-raw/showcase_dm.R
# ---------------------------------------------------------------------------
# Generate the Demographics (DM) showcase RTFs: the SAME demographics report
# built from several table frameworks, all rendered to RTF by rtfreporter, in a
# production-style layout (Letter landscape; sponsor / protocol / page number /
# title in the running header; analysis note / program path / run time in the
# footer).
#
# Each framework writes data-raw/showcase/rtf/dm_<framework>.rtf .  PNG snapshots
# for the article are created MANUALLY from these RTFs (open in Word) and saved
# to vignettes/articles/figures/showcase/dm_<framework>.png (same basename).
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
  filter(TRT01A %in% arm_levels,
         # Keep races that are present in every arm (Asian = 0 and American
         # Indian = 1 after restricting to the randomised arms, which would
         # leave empty per-arm cells); this keeps every framework happy.
         RACE %in% c("WHITE", "BLACK OR AFRICAN AMERICAN")) |>
  mutate(
    TRT01A = factor(TRT01A, levels = arm_levels),
    # Sex shown Male then Female.
    SEX    = factor(SEX, levels = c("M", "F"), labels = c("Male", "Female")),
    # A few age categories.
    AGEGR  = cut(AGE, breaks = c(-Inf, 65, 81, Inf),
                 labels = c("<65", "65 - 80", ">80"), right = FALSE),
    RACE   = factor(RACE, levels = c("WHITE", "BLACK OR AFRICAN AMERICAN"),
                    labels = c("White", "Black or African American"))
  )
arm_n <- table(adsl$TRT01A)

# -- Shared report furniture (sponsor header / footer; identical everywhere) -
sponsor   <- "Acme Biopharma, Inc."
protocol  <- "Protocol ABC-2026-001"
run_dt    <- "2026-06-17 09:14"                 # fixed for reproducible output

dm_header <- function() rtf_header(rows = list(
  c(l = sponsor,                 r = "Page {AUTO_PAGE} of {AUTO_TOTAL_PAGES}"),
  c(l = protocol,                r = "Status: Draft"),
  c(c = "Table 14.1.1"),
  c(c = "Summary of Demographic and Baseline Characteristics"),
  c(c = "Safety Population"),
  c(c = "")                                      # gap before the content
))
dm_footer <- function(program) rtf_footer(rows = list(
  c(l = "Note: Percentages are based on the number of non-missing subjects in each treatment group."),
  c(l = paste0("Program: ", program),  r = paste0("Generated: ", run_dt)),
  c(l = "Source: ADSL",                r = "CONFIDENTIAL")
))

# Insert blank separator rows around the group structure of a built rtftable:
# a blank before each group header (a non-empty, non-indented column-1 cell)
# except the first, plus one at the very top (0) and very bottom (nrow).
.add_group_blanks <- function(rt) {
  d <- rt$data
  if (is.null(d) || nrow(d) == 0L) return(rt)
  col1 <- as.character(d[[1L]])
  indent_chars <- c(" ", "\t", intToUtf8(160L))
  is_header <- nzchar(col1) & !(substr(col1, 1L, 1L) %in% indent_chars)
  hdr <- which(is_header)
  between <- hdr[hdr > 1L] - 1L
  rt$blank_rows <- sort(unique(as.integer(c(0L, between, nrow(d)))))
  rt
}

# Render already-built page object(s) to RTF.  Strips any framework-supplied
# title / footnote (the title lives in the running header, the notes in the
# footer) and adds group / top / bottom blank rows.
render_show <- function(pages, name, program = NULL, ...) {
  if (!is.list(pages) || inherits(pages, "rtftable")) pages <- list(pages)
  pages <- lapply(pages, function(p) {
    attr(p, "rtf_titles")    <- NULL
    attr(p, "rtf_footnotes") <- NULL
    .add_group_blanks(p)
  })
  if (is.null(program)) program <- paste0("/prod/abc/tfl/t_14_1_1_", name, ".R")
  doc <- rtf_document(page = list(paper_size = "letter", orientation = "landscape")) |>
    rtf_section(page = 1, secinfo = list(header = dm_header(), footer = dm_footer(program))) |>
    rtf_tables(pages, ...)
  out <- file.path(rtf_dir, paste0(name, ".rtf"))
  generate_rtfreport(doc, out, overwrite = TRUE)
  cat(sprintf("  wrote %s (%d bytes)\n", out, file.size(out)))
}

# Run a framework block; report but do not abort on error.
try_block <- function(name, expr) {
  tryCatch(force(expr),
           error = function(e) cat(sprintf("  [SKIP] %s: %s\n", name, conditionMessage(e))))
}

cat("Generating DM showcase RTFs...\n")

# ===========================================================================
# A. gtsummary (standalone)  -- build-and-read (read_meta)
# ===========================================================================
try_block("gtsummary", local({
  library(gtsummary)
  tbl <- adsl |>
    select(TRT01A, AGE, AGEGR, SEX, RACE) |>
    tbl_summary(
      by = TRT01A,
      type = list(AGE ~ "continuous2"),
      label = list(AGE = "Age (years)", AGEGR = "Age category",
                   SEX = "Sex", RACE = "Race"),
      statistic = list(
        AGE ~ c("{N_nonmiss}", "{mean} ({sd})", "{median}", "{min}, {max}"),
        all_categorical() ~ "{n} ({p}%)"),
      digits = list(AGE ~ c(0, 1, 2, 1, 0, 0),
                    all_categorical() ~ c(0, 1))) |>
    modify_header(all_stat_cols() ~ "**{level}**  \nN = {n}")
  render_show(as_rtftables(tbl, read_meta = TRUE, align_count_pct = TRUE),
              "dm_gtsummary")
}))

# ===========================================================================
# B. rtables / tern  -- build-and-read (read_meta)
# ===========================================================================
try_block("rtables", local({
  library(rtables); library(tern)
  lyt <- basic_table(show_colcounts = TRUE) |>
    split_cols_by("TRT01A") |>
    analyze_vars(
      vars = c("AGE", "AGEGR", "SEX", "RACE"),
      var_labels = c(AGE = "Age (years)", AGEGR = "Age category",
                     SEX = "Sex", RACE = "Race"),
      .stats = c("n", "mean_sd", "median", "range", "count_fraction"),
      .formats = c(count_fraction = function(x) {
        sprintf("%d (%.1f%%)", round(x[1]), 100 * x[2])
      }))
  tbl <- build_table(lyt, adsl)
  render_show(as_rtftables(tbl, read_meta = TRUE, align_count_pct = TRUE),
              "dm_rtables")
}))

# ===========================================================================
# C. cards / cardx + gtsummary (ARD workflow)  -- build-and-read
# ===========================================================================
try_block("gtsummary-ARD", local({
  library(cards); library(gtsummary)
  ard <- ard_stack(
    data = adsl, .by = TRT01A,
    ard_continuous(variables = AGE,
                   statistic = ~ list(N = length, mean = mean, sd = sd,
                                      median = median, min = min, max = max)),
    ard_categorical(variables = c(AGEGR, SEX, RACE)), .total_n = TRUE)
  tbl <- tbl_ard_summary(
    ard, by = TRT01A,
    type = list(AGE = "continuous2"),
    label = list(AGE = "Age (years)", AGEGR = "Age category",
                 SEX = "Sex", RACE = "Race"),
    statistic = list(
      AGE = c("{N}", "{mean} ({sd})", "{median}", "{min}, {max}"),
      all_categorical() ~ "{n} ({p}%)"))
  render_show(as_rtftables(tbl, read_meta = TRUE, align_count_pct = TRUE),
              "dm_gtsummary_ard")
}))

# ===========================================================================
# D. Tplyr  -- transpose-and-set (body only; metadata set in rtfreporter)
# ===========================================================================
try_block("Tplyr", local({
  library(Tplyr)
  built <- tplyr_table(adsl, TRT01A) |>
    add_layer(group_desc(AGE, by = "Age (years)") |>
                set_format_strings(
                  "n"         = f_str("xx", n),
                  "Mean (SD)" = f_str("xx.x (xx.xx)", mean, sd),
                  "Median"    = f_str("xx.x", median),
                  "Min, Max"  = f_str("xx, xx", min, max))) |>
    add_layer(group_count(AGEGR, by = "Age category") |>
                set_format_strings(f_str("xx (xx.x%)", n, pct))) |>
    add_layer(group_count(SEX, by = "Sex") |>
                set_format_strings(f_str("xx (xx.x%)", n, pct))) |>
    add_layer(group_count(RACE, by = "Race") |>
                set_format_strings(f_str("xx (xx.x%)", n, pct))) |>
    build()

  val_cols <- paste0("var1_", arm_levels)
  ord <- c("Age (years)", "n", "Mean (SD)", "Median", "Min, Max",
           "Age category", "<65", "65 - 80", ">80",
           "Sex", "Male", "Female",
           "Race", "White", "Black or African American", "Asian",
           "American Indian or Alaska Native")
  groups <- c("Age (years)", "Age category", "Sex", "Race")
  body <- built[order(built$ord_layer_index, built$ord_layer_1, built$ord_layer_2), ]
  disp <- do.call(rbind, lapply(split(body, factor(body$row_label1, groups)), function(g) {
    hdr <- data.frame(Characteristic = g$row_label1[1], stringsAsFactors = FALSE)
    hdr[val_cols] <- ""
    rows <- data.frame(Characteristic = paste0("  ", g$row_label2),
                       stringsAsFactors = FALSE)
    rows[val_cols] <- lapply(val_cols, function(c) g[[c]])
    rbind(hdr, rows)
  }))
  disp <- disp[order(match(sub("^  ", "", disp$Characteristic), ord)), ]
  # "Number of subjects" line on top (just N).
  top <- data.frame(Characteristic = "Number of Subjects", stringsAsFactors = FALSE)
  top[val_cols] <- as.character(as.integer(arm_n))
  disp <- rbind(top, disp)
  names(disp) <- c("Characteristic", arm_levels)
  rownames(disp) <- NULL

  col_header <- c("Characteristic",
                  paste0(arm_levels, "\nN = ", as.integer(arm_n)))
  render_show(as_rtftables(disp, col_header = col_header, align_count_pct = TRUE)[[1L]],
              "dm_tplyr")
}))

# ===========================================================================
# E. tfrmt  -- build-and-read (metadata-driven; long summary -> gt)
# ===========================================================================
try_block("tfrmt", local({
  library(tfrmt); library(tidyr)

  cont <- adsl |>
    group_by(column = TRT01A) |>
    summarise(n = sum(!is.na(AGE)), Mean = mean(AGE), SD = sd(AGE),
              Median = median(AGE), Min = min(AGE), Max = max(AGE),
              .groups = "drop") |>
    pivot_longer(c(n, Mean, SD, Median, Min, Max),
                 names_to = "param", values_to = "value") |>
    mutate(group = "Age (years)",
           label = recode(param, n = "n", Mean = "Mean (SD)", SD = "Mean (SD)",
                          Median = "Median", Min = "Min, Max", Max = "Min, Max"))

  cat_long <- function(var, grp) {
    adsl |>
      group_by(column = TRT01A, label = .data[[var]]) |>
      summarise(n = n(), .groups = "drop_last") |>
      mutate(pct = 100 * n / sum(n)) |>
      ungroup() |>
      pivot_longer(c(n, pct), names_to = "param", values_to = "value") |>
      mutate(group = grp, label = as.character(label))
  }
  long <- bind_rows(cont,
                    cat_long("AGEGR", "Age category"),
                    cat_long("SEX",   "Sex"),
                    cat_long("RACE",  "Race"))
  long$column <- factor(long$column, levels = arm_levels)

  spec <- tfrmt(
    group = group, label = label, column = column, param = param, value = value,
    body_plan = body_plan(
      frmt_structure(".default", ".default", frmt("xx.x")),
      frmt_structure("Age (years)", "n", frmt("xx")),
      frmt_structure(".default", "Mean (SD)",
                     frmt_combine("{Mean} ({SD})",
                                  Mean = frmt("xx.x"), SD = frmt("xx.xx"))),
      frmt_structure(".default", "Min, Max",
                     frmt_combine("{Min}, {Max}",
                                  Min = frmt("xx"), Max = frmt("xx"))),
      frmt_structure(c("Age category", "Sex", "Race"), ".default",
                     frmt_combine("{n} ({pct}%)",
                                  n = frmt("xx"), pct = frmt("xx.x")))))
  g <- print_to_gt(spec, long)
  render_show(as_rtftables(g, read_meta = TRUE, align_count_pct = TRUE),
              "dm_tfrmt")
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
  grDevices::png(png, width = 1200, height = 720, res = 120)
  op <- graphics::par(mar = c(0, 0, 0, 0))
  graphics::plot.new(); graphics::rect(0, 0, 1, 1, col = "#f4f4f4", border = "#cccccc")
  graphics::text(0.5, 0.6, paste0("Snapshot pending: ", nm), cex = 1.4)
  graphics::text(0.5, 0.42, paste0("Open ", nm, ".rtf in Word and replace this PNG"),
                 cex = 1.0, col = "#666666")
  graphics::par(op); grDevices::dev.off()
  cat(sprintf("  placeholder %s\n", png))
}

cat("Done.\n")
