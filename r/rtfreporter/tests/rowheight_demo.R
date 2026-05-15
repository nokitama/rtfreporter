# =============================================================================
# rowheight_demo.R  —  行高「文字ぎりぎり」比較デモ
#
# Courier New 9pt (= 180 twips) の1行テキストに対して
# 異なる row_height_twips を並べ、視覚的に確認する。
#
# 実行方法:
#   cd C:\Yrepo\rtfreporter\r\rtfreporter
#   Rscript tests/rowheight_demo.R
#
# 出力: tests/output/rowheight_demo.rtf
# =============================================================================

source(file.path("R", "rtfreport.R"))
source(file.path("R", "rtftable.R"))
source(file.path("R", "rtfplot.R"))
source(file.path("R", "generate_rtfreport.R"))

OUT_DIR <- file.path("tests", "output")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# デフォルト: Courier 9pt (= 18 half-points)
# 1pt = 20 twips → 9pt = 180 twips
# 標準行間 (1.2倍) = 216 twips がほぼ「ぴったり」
# ネガティブ値 = exact height (trrh)

# 幅は9インチ (= 12960 twips)。左右マージン各0.5インチ → 書き込み幅 8インチ
# 比較用データ: 列幅 6:1:1 (Parameter / 設定値 / 備考)

heights <- c(
  "180 twips exact — 文字高さ固定 (row_height_exact=TRUE; クリップされる)" = -180L,
  "200 twips exact — ぎりぎり固定 (row_height_exact=TRUE)"                = -200L,
  "220 twips exact — 標準1.2×行間 固定 (row_height_exact=TRUE)"           = -220L,
  "280 twips min  — 余裕あり 最小 (row_height_exact=FALSE)"               =  280L,
  "360 twips min  — 0.25インチ 最小 (row_height_exact=FALSE)"             =  360L
)

# 各高さで小テーブルを1ページに並べる
r <- rtfreport$new(
  default_page = list(
    paper           = "letter",
    orientation     = "landscape",
    width_twips     = .in_to_twips(11),
    height_twips    = .in_to_twips(8.5),
    margin_top_twips    = .in_to_twips(0.5),
    margin_bottom_twips = .in_to_twips(0.5),
    margin_left_twips   = .in_to_twips(1.0),
    margin_right_twips  = .in_to_twips(1.0)
  )
)
r$set_document_defaults(
  default_header = list(
    rows = list(
      list(columns = c(
        l = "rtfreporter Row Height Demo — Courier 9pt, 9-inch table",
        r = "Page {PAGE} of {TOTAL_PAGES}"
      ))
    )
  ),
  default_footer = list(
    rows = list(list(columns = c(
      l = "Note: trrh positive = minimum height; negative = exact height"
    ))),
    top_border = TRUE
  )
)

s <- r$add_section()

# 比較テーブル一覧
tables_content <- lapply(seq_along(heights), function(i) {
  h     <- heights[[i]]
  label <- names(heights)[i]

  sample_df <- data.frame(
    Parameter = c(
      "row_height_twips",
      "    n",
      "    Mean (SD)",
      "    Median",
      "    Min, Max"
    ),
    TRT_A = c("", "10", "58.4 (10.3)", "60.0", "38.0, 74.0"),
    TRT_B = c("", "10", "61.2 (9.7)",  "63.0", "42.0, 77.0"),
    stringsAsFactors = FALSE
  )

  tbl <- rtftable$new(
    sample_df,
    col_header = list(
      c(paste0("trrh = ", abs(h), if (h < 0) " (exact)" else " (min)"), "", ""),
      c("Parameter", "TRT A (N=10)", "TRT B (N=10)")
    ),
    col_spec = list(
      list(col = "Parameter", align = "left"),
      list(col = "TRT_A",     align = "right"),
      list(col = "TRT_B",     align = "right")
    ),
    col_rel_width        = c(4, 2, 2),
    table_width_twips    = 12960L,
    border               = "tfl",
    row_height_twips     = abs(h),
    row_height_exact     = (h < 0L),
    header_row_height_twips = 280L,
    cell_padding_left_twips  = 108L,
    cell_padding_right_twips = 108L
  )

  list(type = "table", data = tbl)
})

r$add_page(
  section_index = s,
  title = "行高比較 — Courier 9pt / 9インチ表 (trrh = 180, 200, 220, 280, 360 twips)",
  content = tables_content,
  footer_notes = "各テーブルの row_height_twips (\\trrh) を変えてデータ行の高さを比較"
)

out <- file.path(OUT_DIR, "rowheight_demo.rtf")
generate_rtfreport(r, out, overwrite = TRUE)
cat(sprintf("出力: %s\n", out))
