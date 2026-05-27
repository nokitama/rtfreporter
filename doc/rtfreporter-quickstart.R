## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(echo = TRUE, message = FALSE, warning = FALSE,
                      eval = FALSE)
library(rtfreporter)
library(magrittr)

## ----minimal------------------------------------------------------------------
# library(rtfreporter)
# library(magrittr)
# 
# df <- data.frame(
#   Subject = c("001", "002", "003"),
#   Arm     = c("Active", "Placebo", "Active"),
#   Age     = c(34L, 45L, 28L),
#   Sex     = c("M", "F", "M"),
#   stringsAsFactors = FALSE
# )
# 
# doc <- rtf_document() %>%
#   rtf_section(page = 1, secinfo = list(
#     header = rtf_header(rows = list(
#       c(l = "Protocol: RTF-101",         r = "ACME Pharma"),
#       c(l = "Table 14.1.1 Demographics", r = "Page {AUTO_PAGE} of {AUTO_TOTAL_PAGES}")
#     )),
#     footer = rtf_footer(rows = list(
#       c(l = "Source: DM domain.", r = "CONFIDENTIAL")
#     ))
#   )) %>%
#   rtf_tables(list(
#     rtftable(df,
#       col_rel_width    = c(2, 2, 1, 1),
#       row_height_twips = 280L)
#   ))
# 
# generate_rtfreport(doc, tempfile(fileext = ".rtf"), overwrite = TRUE)

## ----shift-table--------------------------------------------------------------
# make_shift_df <- function(a_low, a_norm, a_high, b_low, b_norm, b_high) {
#   data.frame(
#     Baseline = c("Low", "Normal", "High"),
#     A_Low    = a_low,  A_Normal = a_norm,  A_High = a_high,
#     B_Low    = b_low,  B_Normal = b_norm,  B_High = b_high,
#     stringsAsFactors = FALSE, check.names = FALSE
#   )
# }
# 
# lab_data <- list(
#   list(label = "ALT (Alanine Aminotransferase)",
#        df    = make_shift_df(c(4,0,0), c(1,13,1), c(0,2,3),
#                              c(3,0,0), c(1,14,0), c(0,1,4))),
#   list(label = "AST (Aspartate Aminotransferase)",
#        df    = make_shift_df(c(5,0,0), c(0,11,2), c(0,1,5),
#                              c(4,0,0), c(1,12,1), c(0,2,4))),
#   list(label = "HGB (Hemoglobin)",
#        df    = make_shift_df(c(2,1,0), c(1,16,1), c(0,1,2),
#                              c(3,0,0), c(0,15,2), c(0,2,2)))
# )
# 
# spanning_hdr <- list(
#   list(from = 2L, to = 4L, label = "Treatment A  (N=24)", underline = TRUE),
#   list(from = 5L, to = 7L, label = "Treatment B  (N=24)", underline = TRUE)
# )
# col_hdr    <- c("Baseline", "Low", "Normal", "High", "Low", "Normal", "High")
# col_widths <- c(2160L, 900L, 900L, 900L, 900L, 900L, 900L)
# 
# col_spec_shift <- lapply(seq_len(7L), function(j)
#   list(col = j, align = if (j == 1L) "left" else "center"))
# 
# common_footer <- rtf_footer(
#   rows = list(
#     c(l = "ALT=Alanine Aminotransferase; AST=Aspartate Aminotransferase; HGB=Hemoglobin"),
#     c(l = "Low/Normal/High: site reference range categories.", r = "CONFIDENTIAL")
#   )
# )
# 
# # Build document: one section per analyte
# doc <- rtf_document()
# 
# for (i in seq_along(lab_data)) {
#   item <- lab_data[[i]]
# 
#   tbl <- rtftable(
#     data                = item$df,
#     col_header          = col_hdr,
#     spanning_header     = spanning_hdr,
#     col_spec            = col_spec_shift,
#     column_widths_twips = col_widths,
#     border              = "tfl",
#     row_height_twips    = 280L
#   )
# 
#   sec_header <- rtf_header(rows = list(
#     c(l = "Protocol: LAB-001",                             r = "ACME Pharma"),
#     c(l = "Study Title: Phase III Safety Lab Assessment",   r = "Page {AUTO_PAGE} of {AUTO_TOTAL_PAGES}"),
#     c(c = "Table 14.3.1  Laboratory Shift Table (Safety Population)"),
#     c(l = item$label)
#   ))
# 
#   doc <- doc %>%
#     rtf_section(page = i, secinfo = list(header = sec_header, footer = common_footer)) %>%
#     rtf_tables(list(tbl))
# }
# 
# generate_rtfreport(doc, tempfile(fileext = ".rtf"), overwrite = TRUE)

