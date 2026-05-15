# =============================================================================
# multisection_demo.R  —  複数セクション・複数ページ デモ (Lab Chemistry Report)
#
# 構成:
#   Section 1 (Hemoglobin):         2 ページ
#   Section 2 (White Blood Cells):  1 ページ
#   Section 3 (Platelets):          2 ページ
#   → 合計 5 ページ。
#
# 確認ポイント:
#   - ページ番号が RTF 動的フィールド \chpgn で 1/5 ～ 5/5 に表示される
#   - セクション毎に Lab テスト名がヘッダー最下行に左揃えで入る
#   - Lab テスト名の前に空白行（スペーサー）が自動挿入される
#   - スポンサー・試験番号行は全セクション共通
#
# 実行方法:
#   cd C:\Yrepo\rtfreporter\r\rtfreporter
#   Rscript tests/multisection_demo.R
#
# 出力: tests/output/multisection_demo.rtf
# =============================================================================

source(file.path("R", "rtfreport.R"))
source(file.path("R", "rtftable.R"))
source(file.path("R", "rtfplot.R"))
source(file.path("R", "generate_rtfreport.R"))

OUT_DIR <- file.path("tests", "output")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ── ヘルパー: Lab 結果テーブル生成 ──────────────────────────────────────────
make_lab_tbl <- function(df) {
  rtftable$new(
    df,
    col_spec = c(
      list(list(col = 1L, align = "left")),
      lapply(seq(2L, ncol(df)), function(j) list(col = j, align = "right"))
    ),
    col_rel_width = c(4L, rep(2L, ncol(df) - 1L)),
    border = "tfl",
    row_height_twips = 280L,
    header_row_height_twips = 320L,
    cell_padding_left_twips  = 108L,
    cell_padding_right_twips = 108L
  )
}

# ── Section 1: Hemoglobin —————————————————————————————————————————————————————
hgb_p1 <- data.frame(
  Parameter    = c("Baseline", "    n", "    Mean (SD)", "    Median", "    Min, Max",
                   "Week 4",   "    n", "    Mean (SD)", "    Median", "    Min, Max"),
  `TRT A (N=15)` = c("", "15", "13.8 (1.2)", "14.0", "11.2, 16.1",
                     "", "15", "14.1 (1.1)", "14.2", "11.8, 16.4"),
  `TRT B (N=15)` = c("", "15", "13.5 (1.4)", "13.6", "10.8, 15.9",
                     "", "15", "13.3 (1.3)", "13.4", "11.0, 15.6"),
  check.names = FALSE, stringsAsFactors = FALSE
)
hgb_p2 <- data.frame(
  Parameter    = c("Week 8",   "    n", "    Mean (SD)", "    Median", "    Min, Max",
                   "Week 12",  "    n", "    Mean (SD)", "    Median", "    Min, Max"),
  `TRT A (N=15)` = c("", "14", "14.4 (1.0)", "14.5", "12.1, 16.6",
                     "", "14", "14.7 (0.9)", "14.8", "12.5, 16.9"),
  `TRT B (N=15)` = c("", "14", "13.0 (1.5)", "13.1", "10.5, 15.3",
                     "", "13", "12.8 (1.6)", "12.9", "10.2, 15.0"),
  check.names = FALSE, stringsAsFactors = FALSE
)

# ── Section 2: White Blood Cells ─────────────────────────────────────────────
wbc_p1 <- data.frame(
  Parameter    = c("Baseline", "    n", "    Mean (SD)", "    Median", "    Min, Max",
                   "Week 12",  "    n", "    Mean (SD)", "    Median", "    Min, Max"),
  `TRT A (N=15)` = c("", "15", "6.2 (1.8)", "6.0", "3.5, 10.1",
                     "", "14", "6.5 (1.9)", "6.3", "3.8, 10.5"),
  `TRT B (N=15)` = c("", "15", "6.0 (1.6)", "5.9", "3.2, 9.8",
                     "", "13", "5.8 (1.7)", "5.7", "3.0, 9.5"),
  check.names = FALSE, stringsAsFactors = FALSE
)

# ── Section 3: Platelets ─────────────────────────────────────────────────────
plt_p1 <- data.frame(
  Parameter    = c("Baseline", "    n", "    Mean (SD)", "    Median", "    Min, Max",
                   "Week 4",   "    n", "    Mean (SD)", "    Median", "    Min, Max"),
  `TRT A (N=15)` = c("", "15", "238 (45)",  "235", "145, 350",
                     "", "15", "242 (43)",  "240", "150, 355"),
  `TRT B (N=15)` = c("", "15", "245 (50)",  "242", "148, 362",
                     "", "15", "240 (48)",  "238", "146, 358"),
  check.names = FALSE, stringsAsFactors = FALSE
)
plt_p2 <- data.frame(
  Parameter    = c("Week 12",  "    n", "    Mean (SD)", "    Median", "    Min, Max"),
  `TRT A (N=15)` = c("", "14", "248 (42)",  "246", "155, 360"),
  `TRT B (N=15)` = c("", "13", "235 (51)",  "233", "143, 355"),
  check.names = FALSE, stringsAsFactors = FALSE
)

