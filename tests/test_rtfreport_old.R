source(file.path("R", "rtf_border.R"))
source(file.path("R", "rtfreport.R"))
source(file.path("R", "rtftable.R"))
source(file.path("R", "rtfplot.R"))
source(file.path("R", "generate_rtfreport.R"))

stopifnot(inherits(rtfreport, "R6ClassGenerator"))

# Load DM/AE sample data
DM <- read.csv(file.path("tests", "testdata", "dm.csv"), stringsAsFactors = FALSE)
AE <- read.csv(file.path("tests", "testdata", "ae.csv"), stringsAsFactors = FALSE)

# ── Backward-compat test: legacy list(columns = c(...)) row format ─────────────
# The renderer must still accept list(columns = c(...)) in section headers/footers.

report <- rtfreport$new()
sec <- report$add_section(
  header = list(columns = c("DM/AE Listing", "", "Page {AUTO_PAGE} of {TOTAL_PAGES}"))
)

report$add_page(
  section_index = sec,
  title = "Demographics (DM)",
  content = list(
    list(type = "table", data = DM, footer = "Source: DM domain")
  ),
  footer_notes = "Confidential"
)

report$add_page(
  section_index = sec,
  title = "Adverse Events (AE)",
  content = list(
    list(type = "listing", data = AE, footer = "Source: AE domain")
  )
)

report$set_section_footer(sec, list(columns = c("Confidential - Do Not Distribute")))

outfile <- file.path(tempdir(), "dm_ae_report_old.rtf")
generate_rtfreport(report, outfile, overwrite = TRUE)

stopifnot(file.exists(outfile))
rtf_txt <- paste(readLines(outfile, warn = FALSE), collapse = "\n")
stopifnot(grepl("\\\\rtf1", rtf_txt))
stopifnot(grepl("Demographics \\(DM\\)", rtf_txt))
stopifnot(grepl("DM/AE Listing", rtf_txt))
# {AUTO_PAGE} renders as \chpgn; {TOTAL_PAGES} is static
stopifnot(grepl("\\chpgn", rtf_txt, fixed = TRUE))
stopifnot(grepl(" of 2", rtf_txt, fixed = TRUE))
# Single-column footer: top border (\clbrdrt) must be present.
stopifnot(grepl("clbrdrt", rtf_txt))
# Single-column footer: left align (\ql) must be present.
stopifnot(grepl("\\\\ql", rtf_txt))

# ── Manual builder (legacy format) ────────────────────────────────────────────
report_manual <- rtfreport$new()
report_manual$set_document_defaults(
  default_format = list(font_size_half_points = 16L),
  default_page = list(margin_left_twips = 900L)
)

sec_m <- report_manual$add_section()
report_manual$set_section_header(sec_m, list(columns = c("Protocol: XYZ", "", "HOGE company")))
report_manual$set_section_footer(sec_m, list(columns = c("Page {AUTO_PAGE} of {TOTAL_PAGES}")))

page_m <- report_manual$add_page(section_index = sec_m, title = "Manual Build")
report_manual$add_table(sec_m, page_m, data = DM, footer = "DM table footer")
report_manual$add_listing(sec_m, page_m, data = AE, footer = "AE listing footer")
report_manual$set_page_footer_notes(sec_m, page_m, "Manual footer note")

outfile_manual <- file.path("tests", "output", "manual_builder_report.rtf")
generate_rtfreport(report_manual, outfile_manual, overwrite = TRUE)

stopifnot(file.exists(outfile_manual))
rtf_manual <- paste(readLines(outfile_manual, warn = FALSE), collapse = "\n")
stopifnot(grepl("Manual Build", rtf_manual))
stopifnot(grepl("Protocol: XYZ", rtf_manual))
stopifnot(grepl("DM table footer", rtf_manual))
stopifnot(grepl("AE listing footer", rtf_manual))
stopifnot(grepl("Manual footer note", rtf_manual))
stopifnot(grepl("clbrdrt", rtf_manual))

# ── Multi-section test using legacy format (no doc-wide defaults) ─────────────
DM_COHORT <- read.csv(file.path("tests", "testdata", "dm_cohort.csv"), stringsAsFactors = FALSE)
AE_COHORT <- read.csv(file.path("tests", "testdata", "ae_cohort.csv"), stringsAsFactors = FALSE)

report2 <- rtfreport$new()

# Section 1: full 3-row header using legacy list(columns=c(...)) format
sec1 <- report2$add_section(
  header = list(rows = list(
    list(columns = c("Protocol: XXXXX", "", "HOGE company")),
    list(columns = c("HOGEHOGE", "", "Page {AUTO_PAGE} of {TOTAL_PAGES}")),
    list(columns = c("Cohort: Cohort 1", "", ""))
  )),
  footer = list(rows = list(list(columns = c("Confidential", "", ""))))
)

report2$add_page(
  section_index = sec1,
  title = "Demographics (Cohort 1)",
  content = list(
    list(type = "table", data = DM_COHORT[DM_COHORT$COHORT == "Cohort 1", ])
  )
)
report2$add_page(
  section_index = sec1,
  title = "Adverse Events (Cohort 1)",
  content = list(
    list(type = "listing", data = AE_COHORT[AE_COHORT$COHORT == "Cohort 1", ])
  )
)

# Section 2: inherits from section 1 (no header/footer specified → inherit)
sec2 <- report2$add_section(
  header = list(rows = list(
    list(columns = c("Protocol: XXXXX", "", "HOGE company")),
    list(columns = c("HOGEHOGE", "", "Page {AUTO_PAGE} of {TOTAL_PAGES}")),
    list(columns = c("Cohort: Cohort 2", "", ""))
  ))
)

report2$add_page(
  section_index = sec2,
  title = "Demographics (Cohort 2)",
  content = list(
    list(type = "table", data = DM_COHORT[DM_COHORT$COHORT == "Cohort 2", ])
  )
)

dir.create(file.path("tests", "output"), recursive = TRUE, showWarnings = FALSE)
outfile2 <- file.path("tests", "output", "cohort_multi_section_report.rtf")
generate_rtfreport(report2, outfile2, overwrite = TRUE)

stopifnot(file.exists(outfile2))
rtf_txt2 <- paste(readLines(outfile2, warn = FALSE), collapse = "\n")

# Tokens must be rendered (not literal)
stopifnot(!grepl("\\{AUTO_PAGE\\}", rtf_txt2, fixed = TRUE))
stopifnot(grepl("\\chpgn", rtf_txt2, fixed = TRUE))

# Header text must appear
stopifnot(grepl("HOGEHOGE", rtf_txt2))
stopifnot(grepl("HOGE company", rtf_txt2))
stopifnot(grepl("Cohort: Cohort 1", rtf_txt2))
stopifnot(grepl("Cohort: Cohort 2", rtf_txt2))

# Footer: top border (\clbrdrt) must appear (top_border = TRUE default).
stopifnot(grepl("clbrdrt", rtf_txt2))

# Multiple pages and section break expected.
stopifnot(grepl("\\\\page", rtf_txt2))
stopifnot(grepl("\\\\sect", rtf_txt2))

cat("All rtfreporter backward-compat tests passed.\n")
