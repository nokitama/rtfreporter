## ============================================================================
##  Generate a realistic multi-page TFL deliverable using assemble_rtf().
##  Includes:
##    * 3 source RTFs, each with multiple pages
##    * Both static {TOTAL_PAGES} and dynamic {AUTO_PAGE} pageno styles
##    * Final assembled file with cover + multi-level TOC + Roman pages
##    * Headless PDF conversion via LibreOffice (if soffice.exe is available)
## ============================================================================

suppressMessages(suppressWarnings(devtools::load_all(quiet = TRUE)))

out_dir <- normalizePath("output/demo", mustWork = FALSE)
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

## ── Headers / footers (mix the two pageno styles deliberately) ────────────
hdr_auto <- rtf_header(rows = list(
  c(l = "Protocol XYZ-001", r = "Page {AUTO_PAGE} of {AUTO_TOTAL_PAGES}"),
  c(l = "Confidential",     r = "ACME Pharma")
))
hdr_static <- rtf_header(rows = list(
  c(l = "Protocol XYZ-001", r = "Page {PAGE} of {TOTAL_PAGES}"),
  c(l = "Confidential",     r = "ACME Pharma")
))
ftr <- rtf_footer(c(c = "Source: ADaM ADSL"))

## ──────────────────────────────────────────────────────────────────────────
##  Source 1: Demographics by Treatment (3 pages, AUTO pageno)
## ──────────────────────────────────────────────────────────────────────────
mk_demog <- function(label) {
  data.frame(
    Characteristic = c(
      label,
      "  Age, mean (SD)", "  Age, median (Q1, Q3)", "  Age, min - max",
      "  Sex, n (%)", "    Female", "    Male",
      "  Race, n (%)", "    White", "    Black or African American",
      "    Asian", "    Other",
      "  BMI, mean (SD)"
    ),
    Placebo  = c("", "52.3 (12.1)", "51 (44, 60)",   "21 - 79",
                  "", "16 (53.3)", "14 (46.7)",
                  "", "24 (80.0)", "3 (10.0)", "2 ( 6.7)", "1 ( 3.3)",
                  "27.4 (4.1)"),
    Active   = c("", "54.1 (11.7)", "53 (45, 62)",   "24 - 78",
                  "", "14 (46.7)", "16 (53.3)",
                  "", "23 (76.7)", "4 (13.3)", "2 ( 6.7)", "1 ( 3.3)",
                  "27.8 (3.9)"),
    Total    = c("", "53.2 (11.9)", "52 (45, 61)",   "21 - 79",
                  "", "30 (50.0)", "30 (50.0)",
                  "", "47 (78.3)", "7 (11.7)", "4 ( 6.7)", "2 ( 3.3)",
                  "27.6 (4.0)"),
    stringsAsFactors = FALSE
  )
}
demo_pages <- list(
  mk_demog("Overall Population"),
  mk_demog("By Age <= 65 years"),
  mk_demog("By Age >  65 years")
)
titles_demog <- list(
  c("Table 14.1.1", "Demographics and Baseline Characteristics",
    "Safety Population - All Subjects"),
  c("Table 14.1.1 (continued)", "Demographics and Baseline Characteristics",
    "Safety Population - Age <= 65"),
  c("Table 14.1.1 (continued)", "Demographics and Baseline Characteristics",
    "Safety Population - Age >  65")
)
doc1 <- rtf_document() |>
  rtf_section(page = 1, secinfo = list(header = hdr_auto, footer = ftr)) |>
  rtf_tables(demo_pages, titles = titles_demog,
             footnotes = list(
               "Percentages based on column N.  BMI = Body Mass Index.",
               "Subjects aged 65 or younger at randomisation.",
               "Subjects aged over 65 at randomisation."))
f1 <- file.path(out_dir, "t14_1_1_demographics.rtf")
generate_rtfreport(doc1, f1, overwrite = TRUE)

