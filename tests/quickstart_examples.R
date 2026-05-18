source(file.path("R", "rtfreport.R"))
source(file.path("R", "rtftable.R"))
source(file.path("R", "rtfplot.R"))
source(file.path("R", "generate_rtfreport.R"))

DM <- read.csv(file.path("tests", "testdata", "dm.csv"), stringsAsFactors = FALSE)
LB <- read.csv(file.path("tests", "testdata", "lb.csv"), stringsAsFactors = FALSE)

dir.create(file.path("tests", "output"), recursive = TRUE, showWarnings = FALSE)

make_common_header <- function(study_title) {
  list(
    rows = list(
      c(l = "Protocol: RTF-101", r = "Page {PAGE} of {TOTAL_PAGES}"),
      c(l = study_title, r = "For Clinical Study Use Only")
    )
  )
}

make_common_footer <- function() {
  list(
    rows = list(
      c(l = "Confidential - Internal Use Only")
    )
  )
}

# ---------------------------------------------------------------------------
# 1) One-page DM report
# ---------------------------------------------------------------------------
dm_report <- rtfreport$new()
dm_report$set_default_header(make_common_header("Table 14.1.1 Demographics"))
dm_report$set_default_footer(make_common_footer())

dm_sec <- dm_report$add_section(
  header = c(l = "Demographics (Screened Population)", r = "Safety Set")
)
dm_page <- dm_report$add_page(
  section_index = dm_sec,
  title = "Table 14.1.1 Demographics by Treatment Arm"
)

dm_disp <- data.frame(
  `Subject ID` = DM$USUBJID,
  `Treatment Arm` = DM$ARM,
  Sex = DM$SEX,
  Age = DM$AGE,
  check.names = FALSE,
  stringsAsFactors = FALSE
)
dm_tbl <- rtftable$new(
  dm_disp,
  col_header = c("Subject ID", "Treatment Arm", "Sex", "Age"),
  col_rel_width = c(1.8, 2.2, 0.8, 0.8),
  row_height_twips = 300L,
  header_row_height_twips = 300L
)
dm_report$add_table(dm_sec, dm_page, data = dm_tbl, footer = "Source: DM domain")

dm_out <- file.path("tests", "output", "quickstart_dm_report.rtf")
generate_rtfreport(dm_report, dm_out, overwrite = TRUE)

# ---------------------------------------------------------------------------
# 2) Lab report with one section per analyte
# ---------------------------------------------------------------------------
lb_report <- rtfreport$new()
lb_report$set_default_header(make_common_header("Table 14.2.1 Clinical Laboratory Summary"))
lb_report$set_default_footer(make_common_footer())

lb_tests <- unique(LB$LBTEST)
for (test_name in lb_tests) {
  sec <- lb_report$add_section(
    header = c(l = paste0("Clinical Laboratory: ", test_name), r = "Page {PAGE} of {TOTAL_PAGES}")
  )
  page <- lb_report$add_page(
    section_index = sec,
    title = paste0(test_name, " by Subject")
  )

  test_df <- subset(LB, LBTEST == test_name, select = c(USUBJID, ARM, VISIT, LBSTRESN, LBSTRESU, LBNRLO, LBNRHI, LBNRIND))
  names(test_df) <- c("Subject ID", "Treatment Arm", "Visit", "Result", "Unit", "Ref Low", "Ref High", "Flag")

  test_tbl <- rtftable$new(
    test_df,
    col_rel_width = c(1.4, 1.6, 1.0, 0.8, 0.8, 0.8, 0.8, 0.7),
    row_height_twips = 300L,
    header_row_height_twips = 300L
  )
  lb_report$add_table(sec, page, data = test_tbl, footer = paste0("Source: LB domain | ", test_name))
}

lb_out <- file.path("tests", "output", "quickstart_lab_report.rtf")
generate_rtfreport(lb_report, lb_out, overwrite = TRUE)

stopifnot(file.exists(dm_out))
stopifnot(file.exists(lb_out))
cat("Quickstart example reports created:\n")
cat(dm_out, "\n")
cat(lb_out, "\n")