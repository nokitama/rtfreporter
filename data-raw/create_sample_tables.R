# =============================================================================
# Sample pre-formatted data.frames for rtfreporter examples
#
# Purpose : Create ready-to-use data.frames that simulate the output of a
#           statistical analysis step (cards/tfrmt/manual).  No raw ADaM
#           data or pharma packages required.
#
# Output  : inst/extdata/
#             demog_p1.rds   – Demographics page 1  (25 rows)
#             demog_p2.rds   – Demographics page 2  (19 rows)
#             lab_hgb.rds    – Shift table: Hemoglobin
#             lab_alt.rds    – Shift table: ALT
#             lab_creat.rds  – Shift table: Creatinine
#
# Run once from repo root:  source("data-raw/create_sample_tables.R")
# =============================================================================

out_dir <- file.path("inst", "extdata")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# ── Helper: format n (%) ──────────────────────────────────────────────────────
np <- function(n, N) {
  if (n == 0L) return("0")
  sprintf("%d (%.1f%%)", n, 100 * n / N)
}
# Helper: mean (SD) string
msd <- function(m, s) sprintf("%.1f (%.2f)", m, s)
# Helper: "x, y" pair
pair <- function(x, y) sprintf("%.1f, %.1f", x, y)

# =============================================================================
# 1. DEMOGRAPHICS  (N = 60: Drug A n=30, Drug B n=30)
# =============================================================================
NA30 <- 30L; NB30 <- 30L; NT60 <- 60L

# Single-row helper
row <- function(lbl, a, b, tot) {
  data.frame(Label = lbl, `Drug A` = a, `Drug B` = b, Total = tot,
             check.names = FALSE, stringsAsFactors = FALSE)
}
hdr <- function(lbl) row(lbl, "", "", "")  # header row (blank values)

# ── Page 1: Age Group / Age / Sex / Race / Ethnicity / Weight Group ───────────
demog_p1 <- rbind(
  hdr("Age Group, n (%)"),
  row("  <65",    np(10,NA30), np(12,NB30), np(22,NT60)),
  row("  65-<75", np(14,NA30), np(12,NB30), np(26,NT60)),
  row("  >=75",   np( 6,NA30), np( 6,NB30), np(12,NT60)),

  hdr("Age (years)"),
  row("  N",         "30",             "30",             "60"),
  row("  Mean (SD)", msd(63.2,9.14),   msd(67.0,8.31),   msd(65.1,8.85)),
  row("  Median",    "64.0",           "67.5",           "66.0"),
  row("  Q1, Q3",    pair(57.0,70.0),  pair(61.5,73.5),  pair(59.5,71.5)),
  row("  Min, Max",  "43, 79",         "48, 85",         "43, 85"),

  hdr("Sex, n (%)"),
  row("  Male",   np(17,NA30), np(16,NB30), np(33,NT60)),
  row("  Female", np(13,NA30), np(14,NB30), np(27,NT60)),

  hdr("Race, n (%)"),
  row("  White",                       np(19,NA30), np(20,NB30), np(39,NT60)),
  row("  Black or African American",   np( 5,NA30), np( 4,NB30), np( 9,NT60)),
  row("  Asian",                       np( 4,NA30), np( 5,NB30), np( 9,NT60)),
  row("  Other",                       np( 2,NA30), np( 1,NB30), np( 3,NT60)),

  hdr("Ethnicity, n (%)"),
  row("  Hispanic or Latino",     np( 6,NA30), np( 6,NB30), np(12,NT60)),
  row("  Not Hispanic or Latino", np(24,NA30), np(24,NB30), np(48,NT60)),

  hdr("Weight Group (kg), n (%)"),
  row("  <60 kg",    np( 4,NA30), np( 3,NB30), np( 7,NT60)),
  row("  60-<80 kg", np(17,NA30), np(18,NB30), np(35,NT60)),
  row("  >=80 kg",   np( 9,NA30), np( 9,NB30), np(18,NT60))
)
rownames(demog_p1) <- NULL