## ──────────────────────────────────────────────────────────────────────────
##  Source 2: Adverse Events (4 pages by SOC, AUTO pageno)
## ──────────────────────────────────────────────────────────────────────────
mk_ae <- function(rows) {
  data.frame(
    SOC_PT     = rows$pt,
    Placebo_n  = rows$pbo,
    Active_n   = rows$act,
    Total_n    = rows$tot,
    stringsAsFactors = FALSE
  )
}
ae_pages <- list(
  mk_ae(list(
    pt  = c("ALL ADVERSE EVENTS",
            "  Subjects with at least one AE",
            "  Subjects with at least one Serious AE",
            "  Subjects discontinued due to AE"),
    pbo = c("",          "18 (60.0)", " 2 ( 6.7)", " 1 ( 3.3)"),
    act = c("",          "22 (73.3)", " 4 (13.3)", " 2 ( 6.7)"),
    tot = c("",          "40 (66.7)", " 6 (10.0)", " 3 ( 5.0)"))),
  mk_ae(list(
    pt  = c("Nervous system disorders",
            "  Headache", "  Dizziness", "  Insomnia"),
    pbo = c("", "10 (33.3)", " 2 ( 6.7)", " 3 (10.0)"),
    act = c("", "13 (43.3)", " 2 ( 6.7)", " 4 (13.3)"),
    tot = c("", "23 (38.3)", " 4 ( 6.7)", " 7 (11.7)"))),
  mk_ae(list(
    pt  = c("Gastrointestinal disorders",
            "  Nausea", "  Diarrhoea", "  Abdominal pain"),
    pbo = c("", " 6 (20.0)", " 4 (13.3)", " 2 ( 6.7)"),
    act = c("", " 7 (23.3)", " 5 (16.7)", " 3 (10.0)"),
    tot = c("", "13 (21.7)", " 9 (15.0)", " 5 ( 8.3)"))),
  mk_ae(list(
    pt  = c("Investigations",
            "  Blood pressure increased", "  ALT increased",
            "  Weight decreased"),
    pbo = c("", " 1 ( 3.3)", " 2 ( 6.7)", " 0       "),
    act = c("", " 2 ( 6.7)", " 3 (10.0)", " 1 ( 3.3)"),
    tot = c("", " 3 ( 5.0)", " 5 ( 8.3)", " 1 ( 1.7)")))
)
titles_ae <- list(
  c("Table 14.2.1", "Adverse Events Summary", "Safety Population"),
  c("Table 14.2.2", "Adverse Events by SOC and PT (Nervous System)",
    "Safety Population"),
  c("Table 14.2.3", "Adverse Events by SOC and PT (GI)",
    "Safety Population"),
  c("Table 14.2.4", "Adverse Events by SOC and PT (Investigations)",
    "Safety Population")
)
ae_footnote <- list(rep("Percentages based on safety population N=30 per arm.", 4))[[1]]
doc2 <- rtf_document() |>
  rtf_section(page = 1, secinfo = list(header = hdr_auto, footer = ftr)) |>
  rtf_tables(ae_pages, titles = titles_ae,
             footnotes = lapply(ae_footnote, identity))
f2 <- file.path(out_dir, "t14_2_x_ae.rtf")
generate_rtfreport(doc2, f2, overwrite = TRUE)