## ----figure-------------------------------------------------------------------
# library(ggplot2)
# 
# p <- ggplot(
#   data.frame(x = 1:10, y = (1:10)^2 + rnorm(10, sd = 3)),
#   aes(x = x, y = y)) +
#   geom_point(size = 3, colour = "#2166AC") +
#   geom_smooth(method = "lm", se = FALSE, colour = "#D6604D") +
#   labs(title = "Lab value vs. Visit (simulated)", x = "Visit", y = "Lab value") +
#   theme_bw(base_size = 11)
# 
# png_path <- tempfile(fileext = ".png")
# ggsave(png_path, plot = p, width = 7, height = 4.5, dpi = 150)
# 
# doc <- rtf_document() %>%
#   rtf_section(page = 1, secinfo = list(
#     header = rtf_header(rows = list(
#       c(l = "Protocol: FIG-001",           r = "ACME Pharma"),
#       c(l = "Figure 14.1.1  Lab Value vs. Visit (Safety Population)")
#     )),
#     footer = rtf_footer(rows = list(c(l = "Source: LB domain.")))
#   )) %>%
#   rtf_tables(list(
#     rtfplot(png_path, width_twips = 9000L)
#   ))
# 
# generate_rtfreport(doc, tempfile(fileext = ".rtf"), overwrite = TRUE)

## ----fig-plus-table-----------------------------------------------------------
# tbl_summary <- rtftable(
#   data.frame(
#     Statistic = c("n", "Mean", "SD"),
#     Value     = c("30", "42.7", "8.4"),
#     stringsAsFactors = FALSE
#   ),
#   table_width_pct  = 40,
#   table_align      = "left",
#   row_height_twips = 280L
# )
# 
# doc <- rtf_document() %>%
#   rtf_section(page = 1, secinfo = list(
#     header = rtf_header(rows = list(
#       c(l = "Protocol: FIG-001", r = "ACME Pharma"),
#       c(l = "Figure and Summary Table")
#     )),
#     footer = rtf_footer(rows = list(c(l = "Source: LB domain.", r = "CONFIDENTIAL")))
#   )) %>%
#   rtf_tables(list(
#     rtfplot(png_path, width_twips = 7200L),  # page 1: figure
#     tbl_summary                              # page 2: summary table
#   ))
# 
# generate_rtfreport(doc, tempfile(fileext = ".rtf"), overwrite = TRUE)

## ----table-sizing-------------------------------------------------------------
# df <- data.frame(A = 1:3, B = letters[1:3], C = c(1.1, 2.2, 3.3))
# 
# tbl_left   <- rtftable(df, table_width_pct = 70)
# tbl_center <- rtftable(df, table_width_twips = 9000L, table_align = "center")
# tbl_right  <- rtftable(df, table_width_twips = 7200L, table_align = "right",
#                         col_rel_width = c(3, 1, 1))
# tbl_full   <- rtftable(df, table_width_pct = 100)

## ----col-widths---------------------------------------------------------------
# tbl_abs <- rtftable(df, column_widths_twips = c(4320L, 2160L, 2160L))
# tbl_rel <- rtftable(df, col_rel_width = c(2, 1, 1), table_width_twips = 10080L)
# 
# w       <- auto_col_widths(df, table_width_twips = 14400L)
# tbl_auto <- rtftable(df, column_widths_twips = w)