# ── Page 2: Weight / BMI Group / BMI / Prior Treatment ───────────────────────
demog_p2 <- rbind(
  hdr("Weight (kg)"),
  row("  N",         "30",             "30",             "60"),
  row("  Mean (SD)", msd(74.8,12.08),  msd(75.2,11.83),  msd(75.0,11.93)),
  row("  Median",    "74.5",           "75.0",           "74.8"),
  row("  Q1, Q3",    pair(66.0,83.0),  pair(67.0,83.5),  pair(66.5,83.0)),
  row("  Min, Max",  "51.2, 98.7",     "52.3, 97.1",     "51.2, 98.7"),

  hdr("BMI Group (kg/m^{2}), n (%)"),
  row("  <25",    np( 8,NA30), np( 9,NB30), np(17,NT60)),
  row("  25-<30", np(13,NA30), np(12,NB30), np(25,NT60)),
  row("  >=30",   np( 9,NA30), np( 9,NB30), np(18,NT60)),

  hdr("BMI (kg/m^{2})"),
  row("  N",         "30",            "30",            "60"),
  row("  Mean (SD)", msd(26.5,4.21),  msd(26.7,3.97),  msd(26.6,4.08)),
  row("  Median",    "26.1",          "26.4",          "26.2"),
  row("  Q1, Q3",    pair(23.1,29.5), pair(23.5,29.8), pair(23.3,29.6)),
  row("  Min, Max",  "19.2, 36.8",   "19.8, 37.2",    "19.2, 37.2"),

  hdr("Prior Treatment, n (%)"),
  row("  Yes", np(12,NA30), np(12,NB30), np(24,NT60)),
  row("  No",  np(18,NA30), np(18,NB30), np(36,NT60))
)
rownames(demog_p2) <- NULL

cat(sprintf("demog_p1: %d rows\ndemog_p2: %d rows\n",
            nrow(demog_p1), nrow(demog_p2)))

saveRDS(demog_p1, file.path(out_dir, "demog_p1.rds"))
saveRDS(demog_p2, file.path(out_dir, "demog_p2.rds"))


# =============================================================================
# 2. LAB TOXICITY GRADE SHIFT TABLE
#    Rows: Baseline Grade 0-4 + Total (6 rows)
#    Cols: BL_Grade | [DrugA G0..G4 Tot] | [DrugB G0..G4 Tot] | [Total G0..G4 Tot]
#
#    Cell format: "n\n(x.x%)"   (two-line: count on top, pct below)
# =============================================================================

# Cell formatter for shift table
sc <- function(n, N) {
  if (n == 0L) return("0")
  sprintf("%d\n(%.1f%%)", n, 100 * n / N)
}

# make_shift_df: given a matrix of counts [BL_grade(0-4+tot), PostBL_grade(0-4+tot)]
# for Drug A and Drug B, return a 6 x 19 data.frame
#
# count_A / count_B: 6x6 integer matrix
#   rows 1-5 = BL grade 0-4, row 6 = Total
#   cols 1-5 = Post-BL grade 0-4, col 6 = Total
make_shift_df <- function(count_A, count_B) {
  NA30 <- 30L; NB30 <- 30L; NT60 <- 60L
  count_T <- count_A + count_B

  bl_labels <- c("0", "1", "2", "3", "4", "Total")

  make_cols <- function(mat, N) {
    out <- matrix("", nrow = 6L, ncol = 6L)
    for (i in 1:6) for (j in 1:6) out[i, j] <- sc(mat[i, j], N)
    out
  }

  cols_A <- make_cols(count_A, NA30)
  cols_B <- make_cols(count_B, NB30)
  cols_T <- make_cols(count_T, NT60)

  col_nms <- function(prefix) {
    c(paste0(prefix, "_G", 0:4), paste0(prefix, "_Tot"))
  }

  df <- as.data.frame(
    cbind(cols_A, cols_B, cols_T),
    stringsAsFactors = FALSE
  )
  colnames(df) <- c(col_nms("DrugA"), col_nms("DrugB"), col_nms("Total"))
  df <- cbind(data.frame(BL_Grade = bl_labels, stringsAsFactors = FALSE), df)
  df
}

