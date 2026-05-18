source(file.path("R", "rtfreport.R"))
source(file.path("R", "generate_rtfreport.R"))

stopifnot(inherits(rtfreport, "R6ClassGenerator"))

# Load DM/AE sample data
DM <- read.csv(file.path("tests", "testdata", "dm.csv"), stringsAsFactors = FALSE)
AE <- read.csv(file.path("tests", "testdata", "ae.csv"), stringsAsFactors = FALSE)

# Basic test: section header is a single section-specific row (no document-wide rows set).
report <- rtfreport$new()
sec <- report$add_section(
  header = list(columns = c("DM/AE Listing", "", "Page {PAGE} of {TOTAL_PAGES}"))
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

# Add a section footer to verify: single-column footer = left align + top border.
report$set_section_footer(sec, list(columns = c("Confidential - Do Not Distribute")))

outfile <- file.path(tempdir(), "dm_ae_report.rtf")
generate_rtfreport(report, outfile, overwrite = TRUE)

# Assertions
stopifnot(file.exists(outfile))
rtf_txt <- paste(readLines(outfile, warn = FALSE), collapse = "\n")
stopifnot(grepl("\\\\rtf1", rtf_txt))
stopifnot(grepl("Demographics \\(DM\\)", rtf_txt))
stopifnot(grepl("Adverse Events \\(AE\\)", rtf_txt))
stopifnot(grepl("DM/AE Listing", rtf_txt))
stopifnot(grepl("Page", rtf_txt))
# Single-column footer: top border (\clbrdrt) must be present.
stopifnot(grepl("clbrdrt", rtf_txt))
# Single-column footer: left align (\ql) must be present.
stopifnot(grepl("\\\\ql", rtf_txt))

# Negative test: unsupported block type should fail
bad_report <- rtfreport$new()
bad_sec <- bad_report$add_section()
bad_report$add_page(
  section_index = bad_sec,
  title = "Bad page",
  content = list(list(type = "unknown", data = DM))
)

err <- tryCatch({
  generate_rtfreport(bad_report, file.path(tempdir(), "bad.rtf"), overwrite = TRUE)
  NULL
}, error = function(e) e)

stopifnot(!is.null(err))
stopifnot(grepl("Unsupported block type", conditionMessage(err)))

# Manual builder methods test
report_manual <- rtfreport$new()
report_manual$set_document_defaults(
  default_format = list(font_size_half_points = 16L),
  default_page = list(margin_left_twips = 900L)
)

sec_m <- report_manual$add_section()
report_manual$set_section_header(sec_m, list(columns = c("Protocol: XYZ", "", "HOGE company")))
report_manual$set_section_footer(sec_m, list(columns = c("Page {PAGE} of {TOTAL_PAGES}")))

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
# Single-column section footer: top border (\clbrdrt) must appear.
stopifnot(grepl("clbrdrt", rtf_manual))

# Multi-page + multi-section (cohort) test
# New structure: document-wide 3 rows + section-specific 1 row per section.
DM_COHORT <- read.csv(file.path("tests", "testdata", "dm_cohort.csv"), stringsAsFactors = FALSE)
AE_COHORT <- read.csv(file.path("tests", "testdata", "ae_cohort.csv"), stringsAsFactors = FALSE)

report2 <- rtfreport$new()

# Document-wide header: rows 1-3 (common to all sections).
report2$set_default_header(list(
  rows = list(
    list(columns = c("Protocol: XXXXX", "", "HOGE company")),
    list(columns = c("HOGEHOGE", "", "Page {PAGE} of {TOTAL_PAGES}")),
    list(columns = c("", "Demographic/AE Listing", ""))
  )
))

# Document-wide footer: 1 shared row + top border (default).
report2$set_default_footer(list(
  rows = list(
    list(columns = c("Confidential", "", ""))
  )
))

# Section 1: header row 4 is section-specific.
sec1 <- report2$add_section(
  header = list(columns = c("Cohort: Cohort 1", "", ""))
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

# Section 2: header row 4 is section-specific.
sec2 <- report2$add_section(
  header = list(columns = c("Cohort: Cohort 2", "", ""))
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

# Tokens must be rendered as RTF fields (not literal {PAGE}).
stopifnot(!grepl("\\\\\\{PAGE\\\\\\}", rtf_txt2))
stopifnot(!grepl("\\\\\\{TOTAL_PAGES\\\\\\}", rtf_txt2))
stopifnot(grepl("fldinst PAGE", rtf_txt2))
stopifnot(grepl("fldinst NUMPAGES", rtf_txt2))

# Document-wide header rows must appear in output.
stopifnot(grepl("HOGEHOGE", rtf_txt2))
stopifnot(grepl("HOGE company", rtf_txt2))
stopifnot(grepl("Demographic/AE Listing", rtf_txt2))

# Section-specific header rows (row 4) must both appear.
stopifnot(grepl("Cohort: Cohort 1", rtf_txt2))
stopifnot(grepl("Cohort: Cohort 2", rtf_txt2))

# Footer: top border (\clbrdrt) must appear (top_border = TRUE default).
stopifnot(grepl("clbrdrt", rtf_txt2))

# Multiple pages and section break expected.
stopifnot(grepl("\\\\page", rtf_txt2))
stopifnot(grepl("\\\\sect", rtf_txt2))

cat("All rtfreporter R tests passed.\n")