## ----hf-layout----------------------------------------------------------------
# # Multi-row header
# sec_header <- rtf_header(rows = list(
#   c(l = "Protocol: RTF-101",     r = "ACME Pharma"),
#   c(l = "Phase III Safety Study", r = "Page {AUTO_PAGE} of {AUTO_TOTAL_PAGES}"),
#   c(c = "Table 14.3.1  Shift Table (Safety Population)"),
#   c(l = "ALT (Alanine Aminotransferase)")
# ))
# 
# # Footer with two rows
# sec_footer <- rtf_footer(rows = list(
#   c(l = "ALT=Alanine Aminotransferase", r = "CONFIDENTIAL"),
#   c(l = "Low/Normal/High: site reference range categories.")
# ))

## ----spanning-----------------------------------------------------------------
# df_shift <- data.frame(
#   Baseline = c("Low", "Normal", "High"),
#   A_Low = c(4L, 0L, 0L), A_Norm = c(1L, 13L, 1L), A_High = c(0L, 2L, 3L),
#   B_Low = c(3L, 0L, 0L), B_Norm = c(1L, 14L, 0L), B_High = c(0L, 1L, 4L)
# )
# 
# tbl_span <- rtftable(
#   data = df_shift,
#   col_header = c("Baseline", "Low", "Normal", "High", "Low", "Normal", "High"),
#   spanning_header = list(
#     list(from = 2L, to = 4L, label = "Treatment A  (N=24)", underline = TRUE),
#     list(from = 5L, to = 7L, label = "Treatment B  (N=24)", underline = TRUE)
#   ),
#   column_widths_twips = c(2160L, 900L, 900L, 900L, 900L, 900L, 900L),
#   col_spec = lapply(seq_len(7L), function(j)
#     list(col = j, align = if (j == 1L) "left" else "center")),
#   border           = "tfl",
#   row_height_twips = 280L
# )

## ----multi-df-----------------------------------------------------------------
# df_a <- data.frame(Label = c("Low", "Normal", "High"), n = c(4L, 13L, 3L))
# df_b <- data.frame(Label = c("Low", "Normal", "High"), n = c(3L, 14L, 4L))
# 
# tbl_multi <- rtftable(
#   data       = list(df_a, df_b),
#   col_header = list(
#     c("Baseline", "Arm A"),
#     c("Baseline", "Arm B")
#   ),
#   column_widths_twips = c(3600L, 2160L),
#   border              = "tfl",
#   row_height_twips    = 280L
# )

## ----borders------------------------------------------------------------------
# tbl_tfl <- rtftable(df, border = "tfl")
# 
# tbl_custom <- rtftable(df,
#   border = rtf_table_border(
#     header   = rtf_border(top = rtf_border_side(), bottom = rtf_border_side()),
#     last_row = rtf_border(bottom = rtf_border_side("double", 10L))
#   )
# )
# 
# hdr_bordered <- rtf_header(
#   rows   = list(c(c = "Study Title")),
#   border = rtf_border(bottom = rtf_border_side("single"))
# )

## ----assemble-----------------------------------------------------------------
# make_rtf <- function(df, hdr_text, path) {
#   doc <- rtf_document() %>%
#     rtf_section(page = 1, secinfo = list(
#       header = rtf_header(rows = list(
#         c(l = hdr_text, r = "Page {AUTO_PAGE} of {AUTO_TOTAL_PAGES}")
#       )),
#       footer = rtf_footer(rows = list(c(l = "CONFIDENTIAL")))
#     )) %>%
#     rtf_tables(list(df))
#   generate_rtfreport(doc, path, overwrite = TRUE)
# }
# 
# f1 <- tempfile(fileext = ".rtf"); make_rtf(mtcars[1:3, ], "Table 14.1 DM", f1)
# f2 <- tempfile(fileext = ".rtf"); make_rtf(mtcars[4:6, ], "Table 14.2 AE", f2)
# 
# assembled <- tempfile(fileext = ".rtf")
# assemble_rtf(c(f1, f2), assembled, overwrite = TRUE)

