# =============================================================================
# feature_test.R  —  rtfreporter 機能網羅テスト
#
# 実行方法:
#   cd C:\Yrepo\rtfreporter\r\rtfreporter
#   Rscript tests/feature_test.R
#
# 各テストは tests/output/feature/ 配下に RTF ファイルを生成する。
# 目視確認用のサマリーレポートも tests/output/feature/00_summary.rtf に出力。
# =============================================================================

source(file.path("R", "rtfreport.R"))
source(file.path("R", "rtftable.R"))
source(file.path("R", "rtfplot.R"))
source(file.path("R", "generate_rtfreport.R"))

OUT_DIR <- file.path("tests", "output", "feature")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Utility: assert with message
assert <- function(cond, msg) {
  if (!isTRUE(cond)) stop(paste0("FAIL: ", msg), call. = FALSE)
  invisible(TRUE)
}

# Track results for summary RTF
results <- list()

run_test <- function(name, expr) {
  cat(sprintf("  %-55s", name))
  err <- tryCatch({ force(expr); NULL }, error = function(e) e)
  if (is.null(err)) {
    cat("[PASS]\n")
    results[[length(results) + 1L]] <<- list(name = name, status = "PASS", msg = "")
  } else {
    cat(sprintf("[FAIL] %s\n", conditionMessage(err)))
    results[[length(results) + 1L]] <<- list(name = name, status = "FAIL", msg = conditionMessage(err))
  }
  invisible(is.null(err))
}

# Helper: single-section report wrapping an rtftable
.make_report <- function(tbl, title = NULL, footer_notes = NULL) {
  r <- rtfreport$new()
  s <- r$add_section()
  r$add_page(
    section_index = s,
    title         = title,
    content       = list(list(type = "table", data = tbl)),
    footer_notes  = footer_notes
  )
  r
}

# Sample data
DM <- read.csv(file.path("tests", "testdata", "dm.csv"), stringsAsFactors = FALSE)
AE <- read.csv(file.path("tests", "testdata", "ae.csv"), stringsAsFactors = FALSE)

cat("\n=== rtfreporter 機能網羅テスト ===\n\n")

# =============================================================================
# A-1: 手動列ヘッダー — 文字列ベクタ指定
# =============================================================================
cat("[A-1] 手動列ヘッダー\n")