# ── レポート構築 ───────────────────────────────────────────────────────────────
r <- rtfreport$new()

# 文書共通: スポンサー行 + 動的ページ番号 ({PAGE} → \chpgn, {TOTAL_PAGES} → 5)
r$set_document_defaults(
  default_header = list(
    rows = list(
      list(columns = c(
        l = "Sponsor: Example Corp          Study: LAB-2026-001",
        r = "Page {PAGE} of {TOTAL_PAGES}"
      ))
    )
  ),
  default_footer = list(
    rows = list(
      list(columns = c(
        l = "CONFIDENTIAL — For internal use only",
        r = "Data cut-off: 2026-01-01"
      ))
    ),
    top_border = TRUE
  )
)

# ── Section 1: Hemoglobin (2 pages) ──────────────────────────────────────────
# sec$header はヘッダー最下行に追加。空白スペーサー行は自動挿入。
s1 <- r$add_section(
  header = list(columns = c(l = "Lab Test: Hemoglobin (g/dL)"))
)
r$add_page(
  section_index = s1,
  content = list(list(
    type   = "table",
    data   = {
      tbl <- make_lab_tbl(hgb_p1)
      tbl$blank_rows <- c(0L, 5L)   # blank before row 1 and after row 5
      tbl
    },
    footer = "[a] Values are mean (SD) unless otherwise stated."
  )),
  footer_notes = "Source: ADLB; PARAM = HGB"
)
r$add_page(
  section_index = s1,
  content = list(list(
    type   = "table",
    data   = {
      tbl <- make_lab_tbl(hgb_p2)
      tbl$blank_rows <- c(0L, 5L)
      tbl
    },
    footer = "[a] Values are mean (SD) unless otherwise stated."
  )),
  footer_notes = "Source: ADLB; PARAM = HGB"
)

# ── Section 2: White Blood Cells (1 page) ────────────────────────────────────
s2 <- r$add_section(
  header = list(columns = c(l = "Lab Test: White Blood Cells (10^{3}/\u03bcL)"))
)
r$add_page(
  section_index = s2,
  content = list(list(
    type   = "table",
    data   = {
      tbl <- make_lab_tbl(wbc_p1)
      tbl$blank_rows <- c(0L, 5L)
      tbl
    },
    footer = "[a] Values are mean (SD) unless otherwise stated."
  )),
  footer_notes = "Source: ADLB; PARAM = WBC"
)

# ── Section 3: Platelets (2 pages) ───────────────────────────────────────────
s3 <- r$add_section(
  header = list(columns = c(l = "Lab Test: Platelets (10^{3}/\u03bcL)"))
)
r$add_page(
  section_index = s3,
  content = list(list(
    type   = "table",
    data   = {
      tbl <- make_lab_tbl(plt_p1)
      tbl$blank_rows <- c(0L, 5L)
      tbl
    },
    footer = "[a] Values are mean (SD) unless otherwise stated."
  )),
  footer_notes = "Source: ADLB; PARAM = PLT"
)
r$add_page(
  section_index = s3,
  content = list(list(
    type   = "table",
    data   = make_lab_tbl(plt_p2),
    footer = "[a] Values are mean (SD) unless otherwise stated."
  )),
  footer_notes = "Source: ADLB; PARAM = PLT"
)

# ── 出力 ─────────────────────────────────────────────────────────────────────
out <- file.path(OUT_DIR, "multisection_demo.rtf")
generate_rtfreport(r, out, overwrite = TRUE)

# 検証
txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
stopifnot("\\chpgn field present"   = grepl("\\chpgn",    txt, fixed = TRUE))
stopifnot("total pages = 5"         = grepl("of 5",       txt, fixed = TRUE))
stopifnot("Section 1 header (HGB)"  = grepl("Hemoglobin", txt, fixed = TRUE))
stopifnot("Section 2 header (WBC)"  = grepl("White Blood Cells", txt, fixed = TRUE))
stopifnot("Section 3 header (PLT)"  = grepl("Platelets",  txt, fixed = TRUE))
stopifnot("section_break found"     = grepl("\\sect",     txt, fixed = TRUE))
stopifnot("header_wrapper found"    = grepl("{\\header",  txt, fixed = TRUE))

cat("OK: multisection_demo.rtf\n")
cat("  - 3 Lab test sections, 5 pages total\n")
cat("  - Header: common sponsor/page row + auto-spacer + section lab test name\n")
cat("  - Page field: RTF \\chpgn (dynamic, not static substitution)\n")
cat(sprintf("出力: %s\n", out))