## ----auto-widths--------------------------------------------------------------
# df_ae <- data.frame(
#   USUBJID  = c("001-001", "001-002"),
#   AETERM   = c("Headache", "Nausea"),
#   AESTDTC  = c("2024-01-15", "2024-02-03"),
#   AESER    = c("N", "N"),
#   stringsAsFactors = FALSE
# )
# 
# w <- auto_col_widths(df_ae,
#   col_header        = "Subject ID | AE Term | Start Date | Serious",
#   table_width_twips = 14400L)
# 
# tbl_ae <- rtftable(df_ae,
#   col_header          = c("Subject ID", "AE Term", "Start Date", "Serious"),
#   column_widths_twips = w,
#   border              = "tfl",
#   row_height_twips    = 280L)

## ----blank-rows---------------------------------------------------------------
# df_demog <- data.frame(
#   Group    = c("Sex",    "Sex",     "Sex",
#                 "Race",   "Race",    "Race",
#                 "Total"),
#   Category = c("Male",   "Female",  "Subtotal",
#                 "Asian",  "Other",   "Subtotal",
#                 ""),
#   N        = c(45L, 35L, 80L, 40L, 40L, 80L, 80L),
#   stringsAsFactors = FALSE
# )
# 
# # Mode 1: integer positions (-1 = after the last row)
# tbl1 <- rtftable(df_demog, blank_rows = c(0, 3, 6, -1))
# 
# # Mode 2: blank when a variable's value changes
# tbl2 <- rtftable(df_demog,
#   blank_rows = blank_rows_by_change("Group",
#     include_before_first = FALSE, include_after_last = FALSE))
# 
# # Mode 3: regex match (e.g. before every "Total" row)
# tbl3 <- rtftable(df_demog,
#   blank_rows = blank_rows_by_rule("Group", "^Total", where = "before"))
# 
# # Combination — positions are unioned
# tbl4 <- rtftable(df_demog,
#   blank_rows = list(
#     c(-1),
#     blank_rows_by_change("Group",
#       include_before_first = FALSE, include_after_last = FALSE),
#     blank_rows_by_rule("Category", "^Subtotal", where = "after")
#   ))
# 
# # Or attach an attribute to the data frame and let read_attributes pick it up
# attr(df_demog, "rtf_blank_rows") <- c(0, 3, 6, -1)
# tbl5 <- rtftable(df_demog)   # read_attributes = TRUE by default

## ----titles-footnotes---------------------------------------------------------
# doc <- rtf_document() %>%
#   rtf_tables(
#     list(df_demog, df_demog),
#     titles = list(
#       c("Table 14.1.1", "", "Demographics (Safety Population)"),
#       c("Table 14.1.2", "", "Demographics by Region")
#     ),
#     footnotes = list(
#       c("Source: ADSL.", "", "N = 160 subjects."),
#       NULL
#     ),
#     border           = "tfl",
#     row_height_twips = 280L
#   )
# 
# # Or set them after content has been added
# doc <- rtf_document() %>%
#   rtf_tables(list(df_demog, df_demog)) %>%
#   rtf_titles(list("Page One", "Page Two")) %>%
#   rtf_footnotes(list(NULL, "Source: ADSL."))

## ----style-theme--------------------------------------------------------------
# tfl <- rtf_table_style_tfl()   # built-in TFL preset
# 
# # Hand the same record to many tables
# tables <- lapply(list(df_demog, df_demog, df_demog),
#                   function(df) rtftable(df, style = tfl, row_height_twips = 280L))
# 
# # Non-mutating derivation
# heavy_tfl <- rtf_table_style_with(tfl,
#   border_last_row = rtf_border(bottom = rtf_border_side("double", 20L))
# )

