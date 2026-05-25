library(rtfreporter)

data_dir <- system.file("extdata", package = "rtfreporter")
demog_p1 <- readRDS(file.path(data_dir, "demog_p1.rds"))
demog_p2 <- readRDS(file.path(data_dir, "demog_p2.rds"))

col_widths <- c(4320L, 3360L, 3360L, 3360L)
col_hdr    <- c("Characteristic", "Drug A (N=30)", "Drug B (N=30)", "Total (N=60)")

make_tbl <- function(df) rtftable(
  df, col_header = col_hdr, column_widths_twips = col_widths,
  col_spec = list(list(col=1, align="left"), list(col=2, align="center"),
                  list(col=3, align="center"), list(col=4, align="center")),
  row_height_twips = 240L, border = "tfl")

hdr <- rtf_header(rows = list(
  c(l = "Protocol: STUDY001", r = "Company"),
  c(l = "Table 14.1.1  Demographics", r = "Page {AUTO_PAGE} of {AUTO_TOTAL_PAGES}")
))
ftr <- rtf_footer(rows = list(c(l = "CONFIDENTIAL", r = "DRAFT")))

page_cfg <- list(orientation = "landscape", width_in = 11, height_in = 8.5,
                 margin_top_in = 0.75, margin_bottom_in = 0.75,
                 margin_left_in = 0.5, margin_right_in = 0.5)

doc <- rtf_document() |>
  rtf_config(page = page_cfg) |>
  rtf_tables(list(make_tbl(demog_p1))) |>     # page 1
  rtf_tables(list(make_tbl(demog_p2))) |>     # page 2
  rtf_section(page = 1:2,
              secinfo = list(header = hdr, footer = ftr))

out <- tempfile(fileext = ".rtf")
generate_rtfreport(doc, out, overwrite = TRUE)
cat("Demog RTF OK:", out, "\n")
cat("Size:", file.info(out)[["size"]], "bytes\n")