run_test("A-1a: pipe区切り文字列でヘッダー指定", {
  tbl <- rtftable$new(DM, col_header = "Subject ID | Sex | Age (yr) | Treatment Arm")
  r   <- .make_report(tbl, title = "A-1a: Pipe-delimited column headers")
  out <- file.path(OUT_DIR, "A1a_pipe_header.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("Subject ID", txt, fixed = TRUE), "Subject ID not found")
  assert(grepl("Treatment Arm", txt, fixed = TRUE), "Treatment Arm not found")
})

run_test("A-1b: 文字ベクタでヘッダー指定", {
  tbl <- rtftable$new(DM, col_header = c("被験者ID", "性別", "年齢", "治療群"))
  r   <- .make_report(tbl, title = "A-1b: Character vector headers (Japanese)")
  out <- file.path(OUT_DIR, "A1b_vector_header.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # Japanese → Unicode escapes
  assert(grepl("\\u", txt, fixed = TRUE), "Unicode escape not found")
})

run_test("A-1c: 複数行ヘッダー (list)", {
  tbl <- rtftable$new(
    DM,
    col_header = list(
      c("Demographics",        "",      "",        ""),
      c("Subject ID", "Sex", "Age", "Treatment")
    )
  )
  r   <- .make_report(tbl, title = "A-1c: Multi-row column headers")
  out <- file.path(OUT_DIR, "A1c_multirow_header.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("Demographics", txt, fixed = TRUE), "Demographics not found")
  assert(grepl("Treatment",    txt, fixed = TRUE), "Treatment not found")
})

# =============================================================================
# A-2: スパニングヘッダー
# =============================================================================
cat("[A-2] スパニングヘッダー\n")

run_test("A-2a: 基本スパニング (underline=TRUE)", {
  df_span <- data.frame(
    USUBJID = DM$USUBJID, SEX = DM$SEX, AGE = DM$AGE, ARM = DM$ARM,
    stringsAsFactors = FALSE
  )
  tbl <- rtftable$new(
    df_span,
    col_header      = c("Subject", "Sex", "Age", "Arm"),
    spanning_header = list(
      list(from = 3L, to = 4L, label = "Demographics", underline = TRUE)
    )
  )
  r   <- .make_report(tbl, title = "A-2a: Spanning header (cols 3-4)")
  out <- file.path(OUT_DIR, "A2a_spanning_header.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("Demographics", txt, fixed = TRUE), "span label not found")
  assert(grepl("\\ul ", txt, fixed = TRUE), "underline not found")
})

run_test("A-2b: 複数スパン", {
  df6 <- data.frame(
    A1="a", A2="b", B1="c", B2="d", C1="e", C2="f",
    stringsAsFactors = FALSE
  )
  tbl <- rtftable$new(
    df6,
    spanning_header = list(
      list(from = 1L, to = 2L, label = "Group A", underline = TRUE),
      list(from = 3L, to = 4L, label = "Group B", underline = TRUE),
      list(from = 5L, to = 6L, label = "Group C", underline = TRUE)
    )
  )
  r   <- .make_report(tbl, title = "A-2b: Multiple spanning headers")
  out <- file.path(OUT_DIR, "A2b_multi_spanning.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("Group A", txt, fixed = TRUE), "Group A not found")
  assert(grepl("Group C", txt, fixed = TRUE), "Group C not found")
})

# =============================================================================
# B-1: セル単位罫線制御
# =============================================================================
cat("[B-1] 罫線制御\n")

run_test("B-1a: border='tfl' — ヘッダー上下罫線あり、ボディなし、最終行下罫線あり", {
  tbl <- rtftable$new(DM, border = "tfl")
  r   <- .make_report(tbl, title = "B-1a: TFL standard border")
  out <- file.path(OUT_DIR, "B1a_border_tfl.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("clbrdrt\\brdrs", txt, fixed = TRUE), "header top border missing")
  assert(grepl("clbrdrb\\brdrs", txt, fixed = TRUE), "header bottom / last-row border missing")
})

run_test("B-1b: border=NULL — 全罫線なし", {
  tbl <- rtftable$new(DM, border = NULL)
  r   <- .make_report(tbl, title = "B-1b: No borders")
  out <- file.path(OUT_DIR, "B1b_border_none.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # No clbrdrt/clbrdrb except legacy footer (which uses cell_boundary_top_border_template)
  # Check that data/header rows have no border commands
  row_lines <- grep("\\\\trowd", strsplit(txt, "\n")[[1]], value = TRUE)
  has_border <- any(grepl("clbrdr", row_lines, fixed = TRUE))
  assert(!has_border, "border commands found when border=NULL")
})

run_test("B-1c: border カスタム — 全辺 double", {
  tbl <- rtftable$new(
    DM[1:3, ],
    border = list(
      header   = list(top = "double", bottom = "double", left = "double", right = "double"),
      body     = list(top = "double", bottom = "double", left = "double", right = "double"),
      last_row = list(bottom = "double")
    )
  )
  r   <- .make_report(tbl, title = "B-1c: Custom double borders all sides")
  out <- file.path(OUT_DIR, "B1c_border_double.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("\\brdrdb", txt, fixed = TRUE), "double border not found")
})

# =============================================================================
# C-1: テキスト装飾 (Bold / Italic / Underline)
# =============================================================================
cat("[C-1] テキスト装飾\n")

run_test("C-1a: col_spec — 列ごとに bold / italic / underline", {
  tbl <- rtftable$new(
    DM,
    col_spec = list(
      list(col = "USUBJID", bold = TRUE,  align = "left"),
      list(col = "SEX",     italic = TRUE, align = "center"),
      list(col = "AGE",     align = "right"),
      list(col = "ARM",     underline = TRUE, align = "left")
    )
  )
  r   <- .make_report(tbl, title = "C-1a: Per-column text decoration")
  out <- file.path(OUT_DIR, "C1a_text_decor.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("\\b ",  txt, fixed = TRUE), "bold not found")
  assert(grepl("\\i ",  txt, fixed = TRUE), "italic not found")
  assert(grepl("\\ul ", txt, fixed = TRUE), "underline not found")
  assert(grepl("\\qr",  txt, fixed = TRUE), "right-align not found")
})

run_test("C-1b: ヘッダー bold / italic の個別制御", {
  tbl <- rtftable$new(
    DM[1:2, ],
    col_spec = list(
      list(col = 1, header_bold = TRUE,  header_italic = FALSE),
      list(col = 2, header_bold = FALSE, header_italic = TRUE),
      list(col = 3, header_bold = TRUE,  header_align = "left"),
      list(col = 4, header_bold = FALSE, header_align = "right")
    )
  )
  r   <- .make_report(tbl, title = "C-1b: Header-specific decoration")
  out <- file.path(OUT_DIR, "C1b_header_decor.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  assert(file.exists(out), "output not created")
})

# =============================================================================
# C-2: セル内インデント
# =============================================================================
cat("[C-2] セル内インデント\n")

run_test("C-2a: indent_twips で階層的インデント", {
  listing_df <- data.frame(
    ITEM  = c("Parameter", "  Mean", "  SD", "  Min", "  Max"),
    VALUE = c("", "64.0", "10.3", "45", "82"),
    stringsAsFactors = FALSE
  )
  tbl <- rtftable$new(
    listing_df,
    col_spec = list(
      list(col = "ITEM",  align = "left", indent_twips = 0L),
      list(col = "VALUE", align = "right")
    ),
    col_rel_width = c(3, 1)
  )
  r   <- .make_report(tbl, title = "C-2a: Cell indent (listing style)")
  out <- file.path(OUT_DIR, "C2a_indent.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  assert(file.exists(out), "output not created")
})

run_test("C-2b: 深いインデント (360 twips = 0.25\")", {
  listing_df2 <- data.frame(
    CATEGORY = c("Overall", "  Male", "  Female", "    < 65", "    >= 65"),
    N = c(10, 6, 4, 7, 3),
    stringsAsFactors = FALSE
  )
  tbl <- rtftable$new(
    listing_df2,
    col_spec = list(list(col = "CATEGORY", indent_twips = 360L)),
    col_rel_width = c(4, 1)
  )
  r   <- .make_report(tbl, title = "C-2b: Deep indent 360 twips")
  out <- file.path(OUT_DIR, "C2b_deep_indent.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("\\li", txt, fixed = TRUE), "\\li command not found")
})

# =============================================================================
# D-1: 行高
# =============================================================================
cat("[D-1] 行高\n")

run_test("D-1a: row_height_twips 固定 (360 = 0.25\")", {
  tbl <- rtftable$new(DM, row_height_twips = 360L)
  r   <- .make_report(tbl, title = "D-1a: Fixed row height 360 twips")
  out <- file.path(OUT_DIR, "D1a_rowheight_fixed.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("\\trrh360", txt, fixed = TRUE), "\\trrh360 not found")
})

run_test("D-1b: row_height_twips=0 (auto)", {
  tbl <- rtftable$new(DM, row_height_twips = 0L)
  r   <- .make_report(tbl, title = "D-1b: Auto row height (trrh=0)")
  out <- file.path(OUT_DIR, "D1b_rowheight_auto.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # row_height=0 → \trrh must NOT appear
  assert(!grepl("\\trrh0", txt, fixed = TRUE), "\\trrh0 should not be emitted")
})

run_test("D-1c: header_row_height_twips でヘッダーだけ高くする", {
  tbl <- rtftable$new(
    DM, row_height_twips = 280L, header_row_height_twips = 560L
  )
  r   <- .make_report(tbl, title = "D-1c: Separate header/data row heights")
  out <- file.path(OUT_DIR, "D1c_rowheight_header.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("\\trrh560", txt, fixed = TRUE), "header height 560 not found")
  assert(grepl("\\trrh280", txt, fixed = TRUE), "data height 280 not found")
})

# =============================================================================
# E-1 / E-2: Unicode 強化 / 特殊記法変換
# =============================================================================
cat("[E-1/E-2] Unicode・特殊記法\n")

run_test("E-1a: 日本語テキスト → \\uNNNN? エスケープ", {
  df_jp <- data.frame(
    項目   = c("平均値", "標準偏差", "最小値", "最大値"),
    値     = c("64.0", "10.3", "45", "82"),
    stringsAsFactors = FALSE
  )
  tbl <- rtftable$new(df_jp, col_header = c("項目", "値"))
  r   <- .make_report(tbl, title = "E-1a: Japanese Unicode text")
  out <- file.path(OUT_DIR, "E1a_unicode_japanese.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("\\u", txt, fixed = TRUE), "Unicode escape not found")
})

run_test("E-2a: >= と <= の RTF Unicode 変換", {
  df_sym <- data.frame(
    CRITERION = c("Age >= 18", "BMI <= 30", "Baseline >= 10"),
    N = c(8L, 10L, 7L),
    stringsAsFactors = FALSE
  )
  tbl <- rtftable$new(df_sym)
  r   <- .make_report(tbl, title = "E-2a: >= and <= symbol conversion")
  out <- file.path(OUT_DIR, "E2a_symbols.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("\\u8805?", txt, fixed = TRUE), ">= unicode not found")
  assert(grepl("\\u8804?", txt, fixed = TRUE), "<= unicode not found")
})

run_test("E-2b: ^{} 上付き / _{} 下付き マークアップ", {
  df_mu <- data.frame(
    FORMULA = c("CO^{2}", "H_{2}O", "x^{2} + y^{2}", "log_{10}(n)"),
    VALUE   = c("0.04%", "96%", "n/a", "3.0"),
    stringsAsFactors = FALSE
  )
  tbl <- rtftable$new(df_mu)
  r   <- .make_report(tbl, title = "E-2b: Superscript ^{} and subscript _{}")
  out <- file.path(OUT_DIR, "E2b_super_sub.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("\\super ", txt, fixed = TRUE), "\\super not found")
  assert(grepl("\\sub ",   txt, fixed = TRUE), "\\sub not found")
})

run_test("E-2c: \\n セル内改行", {
  df_nl <- data.frame(
    NOTE = c("Line 1\nLine 2", "Single line", "A\nB\nC"),
    stringsAsFactors = FALSE
  )
  tbl <- rtftable$new(df_nl)
  r   <- .make_report(tbl, title = "E-2c: Newline \\n → \\line in cells")
  out <- file.path(OUT_DIR, "E2c_newline.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("\\line ", txt, fixed = TRUE), "\\line not found")
})

# =============================================================================
# F-1: 相対列幅
# =============================================================================
cat("[G] 相対列幅\n")

run_test("G-a: col_rel_width — 3:1:1:1 分配", {
  tbl <- rtftable$new(
    DM,
    col_rel_width   = c(3, 1, 1, 1),
    table_width_twips = 12960L  # 9 inches
  )
  r   <- .make_report(tbl, title = "G-a: Relative widths 3:1:1:1 (9 inch table)")
  out <- file.path(OUT_DIR, "Ga_rel_width.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  # col1 = round(12960 * 3/6) = 6480
  assert(grepl("\\cellx6480", txt, fixed = TRUE), "cellx6480 not found")
  assert(grepl("\\cellx12960", txt, fixed = TRUE), "cellx12960 (total) not found")
})

run_test("G-b: table_width_pct_of_writable = 0.8", {
  tbl <- rtftable$new(
    DM[1:3, ],
    table_width_pct_of_writable = 0.8
  )
  r   <- .make_report(tbl, title = "G-b: Table width 80% of writable width")
  out <- file.path(OUT_DIR, "Gb_pct_width.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  assert(file.exists(out), "output not created")
})

run_test("G-c: column_widths_twips 絶対指定", {
  tbl <- rtftable$new(
    DM,
    column_widths_twips = c(2880L, 720L, 720L, 2160L)
  )
  r   <- .make_report(tbl, title = "G-c: Absolute column widths in twips")
  out <- file.path(OUT_DIR, "Gc_abs_width.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("\\cellx2880", txt, fixed = TRUE), "cellx2880 not found")
  assert(grepl("\\cellx6480", txt, fixed = TRUE), "cellx6480 not found")
})

# =============================================================================
# セル垂直アライメント
# =============================================================================
cat("[valign] セル垂直アライメント\n")

run_test("valign-a: cell_valign='top'", {
  tbl <- rtftable$new(DM[1:2, ], cell_valign = "top")
  r   <- .make_report(tbl, title = "valign-a: Vertical align TOP")
  out <- file.path(OUT_DIR, "VA_valign_top.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("\\clvertalt", txt, fixed = TRUE), "\\clvertalt not found")
})

run_test("valign-b: cell_valign='center'", {
  tbl <- rtftable$new(DM[1:2, ], cell_valign = "center")
  r   <- .make_report(tbl, title = "valign-b: Vertical align CENTER")
  out <- file.path(OUT_DIR, "VB_valign_center.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("\\clvertalc", txt, fixed = TRUE), "\\clvertalc not found")
})

# =============================================================================
# セルパディング
# =============================================================================
cat("[padding] セルパディング\n")

run_test("PAD-a: cell_padding_left/right カスタム値", {
  tbl <- rtftable$new(
    DM[1:3, ],
    cell_padding_left_twips  = 180L,
    cell_padding_right_twips = 180L
  )
  r   <- .make_report(tbl, title = "PAD-a: Custom cell padding 180 twips each side")
  out <- file.path(OUT_DIR, "PAD_padding.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("\\li180", txt, fixed = TRUE), "\\li180 not found")
  assert(grepl("\\ri180", txt, fixed = TRUE), "\\ri180 not found")
})

# =============================================================================
# 複合: AE Adverse Events テーブル (Clinical TFL 風)
# =============================================================================
cat("[COMPOSITE] Clinical TFL 風総合テスト\n")

run_test("COMP-a: Clinical AE listing (全機能組み合わせ)", {
  ae_disp <- AE
  ae_disp$AETERM <- paste0(ae_disp$AETERM, "^{a}")  # superscript footnote marker

  tbl <- rtftable$new(
    ae_disp,
    col_header      = "Subject ID | Adverse Event | Severity | Serious?",
    spanning_header = list(
      list(from = 2L, to = 4L, label = "Adverse Event Summary", underline = TRUE)
    ),
    col_spec = list(
      list(col = "USUBJID", align = "left",   bold   = FALSE),
      list(col = "AETERM",  align = "left",   italic = FALSE),
      list(col = "AESEV",   align = "center"),
      list(col = "AESER",   align = "center", bold   = TRUE,
           header_align = "center", header_bold = TRUE)
    ),
    col_rel_width = c(2, 4, 2, 1),
    border        = "tfl",
    row_height_twips = 320L,
    cell_padding_left_twips = 108L
  )

  r <- rtfreport$new()
  r$set_document_defaults(
    default_header = list(
      rows = list(
        list(columns = c(l = "Sponsor: Example Corp",
                         r = "Study: EX-2026-001")),
        list(columns = c(l = "Table 14.3.1: Adverse Events",
                         r = "Page {PAGE} of {TOTAL_PAGES}"))
      )
    ),
    default_footer = list(
      rows      = list(list(columns = c(l = "Confidential"))),
      top_border = TRUE
    )
  )
  s <- r$add_section()
  r$add_page(
    section_index = s,
    title         = "Table 14.3.1 — Adverse Events by Subject",
    content       = list(list(
      type   = "table",
      data   = tbl,
      footer = "^{a} Verbatim adverse event term as reported"
    )),
    footer_notes = "Source: ADAE dataset; Data cut-off: 2026-01-01"
  )

  out <- file.path(OUT_DIR, "COMPa_ae_clinical.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("Adverse Event Summary", txt, fixed = TRUE), "span label missing")
  assert(grepl("\\super ", txt, fixed = TRUE), "superscript missing")
  assert(grepl("clbrdrt\\brdrs", txt, fixed = TRUE), "TFL header border missing")
})

run_test("COMP-b: Demographics table with relative widths + unicode", {
  dm_disp <- DM
  dm_disp$NOTE <- c(">=18 yr", "<=30 BMI", "n>=10", "OK")
  tbl <- rtftable$new(
    dm_disp,
    col_header = c("Subject", "Sex", "Age", "Arm", "Criteria"),
    col_spec = list(
      list(col = "USUBJID", align = "left",   bold = TRUE),
      list(col = "SEX",     align = "center"),
      list(col = "AGE",     align = "right"),
      list(col = "ARM",     align = "left"),
      list(col = "NOTE",    align = "left",   italic = TRUE)
    ),
    col_rel_width = c(2, 1, 1, 2, 2),
    border        = "tfl",
    row_height_twips = 340L
  )
  r   <- .make_report(tbl, title = "COMP-b: DM table with unicode symbols")
  out <- file.path(OUT_DIR, "COMPb_dm_unicode.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("\\u8805?", txt, fixed = TRUE), ">= unicode not found")
  assert(grepl("\\u8804?", txt, fixed = TRUE), "<= unicode not found")
})

# =============================================================================
# エラーハンドリング
# =============================================================================
cat("[ERR] エラーハンドリング\n")

run_test("ERR-a: 不正な border 型 → エラー", {
  err <- tryCatch(
    rtftable$new(DM, border = "invalid"),
    error = function(e) e
  )
  assert(inherits(err, "error"), "should have thrown")
})

run_test("ERR-b: col_rel_width 長さ不一致 → エラー", {
  tbl <- rtftable$new(DM, col_rel_width = c(1, 2, 3))  # DM has 4 cols
  r   <- .make_report(tbl)
  err <- tryCatch(
    generate_rtfreport(r, file.path(tempdir(), "err_b.rtf"), overwrite = TRUE),
    error = function(e) e
  )
  assert(inherits(err, "error"), "should have thrown length mismatch")
})

run_test("ERR-c: column_widths_twips 長さ不一致 → エラー", {
  tbl <- rtftable$new(DM, column_widths_twips = c(1000L, 2000L))  # too few
  r   <- .make_report(tbl)
  err <- tryCatch(
    generate_rtfreport(r, file.path(tempdir(), "err_c.rtf"), overwrite = TRUE),
    error = function(e) e
  )
  assert(inherits(err, "error"), "should have thrown")
})

run_test("ERR-d: 存在しない col_spec col 名 → エラー", {
  err <- tryCatch(
    rtftable$new(DM, col_spec = list(list(col = "NOTEXIST", bold = TRUE))),
    error = function(e) e
  )
  assert(inherits(err, "error"), "should have thrown col not found")
})

run_test("ERR-e: overwrite=FALSE で既存ファイル → エラー", {
  out <- file.path(tempdir(), "existing_err.rtf")
  tbl <- rtftable$new(DM[1, ])
  r   <- .make_report(tbl)
  generate_rtfreport(r, out, overwrite = TRUE)  # create first
  err <- tryCatch(
    generate_rtfreport(r, out, overwrite = FALSE),
    error = function(e) e
  )
  assert(inherits(err, "error"), "should have thrown overwrite error")
})

# =============================================================================
# 後方互換 — data.frame 直渡し (旧 API)
# =============================================================================
cat("[COMPAT] 後方互換\n")

run_test("COMPAT-a: data.frame 直渡し (旧 API)", {
  r <- rtfreport$new()
  s <- r$add_section()
  r$add_page(
    section_index = s,
    title = "COMPAT-a: Legacy data.frame API",
    content = list(list(type = "table", data = DM, footer = "Legacy footer"))
  )
  out <- file.path(OUT_DIR, "COMPATa_legacy.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  assert(file.exists(out), "output not created")
})

run_test("COMPAT-b: metadata list 渡し (旧 API)", {
  r <- rtfreport$new()
  s <- r$add_section()
  r$add_page(
    section_index = s,
    content = list(list(
      type = "table",
      data = DM[1:2, c("USUBJID", "SEX")],
      metadata = list(
        row_height_twips    = 360L,
        column_widths_twips = c(2880L, 1440L)
      )
    ))
  )
  out <- file.path(OUT_DIR, "COMPATb_legacy_meta.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("\\trrh360", txt, fixed = TRUE), "\\trrh360 not found")
  assert(grepl("\\cellx2880", txt, fixed = TRUE), "\\cellx2880 not found")
})

# =============================================================================
# H-1: 空白行挿入 (blank_rows)
# =============================================================================
cat("[H-1] 空白行挿入 (blank_rows)\n")

run_test("H-1a: blank_rows=0 — 最初のデータ行の前に空白行", {
  tbl <- rtftable$new(
    DM,
    blank_rows = 0L,
    border = "tfl",
    row_height_twips = 300L
  )
  r   <- .make_report(tbl, title = "H-1a: blank_rows=0 (before row 1)")
  out <- file.path(OUT_DIR, "H1a_blank_before_first.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  assert(file.exists(out), "output not created")
})

run_test("H-1b: blank_rows=c(2) — 2行目の後に空白行", {
  tbl <- rtftable$new(
    DM,
    blank_rows = 2L,
    border = "tfl",
    row_height_twips = 300L
  )
  r   <- .make_report(tbl, title = "H-1b: blank_rows=c(2) (after row 2)")
  out <- file.path(OUT_DIR, "H1b_blank_after_row2.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  assert(file.exists(out), "output not created")
})

run_test("H-1c: blank_rows=c(0,3) — 先頭と3行目の後に空白行", {
  df_h <- data.frame(
    Category = c("Group A", "  n", "  Mean (SD)", "Group B", "  n", "  Mean (SD)"),
    TRT_A    = c("", "10", "64.0 (10.3)", "", "8", "58.5 (9.2)"),
    TRT_B    = c("", "10", "60.1 (11.5)", "", "9", "62.3 (8.4)"),
    stringsAsFactors = FALSE
  )
  tbl <- rtftable$new(
    df_h,
    col_header = c("Parameter", "Treatment A\n(N=10)", "Treatment B\n(N=10)"),
    blank_rows = c(0L, 3L),
    col_spec = list(
      list(col = "Category", align = "left"),
      list(col = "TRT_A",    align = "right"),
      list(col = "TRT_B",    align = "right")
    ),
    col_rel_width = c(3, 2, 2),
    border = "tfl",
    row_height_twips = 300L
  )
  r   <- .make_report(tbl, title = "H-1c: blank_rows=c(0,3) group separator rows")
  out <- file.path(OUT_DIR, "H1c_blank_group_sep.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  assert(file.exists(out), "output not created")
})

run_test("H-1d: blank_row_height_twips カスタム指定", {
  tbl <- rtftable$new(
    DM[1:3, ],
    blank_rows = 2L,
    blank_row_height_twips = 200L,
    row_height_twips = 300L
  )
  r   <- .make_report(tbl, title = "H-1d: Custom blank row height (200 twips)")
  out <- file.path(OUT_DIR, "H1d_blank_custom_height.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("\\trrh200", txt, fixed = TRUE), "\\trrh200 not found in blank row")
})

# =============================================================================
# TFL風デモ: Demographics 統計サマリー表 (全機能統合)
# =============================================================================
cat("[TFL-DEMO] Demographics TFL スタイルデモ\n")

run_test("TFL-DEMO: Demographics Summary Table (TFL style)", {
  # Demographics summary data (simulated)
  demo_df <- data.frame(
    Parameter = c(
      "Age (years)",
      "    n",
      "    Mean (SD)",
      "    Median",
      "    Min, Max",
      "Age group [n (%)]",
      "    18 <= age < 65",
      "    age >= 65",
      "Sex [n (%)]",
      "    Male",
      "    Female",
      "Race [n (%)]",
      "    Asian",
      "    Black",
      "    White"
    ),
    TRT_A = c(
      "", "10", "58.4 (10.3)", "60.0", "38.0, 74.0",
      "", "6 (60.0)", "4 (40.0)",
      "", "6 (60.0)", "4 (40.0)",
      "", "2 (20.0)", "1 (10.0)", "7 (70.0)"
    ),
    TRT_B = c(
      "", "10", "61.2 (9.7)", "63.0", "42.0, 77.0",
      "", "5 (50.0)", "5 (50.0)",
      "", "5 (50.0)", "5 (50.0)",
      "", "3 (30.0)", "2 (20.0)", "5 (50.0)"
    ),
    Total = c(
      "", "20", "59.8 (10.0)", "61.5", "38.0, 77.0",
      "", "11 (55.0)", "9 (45.0)",
      "", "11 (55.0)", "9 (45.0)",
      "", "5 (25.0)", "3 (15.0)", "12 (60.0)"
    ),
    stringsAsFactors = FALSE
  )

  # Bold the category header rows (rows 1, 6, 9, 12)
  bold_rows <- c(1, 6, 9, 12)

  tbl <- rtftable$new(
    demo_df,
    col_header = list(
      c("", "Treatment A\n(N=10)", "Treatment B\n(N=10)", "Total\n(N=20)"),
      c("Parameter", "(N=10)", "(N=10)", "(N=20)")
    ),
    spanning_header = list(
      list(from = 2L, to = 3L, label = "Randomized Treatment", underline = TRUE)
    ),
    col_spec = list(
      list(col = "Parameter", align = "left"),
      list(col = "TRT_A",     align = "right"),
      list(col = "TRT_B",     align = "right"),
      list(col = "Total",     align = "right")
    ),
    # Blank rows after each category block: after row 5, 8, 11
    blank_rows = c(5L, 8L, 11L),
    col_rel_width = c(4, 2, 2, 2),
    border = "tfl",
    row_height_twips = 300L,
    header_row_height_twips = 360L,
    cell_padding_left_twips = 108L,
    cell_padding_right_twips = 108L
  )

  r <- rtfreport$new()
  r$set_document_defaults(
    default_header = list(
      rows = list(
        list(columns = c(
          l = "Sponsor: Example Corp          Study: EX-2026-001",
          r = "Page {PAGE} of {TOTAL_PAGES}"
        )),
        list(columns = c(
          l = "Table 14.1.1: Demographic and Baseline Characteristics",
          r = ""
        ))
      )
    ),
    default_footer = list(
      rows = list(
        list(columns = c(l = "Note: Values are n (%) unless otherwise specified.")),
        list(columns = c(l = "Source: ADSL dataset. Data cut-off: 2026-01-01."))
      ),
      top_border = TRUE
    )
  )

  s <- r$add_section()
  r$add_page(
    section_index = s,
    title   = "Table 14.1.1 — Demographic and Baseline Characteristics",
    content = list(list(
      type   = "table",
      data   = tbl,
      footer = "[a] n (%) unless otherwise specified"
    )),
    footer_notes = "Source: ADSL; Cutoff: 2026-01-01"
  )

  out <- file.path(OUT_DIR, "TFL_demographics.rtf")
  generate_rtfreport(r, out, overwrite = TRUE)
  txt <- paste(readLines(out, warn = FALSE), collapse = "\n")
  assert(grepl("Randomized Treatment", txt, fixed = TRUE), "spanning header missing")
  assert(grepl("\\u8804?", txt, fixed = TRUE), "<= unicode missing")  # from "18 <= age"
  assert(grepl("\\u8805?", txt, fixed = TRUE), ">= unicode missing")  # from "age >= 65"
  assert(file.exists(out), "output not created")
})

# =============================================================================
# 総合サマリー RTF レポート生成
# =============================================================================
cat("\n--- テスト結果サマリー生成中 ---\n")

n_pass <- sum(vapply(results, function(x) x$status == "PASS", logical(1L)))
n_fail <- sum(vapply(results, function(x) x$status == "FAIL", logical(1L)))

summary_df <- data.frame(
  No     = seq_along(results),
  Test   = vapply(results, function(x) x$name,   character(1L)),
  Status = vapply(results, function(x) x$status, character(1L)),
  Detail = vapply(results, function(x) x$msg,    character(1L)),
  stringsAsFactors = FALSE
)

tbl_summary <- rtftable$new(
  summary_df,
  col_header = c("No.", "Test Name", "Status", "Detail"),
  col_spec = list(
    list(col = "No",     align = "right"),
    list(col = "Test",   align = "left"),
    list(col = "Status", align = "center", bold = TRUE),
    list(col = "Detail", align = "left",   italic = TRUE)
  ),
  col_rel_width   = c(1, 6, 2, 4),
  border          = "tfl",
  row_height_twips = 300L,
  cell_padding_left_twips = 108L
)

r_summary <- rtfreport$new()
r_summary$set_document_defaults(
  default_header = list(
    rows = list(
      list(columns = c(
        l = "rtfreporter Feature Test Report",
        r = paste0("Run: ", format(Sys.time(), "%Y-%m-%d %H:%M"))
      ))
    )
  ),
  default_footer = list(
    rows = list(list(columns = c(
      l = sprintf("PASS: %d / FAIL: %d / TOTAL: %d", n_pass, n_fail, n_pass + n_fail)
    ))),
    top_border = TRUE
  )
)
s_sum <- r_summary$add_section()
r_summary$add_page(
  section_index = s_sum,
  title         = sprintf("Feature Test Summary  —  PASS: %d  /  FAIL: %d  /  TOTAL: %d",
                           n_pass, n_fail, n_pass + n_fail),
  content       = list(list(type = "table", data = tbl_summary)),
  footer_notes  = "Generated by feature_test.R"
)
summary_out <- file.path(OUT_DIR, "00_summary.rtf")
generate_rtfreport(r_summary, summary_out, overwrite = TRUE)

cat(sprintf("\n=== 結果: PASS %d / FAIL %d / TOTAL %d ===\n",
            n_pass, n_fail, n_pass + n_fail))
cat(sprintf("    サマリーレポート: %s\n\n", summary_out))

if (n_fail > 0L) {
  cat("FAIL したテスト:\n")
  for (x in results[vapply(results, function(r) r$status == "FAIL", logical(1L))]) {
    cat(sprintf("  - %s\n    %s\n", x$name, x$msg))
  }
  quit(status = 1L)
}
