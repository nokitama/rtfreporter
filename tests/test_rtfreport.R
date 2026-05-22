source(file.path("R", "rtf_border.R"))
source(file.path("R", "rtfreport.R"))
source(file.path("R", "rtftable.R"))
source(file.path("R", "rtfplot.R"))
source(file.path("R", "generate_rtfreport.R"))

stopifnot(inherits(rtfreport, "R6ClassGenerator"))

# Load DM/AE sample data
DM <- read.csv(file.path("tests", "testdata", "dm.csv"), stringsAsFactors = FALSE)
AE <- read.csv(file.path("tests", "testdata", "ae.csv"), stringsAsFactors = FALSE)

# ============================================================================
# Basic test: new named-column header format
# ============================================================================
report <- rtfreport$new()
sec <- report$add_section(
  header = c(l = "DM/AE Listing", r = "Page {AUTO_PAGE} of {TOTAL_PAGES}")
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

# Add a section footer: single-column (left align) + top border.
report$set_section_footer(sec, c(l = "Confidential - Do Not Distribute"))

outfile <- file.path(tempdir(), "dm_ae_report.rtf")
generate_rtfreport(report, outfile, overwrite = TRUE)

# Assertions
stopifnot(file.exists(outfile))
rtf_txt <- paste(readLines(outfile, warn = FALSE), collapse = "\n")
stopifnot(grepl("\\\\rtf1", rtf_txt))
stopifnot(grepl("Demographics \\(DM\\)", rtf_txt))
stopifnot(grepl("Adverse Events \\(AE\\)", rtf_txt))
stopifnot(grepl("DM/AE Listing", rtf_txt))
# {AUTO_PAGE} renders as \chpgn (RTF dynamic field); {TOTAL_PAGES} renders as static count "2".
stopifnot(grepl("\\chpgn", rtf_txt, fixed = TRUE))
stopifnot(grepl(" of 2", rtf_txt, fixed = TRUE))
# Single-column footer: top border (\\clbrdrt) must be present.
stopifnot(grepl("clbrdrt", rtf_txt))
# Single-column footer: left align (\\ql) must be present.
stopifnot(grepl("\\\\ql", rtf_txt))

# ============================================================================
# Negative test: unsupported block type should fail
# ============================================================================
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

# ============================================================================
# Manual builder methods test
# ============================================================================
report_manual <- rtfreport$new()
report_manual$set_document_defaults(
  default_format = list(font_size_half_points = 16L),
  default_page = list(margin_left_twips = 900L)
)

sec_m <- report_manual$add_section()
report_manual$set_section_header(sec_m, c(l = "Protocol: XYZ", r = "HOGE company"))
report_manual$set_section_footer(sec_m, c(l = "Page {AUTO_PAGE} of {TOTAL_PAGES}"))

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
# {AUTO_PAGE} renders as \chpgn; {TOTAL_PAGES} renders as static "1".
stopifnot(grepl("\\chpgn", rtf_manual, fixed = TRUE))
stopifnot(grepl(" of 1", rtf_manual, fixed = TRUE))
# Single-column section footer: top border (\\clbrdrt) must appear.
stopifnot(grepl("clbrdrt", rtf_manual))

# ============================================================================
# Multi-page + multi-section (cohort) test with aggregated tables
# New structure: document-wide 3 rows + section-specific 1 row per section
# Header rows: 2-column, 2-column, 1-column center
# Footer rows: 1-column left (with top border)
# ============================================================================
DM_COHORT <- read.csv(file.path("tests", "testdata", "dm_cohort.csv"), stringsAsFactors = FALSE)
AE_COHORT <- read.csv(file.path("tests", "testdata", "ae_cohort.csv"), stringsAsFactors = FALSE)

# Create aggregated DM table: cohort, sex, count, mean age
dm_agg <- aggregate(
  DM_COHORT$AGE,
  by = list(COHORT = DM_COHORT$COHORT, SEX = DM_COHORT$SEX),
  FUN = function(x) length(x)
)
names(dm_agg)[names(dm_agg) == "x"] <- "N"

# Calculate mean age per cohort/sex
dm_age <- aggregate(
  DM_COHORT$AGE,
  by = list(COHORT = DM_COHORT$COHORT, SEX = DM_COHORT$SEX),
  FUN = mean
)
names(dm_age)[names(dm_age) == "x"] <- "Mean_Age"
dm_age$Mean_Age <- round(dm_age$Mean_Age, 1)

# Merge
dm_summary <- merge(dm_agg, dm_age)
dm_summary <- dm_summary[order(dm_summary$COHORT, dm_summary$SEX), ]

# Create aggregated AE table
ae_agg <- aggregate(
  rep(1, nrow(AE_COHORT)),
  by = list(COHORT = AE_COHORT$COHORT, AETERM = AE_COHORT$AETERM),
  FUN = sum
)
names(ae_agg)[names(ae_agg) == "x"] <- "Count"

report2 <- rtfreport$new()

# Section 1: full header (3 common rows + 1 section-specific row), plus footer.
sec1 <- report2$add_section(
  header = list(
    rows = list(
      c(l = "Protocol: XXXXX",                            r = "HOGE company"),
      c(l = "Study Title",                                r = "Page {AUTO_PAGE} of {TOTAL_PAGES}"),
      c(c = "Table 14.1.1 Demographic and Safety Summary"),
      c(l = "Cohort: Cohort 1")
    )
  ),
  footer = list(rows = list(c(l = "Confidential")))
)

report2$add_page(
  section_index = sec1,
  title = "Demographics Summary (Cohort 1)",
  content = list(
    list(type = "table", data = dm_summary[dm_summary$COHORT == "Cohort 1", ])
  )
)

report2$add_page(
  section_index = sec1,
  title = "Adverse Events (Cohort 1)",
  content = list(
    list(type = "table", data = ae_agg[ae_agg$COHORT == "Cohort 1", ])
  )
)

# Section 2: different section-specific row (rows 1-3 same, row 4 different).
sec2 <- report2$add_section(
  header = list(
    rows = list(
      c(l = "Protocol: XXXXX",                            r = "HOGE company"),
      c(l = "Study Title",                                r = "Page {AUTO_PAGE} of {TOTAL_PAGES}"),
      c(c = "Table 14.1.1 Demographic and Safety Summary"),
      c(l = "Cohort: Cohort 2")
    )
  ),
  footer = list(rows = list(c(l = "Confidential")))
)

report2$add_page(
  section_index = sec2,
  title = "Demographics Summary (Cohort 2)",
  content = list(
    list(type = "table", data = dm_summary[dm_summary$COHORT == "Cohort 2", ])
  )
)

report2$add_page(
  section_index = sec2,
  title = "Adverse Events (Cohort 2)",
  content = list(
    list(type = "table", data = ae_agg[ae_agg$COHORT == "Cohort 2", ])
  )
)

dir.create(file.path("tests", "output"), recursive = TRUE, showWarnings = FALSE)
outfile2 <- file.path("tests", "output", "cohort_multi_section_report.rtf")
generate_rtfreport(report2, outfile2, overwrite = TRUE)

stopifnot(file.exists(outfile2))
rtf_txt2 <- paste(readLines(outfile2, warn = FALSE), collapse = "\n")

# {AUTO_PAGE} renders as \chpgn; {TOTAL_PAGES} renders as static "4".
stopifnot(grepl("\\chpgn", rtf_txt2, fixed = TRUE))
stopifnot(grepl(" of 4", rtf_txt2, fixed = TRUE))

# Header rows must appear in output (from both sections)
stopifnot(grepl("HOGE company", rtf_txt2))
stopifnot(grepl("Study Title", rtf_txt2))
stopifnot(grepl("Demographic and Safety Summary", rtf_txt2))

# Section-specific header rows (row 4) must both appear
stopifnot(grepl("Cohort: Cohort 1", rtf_txt2))
stopifnot(grepl("Cohort: Cohort 2", rtf_txt2))

# Footer: top border (\\clbrdrt) must appear (top_border = TRUE default)
stopifnot(grepl("clbrdrt", rtf_txt2))

# Multiple pages and section break expected
stopifnot(grepl("\\\\page", rtf_txt2))
stopifnot(grepl("\\\\sect", rtf_txt2))

# ============================================================================
# Metadata-driven table layout test
# ============================================================================
report_meta <- rtfreport$new()
sec_meta <- report_meta$add_section()
report_meta$add_page(
  section_index = sec_meta,
  title = "Metadata Layout",
  content = list(
    list(
      type = "table",
      data = DM[, c("USUBJID", "SEX")],
      metadata = list(
        row_height_twips = 360L,
        column_widths_twips = c(1200L, 3600L)
      )
    )
  )
)

outfile_meta <- file.path(tempdir(), "metadata_layout.rtf")
generate_rtfreport(report_meta, outfile_meta, overwrite = TRUE)
rtf_meta <- paste(readLines(outfile_meta, warn = FALSE), collapse = "\n")

stopifnot(grepl("\\\\trrh360", rtf_meta))
stopifnot(grepl("\\\\cellx1200", rtf_meta))
stopifnot(grepl("\\\\cellx4800", rtf_meta))

# ============================================================================
# Convenience builder: add_section_from_dataframes()
# ============================================================================
report_bundle <- rtfreport$new()
bundle_sec <- report_bundle$add_section_from_dataframes(
  data_list = list(
    `DM page` = DM[1:2, ],
    `AE page` = AE[1:2, ]
  ),
  section_header = c(l = "Bundle Section"),
  page_footer_notes = "bundle note"
)

stopifnot(bundle_sec == 1L)
stopifnot(length(report_bundle$sections[[bundle_sec]]$pages) == 2L)
stopifnot(identical(report_bundle$sections[[bundle_sec]]$pages[[1]]$title, "DM page"))
stopifnot(identical(report_bundle$sections[[bundle_sec]]$pages[[2]]$title, "AE page"))

outfile_bundle <- file.path(tempdir(), "bundle_section_report.rtf")
generate_rtfreport(report_bundle, outfile_bundle, overwrite = TRUE)

bundle_txt <- paste(readLines(outfile_bundle, warn = FALSE), collapse = "\n")
stopifnot(grepl("Bundle Section", bundle_txt, fixed = TRUE))
stopifnot(grepl("DM page", bundle_txt, fixed = TRUE))
stopifnot(grepl("AE page", bundle_txt, fixed = TRUE))
stopifnot(grepl("bundle note", bundle_txt, fixed = TRUE))

# ============================================================================
# rtftable: border="tfl" – header gets top+bottom, last row gets bottom
# ============================================================================
small_df <- data.frame(A = c("a1", "a2"), B = c("b1", "b2"), stringsAsFactors = FALSE)
tbl_tfl <- rtftable$new(small_df, border = "tfl")
report_tfl <- rtfreport$new()
sec_tfl <- report_tfl$add_section()
report_tfl$add_page(
  section_index = sec_tfl,
  content = list(list(type = "table", data = tbl_tfl))
)
out_tfl <- file.path(tempdir(), "tbl_tfl.rtf")
generate_rtfreport(report_tfl, out_tfl, overwrite = TRUE)
tfl_txt <- paste(readLines(out_tfl, warn = FALSE), collapse = "\n")
# Header row must have clbrdrt (top) and clbrdrb (bottom)
stopifnot(grepl("clbrdrt\\\\brdrs", tfl_txt))
stopifnot(grepl("clbrdrb\\\\brdrs", tfl_txt))

# ============================================================================
# rtftable: border=NULL – no border commands emitted
# ============================================================================
tbl_noborder <- rtftable$new(small_df, border = NULL)
report_nb <- rtfreport$new()
sec_nb <- report_nb$add_section()
report_nb$add_page(
  section_index = sec_nb,
  content = list(list(type = "table", data = tbl_noborder))
)
out_nb <- file.path(tempdir(), "tbl_noborder.rtf")
generate_rtfreport(report_nb, out_nb, overwrite = TRUE)
nb_txt <- paste(readLines(out_nb, warn = FALSE), collapse = "\n")
stopifnot(!grepl("clbrdrt", nb_txt, fixed = TRUE))
stopifnot(!grepl("clbrdrb", nb_txt, fixed = TRUE))

# ============================================================================
# rtftable: col_spec bold / italic / align
# ============================================================================
tbl_cs <- rtftable$new(
  small_df,
  col_spec = list(
    list(col = "A", align = "center", bold = TRUE),
    list(col = "B", align = "right",  italic = TRUE)
  )
)
report_cs <- rtfreport$new()
sec_cs <- report_cs$add_section()
report_cs$add_page(
  section_index = sec_cs,
  content = list(list(type = "table", data = tbl_cs))
)
out_cs <- file.path(tempdir(), "tbl_colspec.rtf")
generate_rtfreport(report_cs, out_cs, overwrite = TRUE)
cs_txt <- paste(readLines(out_cs, warn = FALSE), collapse = "\n")
stopifnot(grepl("\\\\b ", cs_txt))   # bold on
stopifnot(grepl("\\\\i ", cs_txt))   # italic on
stopifnot(grepl("\\\\qr", cs_txt))   # right align for col B

# ============================================================================
# rtftable: col_rel_width produces correct cellx positions
# ============================================================================
tbl_rw <- rtftable$new(
  small_df,
  col_rel_width = c(1, 3),
  table_width_twips = 4000L
)
report_rw <- rtfreport$new()
sec_rw <- report_rw$add_section()
report_rw$add_page(
  section_index = sec_rw,
  content = list(list(type = "table", data = tbl_rw))
)
out_rw <- file.path(tempdir(), "tbl_relwidth.rtf")
generate_rtfreport(report_rw, out_rw, overwrite = TRUE)
rw_txt <- paste(readLines(out_rw, warn = FALSE), collapse = "\n")
# col 1 = round(4000*1/4) = 1000, col 2 cumulative = 4000
stopifnot(grepl("\\\\cellx1000", rw_txt))
stopifnot(grepl("\\\\cellx4000", rw_txt))

# ============================================================================
# rtftable: spanning_header
# ============================================================================
df3 <- data.frame(X = "x", Y = "y", Z = "z", stringsAsFactors = FALSE)
tbl_span <- rtftable$new(
  df3,
  spanning_header = list(
    list(from = 2L, to = 3L, label = "Group YZ", underline = TRUE)
  )
)
report_sp <- rtfreport$new()
sec_sp <- report_sp$add_section()
report_sp$add_page(
  section_index = sec_sp,
  content = list(list(type = "table", data = tbl_span))
)
out_sp <- file.path(tempdir(), "tbl_spanning.rtf")
generate_rtfreport(report_sp, out_sp, overwrite = TRUE)
sp_txt <- paste(readLines(out_sp, warn = FALSE), collapse = "\n")
stopifnot(grepl("Group YZ", sp_txt, fixed = TRUE))
stopifnot(grepl("\\\\ul ", sp_txt))

# ============================================================================
# Text processing: Unicode, superscript, >= token
# ============================================================================
df_text <- data.frame(NOTE = "x>=2 and y^{2}", stringsAsFactors = FALSE)
tbl_text <- rtftable$new(df_text, border = NULL)
report_tx <- rtfreport$new()
sec_tx <- report_tx$add_section()
report_tx$add_page(
  section_index = sec_tx,
  content = list(list(type = "table", data = tbl_text))
)
out_tx <- file.path(tempdir(), "tbl_text.rtf")
generate_rtfreport(report_tx, out_tx, overwrite = TRUE)
tx_txt <- paste(readLines(out_tx, warn = FALSE), collapse = "\n")
stopifnot(grepl("\\u8805?", tx_txt, fixed = TRUE))   # >= converted
stopifnot(grepl("\\super ", tx_txt, fixed = TRUE))   # ^{2} converted

# ============================================================================
# rtftable: manual col_header (pipe string)
# ============================================================================
tbl_hdr <- rtftable$new(
  small_df,
  col_header = "Column A | Column B"
)
report_hdr <- rtfreport$new()
sec_hdr <- report_hdr$add_section()
report_hdr$add_page(
  section_index = sec_hdr,
  content = list(list(type = "table", data = tbl_hdr))
)
out_hdr <- file.path(tempdir(), "tbl_colheader.rtf")
generate_rtfreport(report_hdr, out_hdr, overwrite = TRUE)
hdr_txt <- paste(readLines(out_hdr, warn = FALSE), collapse = "\n")
stopifnot(grepl("Column A", hdr_txt, fixed = TRUE))
stopifnot(grepl("Column B", hdr_txt, fixed = TRUE))

cat("All rtfreporter R tests passed.\n")

# ============================================================================
# rtf_border_side: constructor and validation
# ============================================================================
bs <- rtf_border_side()
stopifnot(inherits(bs, "rtf_border_side"))
stopifnot(bs$style == "single")
stopifnot(bs$width == 15L)
stopifnot(is.null(bs$color))

bs2 <- rtf_border_side("thick", 20L, "#FF0000")
stopifnot(bs2$style == "thick")
stopifnot(bs2$width == 20L)
stopifnot(bs2$color == "#FF0000")

err_bs <- tryCatch(rtf_border_side("zigzag"), error = function(e) e)
stopifnot(inherits(err_bs, "error"))

# ============================================================================
# rtf_border: constructor and convenience variants
# ============================================================================
b_none   <- rtf_border_none()
stopifnot(inherits(b_none, "rtf_border"))
stopifnot(is.null(b_none$top))

b_top  <- rtf_border_top()
stopifnot(!is.null(b_top$top))
stopifnot(is.null(b_top$bottom))

b_box <- rtf_border_box("double", 10L)
stopifnot(!is.null(b_box$top))
stopifnot(!is.null(b_box$bottom))
stopifnot(!is.null(b_box$left))
stopifnot(!is.null(b_box$right))
stopifnot(b_box$top$style == "double")

# ============================================================================
# rtf_table_border and rtf_border_tfl
# ============================================================================
tfl <- rtf_border_tfl()
stopifnot(inherits(tfl, "rtf_table_border"))
stopifnot(!is.null(tfl$header$top))
stopifnot(!is.null(tfl$header$bottom))
stopifnot(!is.null(tfl$last_row$bottom))
stopifnot(is.null(tfl$body))
stopifnot(is.null(tfl$spanning))

# ============================================================================
# rtftable with rtf_table_border object
# ============================================================================
tbl_obj <- rtftable$new(small_df, border = rtf_border_tfl())
stopifnot(inherits(tbl_obj$border, "rtf_table_border"))

# plain-list backward compat still produces rtf_table_border
tbl_lst <- rtftable$new(small_df, border = list(
  header = list(top = "single", bottom = "single", width = 15L),
  last_row = list(bottom = "single")
))
stopifnot(inherits(tbl_lst$border, "rtf_table_border"))

# ============================================================================
# rtf_header / rtf_footer with rtf_border
# ============================================================================
hdr_obj <- rtf_header(c(l = "Test"), border = NULL)
stopifnot(is.null(hdr_obj$border))

ftr_obj <- rtf_footer(c(l = "Test"))   # default border = rtf_border_top()
stopifnot(inherits(ftr_obj$border, "rtf_border"))
stopifnot(!is.null(ftr_obj$border$top))

# Deprecated top_border= should still work with a warning
ftr_dep <- withCallingHandlers(
  rtf_footer(c(l = "X"), top_border = TRUE),
  warning = function(w) { invokeRestart("muffleWarning") }
)
stopifnot(!is.null(ftr_dep$border$top))

# ============================================================================
# Render with rtf_border: footer top border renders as \clbrdrt\brdrs
# ============================================================================
report_br <- rtfreport$new()
sec_br <- report_br$add_section(
  header = c(l = "Header Test"),
  footer = rtf_footer(c(l = "Footer Test"))  # default top border
)
report_br$add_page(
  section_index = sec_br,
  content = list(list(type = "table", data = small_df))
)
out_br <- file.path(tempdir(), "border_render.rtf")
generate_rtfreport(report_br, out_br, overwrite = TRUE)
br_txt <- paste(readLines(out_br, warn = FALSE), collapse = "\n")
stopifnot(grepl("Footer Test", br_txt, fixed = TRUE))
stopifnot(grepl("clbrdrt", br_txt, fixed = TRUE))   # top border rendered

# ============================================================================
# Render with colored border: color table must include the hex color
# ============================================================================
report_col <- rtfreport$new()
sec_col <- report_col$add_section(
  footer = rtf_footer(c(l = "Red Footer"),
                      border = rtf_border_top("single", 15L, "#FF0000"))
)
report_col$add_page(
  section_index = sec_col,
  content = list(list(type = "table", data = small_df))
)
out_col <- file.path(tempdir(), "color_border.rtf")
generate_rtfreport(report_col, out_col, overwrite = TRUE)
col_txt <- paste(readLines(out_col, warn = FALSE), collapse = "\n")
stopifnot(grepl("red255", col_txt, fixed = TRUE))   # #FF0000 in color table
stopifnot(grepl("brdrcf2", col_txt, fixed = TRUE))  # color index 2

cat("All border class tests passed.\n")