# ── RBC (Red Blood Cell Count): mild reductions ──────────────────────────────
cA_rbc <- matrix(0L, 6L, 6L)
cA_rbc[1, ] <- c(14L,  6L,  3L,  2L,  0L, 25L)  # BL=0
cA_rbc[2, ] <- c( 1L,  2L,  1L,  1L,  0L,  5L)  # BL=1
cA_rbc[3, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cA_rbc[4, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cA_rbc[5, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cA_rbc[6, ] <- c(15L,  8L,  4L,  3L,  0L, 30L)  # Total

cB_rbc <- matrix(0L, 6L, 6L)
cB_rbc[1, ] <- c(16L,  5L,  3L,  2L,  0L, 26L)
cB_rbc[2, ] <- c( 1L,  2L,  1L,  0L,  0L,  4L)
cB_rbc[3, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cB_rbc[4, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cB_rbc[5, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cB_rbc[6, ] <- c(17L,  7L,  4L,  2L,  0L, 30L)

lab_rbc <- make_shift_df(cA_rbc, cB_rbc)

# ── WBC (White Blood Cell Count): leukocytopenia pattern ─────────────────────
cA_wbc <- matrix(0L, 6L, 6L)
cA_wbc[1, ] <- c(12L,  7L,  4L,  2L,  0L, 25L)  # BL=0
cA_wbc[2, ] <- c( 1L,  2L,  1L,  1L,  0L,  5L)  # BL=1
cA_wbc[3, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cA_wbc[4, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cA_wbc[5, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cA_wbc[6, ] <- c(13L,  9L,  5L,  3L,  0L, 30L)  # Total

cB_wbc <- matrix(0L, 6L, 6L)
cB_wbc[1, ] <- c(15L,  5L,  4L,  2L,  0L, 26L)
cB_wbc[2, ] <- c( 0L,  2L,  1L,  1L,  0L,  4L)
cB_wbc[3, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cB_wbc[4, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cB_wbc[5, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cB_wbc[6, ] <- c(15L,  7L,  5L,  3L,  0L, 30L)

lab_wbc <- make_shift_df(cA_wbc, cB_wbc)

# ── HGB (Hemoglobin): mild hematological changes ─────────────────────────────
# Drug A: BL Grade 0 (n=25), BL Grade 1 (n=5)
cA_hgb <- matrix(0L, 6L, 6L)
cA_hgb[1, ] <- c(15L,  7L,  2L,  1L,  0L, 25L)  # BL=0 → post
cA_hgb[2, ] <- c( 1L,  2L,  1L,  1L,  0L,  5L)  # BL=1 → post
cA_hgb[3, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cA_hgb[4, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cA_hgb[5, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cA_hgb[6, ] <- c(16L,  9L,  3L,  2L,  0L, 30L)  # Total

cB_hgb <- matrix(0L, 6L, 6L)
cB_hgb[1, ] <- c(18L,  5L,  2L,  1L,  0L, 26L)
cB_hgb[2, ] <- c( 1L,  2L,  0L,  1L,  0L,  4L)
cB_hgb[3, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cB_hgb[4, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cB_hgb[5, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cB_hgb[6, ] <- c(19L,  7L,  2L,  2L,  0L, 30L)

lab_hgb <- make_shift_df(cA_hgb, cB_hgb)

# ── ALT: hepatic enzyme – more Grade 1-2 elevations ──────────────────────────
cA_alt <- matrix(0L, 6L, 6L)
cA_alt[1, ] <- c(14L,  7L,  3L,  1L,  0L, 25L)  # BL=0
cA_alt[2, ] <- c( 1L,  2L,  1L,  1L,  0L,  5L)  # BL=1
cA_alt[3, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cA_alt[4, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cA_alt[5, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cA_alt[6, ] <- c(15L,  9L,  4L,  2L,  0L, 30L)

cB_alt <- matrix(0L, 6L, 6L)
cB_alt[1, ] <- c(17L,  5L,  2L,  2L,  0L, 26L)
cB_alt[2, ] <- c( 0L,  2L,  1L,  1L,  0L,  4L)
cB_alt[3, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cB_alt[4, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cB_alt[5, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cB_alt[6, ] <- c(17L,  7L,  3L,  3L,  0L, 30L)

lab_alt <- make_shift_df(cA_alt, cB_alt)

# ── Creatinine: renal function – mostly stable ────────────────────────────────
cA_creat <- matrix(0L, 6L, 6L)
cA_creat[1, ] <- c(18L,  5L,  1L,  1L,  0L, 25L)
cA_creat[2, ] <- c( 2L,  2L,  1L,  0L,  0L,  5L)
cA_creat[3, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cA_creat[4, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cA_creat[5, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cA_creat[6, ] <- c(20L,  7L,  2L,  1L,  0L, 30L)

cB_creat <- matrix(0L, 6L, 6L)
cB_creat[1, ] <- c(19L,  5L,  1L,  1L,  0L, 26L)
cB_creat[2, ] <- c( 1L,  2L,  1L,  0L,  0L,  4L)
cB_creat[3, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cB_creat[4, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cB_creat[5, ] <- c( 0L,  0L,  0L,  0L,  0L,  0L)
cB_creat[6, ] <- c(20L,  7L,  2L,  1L,  0L, 30L)

lab_creat <- make_shift_df(cA_creat, cB_creat)

cat(sprintf("Lab shift table: %d rows x %d cols\n", nrow(lab_hgb), ncol(lab_hgb)))
print(lab_hgb)

saveRDS(lab_rbc,   file.path(out_dir, "lab_rbc.rds"))
saveRDS(lab_wbc,   file.path(out_dir, "lab_wbc.rds"))
saveRDS(lab_hgb,   file.path(out_dir, "lab_hgb.rds"))
saveRDS(lab_alt,   file.path(out_dir, "lab_alt.rds"))
saveRDS(lab_creat, file.path(out_dir, "lab_creat.rds"))

cat("\nAll sample tables saved to", out_dir, "\n")