## ──────────────────────────────────────────────────────────────────────────
##  Source 3: Subject Disposition Listing (3 pages, STATIC pageno -- so we
##  also exercise the {PAGE} / {TOTAL_PAGES} (static) code path).
## ──────────────────────────────────────────────────────────────────────────
mk_listing <- function(idx_start, n = 12) {
  ids <- sprintf("XYZ-%03d", seq(idx_start, idx_start + n - 1L))
  data.frame(
    USUBJID  = ids,
    Status   = sample(c("Completed", "Withdrawn", "Discontinued"),
                       n, replace = TRUE, prob = c(0.7, 0.2, 0.1)),
    Reason   = sample(c("", "Adverse event", "Lost to follow-up",
                        "Withdrew consent", "Protocol deviation"),
                       n, replace = TRUE,
                       prob = c(0.6, 0.1, 0.1, 0.1, 0.1)),
    EndDate  = format(seq.Date(as.Date("2026-01-15"), by = "day",
                                length.out = n), "%Y-%m-%d"),
    stringsAsFactors = FALSE
  )
}
set.seed(42)
list_pages <- list(mk_listing(1L), mk_listing(13L), mk_listing(25L))
titles_list <- list(
  c("Listing 16.1", "Subject Disposition", "All Randomized - Page 1 of 3"),
  c("Listing 16.1 (continued)", "Subject Disposition",
    "All Randomized - Page 2 of 3"),
  c("Listing 16.1 (continued)", "Subject Disposition",
    "All Randomized - Page 3 of 3")
)
doc3 <- rtf_document() |>
  rtf_section(page = 1, secinfo = list(header = hdr_static, footer = ftr)) |>
  rtf_tables(list_pages, titles = titles_list)
f3 <- file.path(out_dir, "l16_1_disposition.rtf")
generate_rtfreport(doc3, f3, overwrite = TRUE)

## ──────────────────────────────────────────────────────────────────────────
##  Assemble: cover + multi-level TOC + Roman pages
## ──────────────────────────────────────────────────────────────────────────
final <- file.path(out_dir, "assembled_full_deliverable.rtf")
assemble_rtf(
  input_files = c(f1, f2, f3),
  output_file = final,
  cover = list(
    title    = "Study XYZ-001",
    subtitle = "Final Statistical Report - TFL Package",
    date     = format(Sys.Date(), "%d %B %Y"),
    version  = "v1.0",
    meta     = c("Confidential - For Sponsor Use Only",
                 "Prepared by ACME Pharma Biostatistics")
  ),
  toc = list(
    toc_heading("EFFICACY ANALYSES",          level = 1),
    toc_entry  ("Table 14.1.1 Demographics and Baseline Characteristics",
                file = f1, level = 2),
    toc_heading("SAFETY ANALYSES",            level = 1),
    toc_entry  ("Table 14.2.1 Adverse Events Summary",
                file = f2, level = 2),
    toc_heading("LISTINGS",                   level = 1),
    toc_entry  ("Listing 16.1 Subject Disposition",
                file = f3, level = 2)
  ),
  toc_title          = "Table of Contents",
  toc_leader         = "dot",
  toc_page_numbering = "roman",
  overwrite          = TRUE
)

## ──────────────────────────────────────────────────────────────────────────
##  Headless PDF conversion via LibreOffice (if available).
## ──────────────────────────────────────────────────────────────────────────
soffice_candidates <- c(
  "C:/Program Files/LibreOffice/program/soffice.exe",
  "C:/Program Files (x86)/LibreOffice/program/soffice.exe"
)
soffice <- Filter(file.exists, soffice_candidates)[1L]
final_pdf <- sub("\\.rtf$", ".pdf", final)

if (length(soffice) && !is.na(soffice)) {
  cat("\nConverting to PDF via LibreOffice...\n")
  # Delete stale output so we know if conversion truly ran
  if (file.exists(final_pdf)) unlink(final_pdf)
  res <- system2(
    soffice,
    args = c("--headless", "--convert-to", "pdf:writer_pdf_Export",
             "--outdir", shQuote(out_dir), shQuote(final)),
    stdout = TRUE, stderr = TRUE
  )
  if (file.exists(final_pdf)) {
    cat("PDF generated:\n  ", final_pdf, "\n",
        sprintf("  (%d bytes)\n", file.info(final_pdf)$size), sep = "")
  } else {
    cat("PDF conversion FAILED.  Tool output:\n")
    cat(paste(res, collapse = "\n"), "\n")
  }
} else {
  cat("\nLibreOffice not found; skipping PDF conversion.\n")
}

cat("\n===\nFolder:", out_dir, "\n")
cat("Final assembled RTF:\n  ", final,
    sprintf("  (%d bytes)\n", file.info(final)$size), sep = "")
