# rtfreporter 機能検討案

**作成日**: 2026-05-15  
**対象**: rtfreporter R パッケージ  
**参照**: R2RTF v1.2.0, reporter (master)

---

## 背景と方針

### 分析対象パッケージの評価

| 観点 | R2RTF | reporter | rtfreporter（現状） |
|------|-------|----------|---------------------|
| テーブルヘッダー | ◎ パイプ区切り手動指定、複数行 | △ 自動生成、スパン対応 | △ 列名そのまま |
| 罫線制御 | △ 消去が不完全、"none"なし | △ all/inside等の大雑把指定 | △ フッター上線のみ |
| セル書式 | ○ テキスト単位で詳細指定 | △ Bold/Italic程度 | △ ヘッダーBoldのみ |
| 行高・余白 | △ フォントサイズ依存あり | ✗ フォントサイズ固定 | △ 定数指定のみ |
| セクション | ✗ なし | ✗ なし | ◎ ある |
| RTF文書構造 | ○ しっかりしている | △ テキスト変換経由 | ○ コマンドリソース分離 |
| Unicode対応 | ○ \u変換あり | ○ あり | △ 簡易エスケープのみ |
| 相対列幅 | ○ col_rel_width | △ widthのみ | △ 絶対値のみ |

### 基本方針

1. **現在のRTF文書構造（Document → Section → Page → Block）を厳守する**  
2. **RTFコマンドはリソースファイル（rtf_commands.R）に集約し、安定させる**  
3. **コードは真似しない。アイデアのみ取り込む**  
4. **フォントサイズに依存した寸法計算は一切行わない**  
5. **"ない機能はない"として明示できる設計（NULL や "none" で完全消去）**

---

## 機能検討案一覧

### A. テーブルヘッダーの強化

#### A-1. 手動列ヘッダー指定（R2RTF の強みを取り込む）

**概要**: 列ヘッダーをデータフレームの列名から自動生成するだけでなく、文字列またはベクタで手動指定できるようにする。

**想定API**:
```r
# パイプ区切り文字列（R2RTFスタイル）
add_table(..., col_header = "Treatment | N | Mean (SD)")

# 文字ベクタ（明示的）
add_table(..., col_header = c("Treatment", "N", "Mean (SD)"))

# 複数ヘッダー行（ネストしたリスト）
add_table(..., col_header = list(
  c("", "Arm A", "Arm B"),
  c("Item", "N", "Mean", "N", "Mean")
))
```

**実装上の考慮点**:
- ヘッダー行数分だけ `\trowd...\row` ブロックを繰り返す
- 各ヘッダー行の列幅は本体テーブルと同じ `\cellx` 位置を使う（ずれ防止）
- 空文字セルは空白セルとしてレンダリングする（列構造を維持するため）

---

#### A-2. スパニングヘッダー（結合ヘッダー）

**概要**: 複数列にまたがるヘッダーを指定できるようにする。RTFでは列結合そのものは存在しないため、「幅を合計したセル + 下線」で視覚的に再現する（reporter方式のアイデアを転用、コードは独自実装）。

**想定API**:
```r
add_table(...,
  col_header = c("Item", "N", "Mean", "N", "Mean"),
  spanning_header = list(
    list(from = 2, to = 3, label = "Arm A", underline = TRUE),
    list(from = 4, to = 5, label = "Arm B", underline = TRUE)
  )
)
```

**実装上の考慮点**:
- スパニングヘッダー行のセルは「from〜to列の累計幅」を `\cellx` 位置として計算する
- 下線は `\uldb`（太下線）または `\ul`（細下線）を文字装飾で付与する（罫線は使わない）
- 空スパン領域（スパン外の列）は空セルで対応
- 複数段のスパン（level指定）を将来的にサポートできる設計にする

---

### B. 罫線制御の全面見直し

**現状の問題**: 罫線はフッター上線のみで、本体テーブルには罫線が実装されていない。

#### B-1. セル単位の罫線指定

**概要**: テーブル全体・行・セル単位で4辺の罫線を独立して指定できるようにする。「完全に消す」ことも明示的に行える。

**想定API（メタデータ方式）**:
```r
add_table(..., metadata = list(
  border = list(
    header = list(top = "single", bottom = "double", left = "none", right = "none"),
    body   = list(top = "none",   bottom = "none",   left = "none", right = "none"),
    first_row = list(top = "single"),
    last_row  = list(bottom = "single")
  )
))
```

**罫線種別（RTFコマンド対応）**:

| 指定値 | RTFコマンド | 説明 |
|--------|-------------|------|
| `"none"` | （コマンドなし） | 罫線なし（完全消去）|
| `"single"` | `\brdrs` | 細線 |
| `"double"` | `\brdrdb` | 二重線 |
| `"thick"` | `\brdrth` | 太線 |
| `"dash"` | `\brdrdash` | 破線 |
| `"dot"` | `\brdrdot` | 点線 |

**重要**: `"none"` のとき該当の `\clbrdrl` 等のコマンド自体を出力しない（R2RTFでは空文字を出力しており不安定）。

**デフォルト設定（Clinical TFL標準）**:
```
header: top=single, bottom=single, left=none, right=none
body:   top=none,   bottom=none,   left=none, right=none
first_row: top=single
last_row:  bottom=single
```

---

#### B-2. 罫線幅の指定

**概要**: 罫線幅をtwips単位で指定できるようにする。

```r
border = list(
  header = list(top = "double", top_width = 20, bottom = "single", bottom_width = 15)
)
```

RTFコマンド: `\clbrdrt\brdrdb\brdrw20`

---

### C. セル書式の充実

#### C-1. テキスト装飾（列単位・セル単位）

**概要**: 列またはセル単位でテキストの装飾を指定できるようにする。

**想定API**:
```r
# 列定義でのスタイル指定
col_spec = list(
  list(col = "label",  bold = TRUE, align = "left"),
  list(col = "value1", align = "right", format = "%.1f"),
  list(col = "value2", italic = TRUE, align = "right")
)
add_table(..., col_spec = col_spec)
```

**サポートする装飾**:

| 属性 | RTFコマンド | デフォルト |
|------|-------------|-----------|
| `bold` | `\b...\b0` | `FALSE` |
| `italic` | `\i...\i0` | `FALSE` |
| `underline` | `\ul...\ulnone` | `FALSE` |
| `align` | `\ql` / `\qr` / `\qc` | `"left"` |
| `indent_twips` | `\li{n}` | `0` |

**フォントカラーは将来拡張**として設計だけ予約する（カラーテーブルの管理が複雑なため）。

---

#### C-2. セル内インデント（階層表示用）

**概要**: 変数値に応じてセルの左インデントを変えることで、階層的なリスティングを表現する。

```r
# 行ごとのインデント指定（twips単位）
add_table(..., col_spec = list(
  list(col = "label", indent_by_col = "indent_level", indent_unit_twips = 360)
  # indent_level列の値×360twipsで左インデントを設定
))
```

RTFコマンド: `\li720` （1レベル = 720twips = 0.5インチ）

---

### D. 行高・余白の改善

#### D-1. 行高をフォントサイズから独立させる

**現状**: `table_cell_height_twips` は定数として設定可能だが、報告書全体で固定。

**改善案**: 行ごとに異なる高さを指定できるようにする。

```r
add_table(..., metadata = list(
  row_height_twips = 240,        # デフォルト行高
  header_row_height_twips = 300  # ヘッダー行の高さ
))
```

**重要**: reporter のように「フォントサイズ × 係数」で行高を自動計算するのは**行わない**。行高は常に明示的なtwips値で指定する。  
行高が不明なときのデフォルトは `0`（RTFリーダーの自動調整）を使う。

RTFコマンド: `\trrh0`（高さ0 = 自動）または `\trrh240`（固定値）

---

#### D-2. セル内上下余白（セルパディング）

**概要**: セル内の左右余白（インデント）は `\li`/`\ri` で対応済み。上下余白については RTF の `\clpadb`/`\clpadt` コマンドで対応する。

```r
metadata = list(
  cell_padding = list(top = 0, bottom = 0, left = 72, right = 72)  # twips
)
```

RTFコマンド: `\clpadl72\clpadr72\clpadt0\clpadb0`（Word対応の独自拡張コマンド）

---

### E. Unicode・特殊文字対応の強化

#### E-1. Unicode文字の安定的なエスケープ

**現状**: `{` `}` `\` のエスケープのみ。マルチバイト文字が入るとRTFが壊れる可能性。

**改善案**: ASCII範囲外の文字を `\u{codepoint}?` 形式に変換するユーティリティを実装する。

```r
# 内部ユーティリティ
.rtf_escape_unicode <- function(x) {
  # 非ASCII文字を \uNNNN? 形式に変換
  # ASCIIは既存の {, }, \ エスケープのみ
}
```

RTFコマンド例:  
- `α` → `\u945?`  
- `≥` → `\u8805?`  
- 日本語 `表` → `\u34920?`

**R2RTFのアプローチを参考に**（コードは独自実装）: コードポイントを取得して `sprintf("\\u%d?", codepoint)` で変換する。

---

#### E-2. 特殊記法のサポート

**概要**: Clinical TFL でよく使われる記法を自動変換する。

| 入力 | RTF出力 | 表示 |
|------|---------|------|
| `{PAGE}` | `\chpgn` | 現在ページ番号（既存） |
| `{TOTAL_PAGES}` | `{\field{\*\fldinst NUMPAGES}}` | 総ページ数（既存） |
| `\n` | `\line ` | 改行 |
| `^{text}` | `{\super text}` | 上付き文字 |
| `_{text}` | `{\sub text}` | 下付き文字 |
| `>=` | `\u8805?` | ≥ |
| `<=` | `\u8804?` | ≤ |

---

### F. RTFコマンドの安定化

#### F-1. コマンドリソースの整理・拡充

**現状**: `rtf_commands.R` に主要コマンドはあるが、罫線・セル書式が不足。

**追加すべきコマンドテンプレート**:

```r
# 罫線（4辺独立）
border_top_template    = "\\clbrdrt\\{style}\\brdrw{width}"
border_bottom_template = "\\clbrdrb\\{style}\\brdrw{width}"
border_left_template   = "\\clbrdrl\\{style}\\brdrw{width}"
border_right_template  = "\\clbrdrr\\{style}\\brdrw{width}"

# テキスト装飾
bold_on    = "\\b "
bold_off   = "\\b0 "
italic_on  = "\\i "
italic_off = "\\i0 "
underline_on  = "\\ul "
underline_off = "\\ulnone "
superscript_on  = "\\super "
superscript_off = "\\nosupersub "
subscript_on    = "\\sub "
subscript_off   = "\\nosupersub "

# セル垂直配置
cell_valign_top    = "\\clvertalt"
cell_valign_center = "\\clvertalc"
cell_valign_bottom = "\\clvertalb"

# 行設定
row_keep_together = "\\trkeep"   # 改ページで行を分割しない
```

---

#### F-2. RTF出力の妥当性検証

**概要**: 生成したRTFコマンド列が正しく閉じられているかを生成時に検証する軽量チェック機能。

```r
# 内部検証（generate_rtfreport 末尾で実行）
.validate_rtf_output <- function(rtf_lines) {
  # 1. 開き波括弧と閉じ波括弧の数が一致するか
  # 2. \trowd と \row の対応が取れているか
  # 3. \cell の数と \cellx の数が一致するか
  # 警告として出力（エラーにはしない）
}
```

---

#### F-3. セクション区切りコマンドの確認

**現状**: `\sect` がリソースにあるが、セクションごとのページ設定変更（用紙サイズ、余白、向き）が未実装。

**改善案**: セクション内で用紙サイズ・向き・余白を変更できるようにする。

```r
add_section(..., 
  page = list(
    orientation = "portrait",  # このセクションだけ縦向き
    margin_left_twips = 1440
  )
)
```

RTFコマンド: `\sect\sectd\paperw12240\paperh15840` （セクション後に設定変更）

---

### G. 相対列幅のサポート

**現状**: 列幅はtwips絶対値か、テーブル幅に対する均等分割のみ。

**改善案**: R2RTFの `col_rel_width` のように相対比率で列幅を指定できるようにする。

```r
add_table(..., metadata = list(
  col_rel_width = c(3, 1, 1, 2)  # 3:1:1:2 の比率で分割
  # table_width_pct_of_writable = 90 と組み合わせ可能
))
```

計算式: `cellx[i] = table_width_twips * sum(rel[1:i]) / sum(rel)`

---

## 優先度まとめ

| # | 機能 | 分類 | 優先度 | 理由 |
|---|------|------|--------|------|
| A-1 | 手動列ヘッダー指定 | テーブル | **高** | Clinical TFLの基本要件 |
| B-1 | セル単位罫線制御 | 罫線 | **高** | 現在ほぼ未実装 |
| C-1 | テキスト装飾（Bold等）| 書式 | **高** | ヘッダーBoldのみでは不足 |
| F-1 | コマンドリソース拡充 | 安定化 | **高** | 他機能の土台 |
| G | 相対列幅 | レイアウト | **高** | 使い勝手向上 |
| A-2 | スパニングヘッダー | テーブル | 中 | 必要度は高いが実装複雑 |
| C-2 | セル内インデント | 書式 | 中 | Listing用途で有用 |
| D-1 | 行高改善 | レイアウト | 中 | 現状定数で概ね対応済み |
| E-1 | Unicode強化 | 文字 | 中 | 日本語対応で必要 |
| E-2 | 特殊記法変換 | 文字 | 中 | 利便性向上 |
| B-2 | 罫線幅指定 | 罫線 | 低 | B-1の拡張 |
| D-2 | セル内上下余白 | レイアウト | 低 | 微調整用途 |
| F-2 | RTF出力検証 | 安定化 | 低 | デバッグ支援 |
| F-3 | セクション別ページ設定 | セクション | 低 | 混在文書向け |

---

## 見習わない点（明示的にNGとする設計）

1. **reporterのフォントサイズ依存の行高計算** → すべてtwips明示値またはRTF自動（`\trrh0`）
2. **reporterのテキスト→RTF変換経由の生成** → RTFコマンドを直接構築する方針を維持
3. **R2RTFの罫線"空文字"=なし** → `"none"`時は該当コマンドを出力しない
4. **両者の列幅px/pt依存計算** → twips統一、変換はユーティリティ関数に閉じ込める
5. **セクション概念の欠如** → rtfreporterの階層構造を崩さない

---

---

## 実装仕様（2026-05-15 承認済み）

### クラス設計

```
rtftable  (R6)   ← データテーブル専用オブジェクト
rtfplot   (R6)   ← 図（PNG/JPEG埋め込み）専用オブジェクト
rtfreport (R6)   ← 変更なし（Document→Section→Page→Block 階層）
```

`add_table(sec, page, data)` の `data` 引数に `rtftable` を渡せる。
従来の `data.frame + metadata` も後方互換で動作（`"tfl"` デフォルト罫線が付与される）。

### rtftable API確定仕様

```r
rtftable$new(
  data,
  col_header   = NULL,          # NULL(列名使用) | 文字ベクタ | リスト（複数行）
                                #   "A | B | C" のパイプ区切り文字列も可
  spanning_header = NULL,       # list(list(from=2,to=3,label="Arm A",underline=TRUE))
  col_spec     = NULL,          # list(list(col=1,align="left",bold=TRUE),...)
                                #   col は列番号(int) or 列名(chr)
                                #   属性: align,bold,italic,underline,indent_twips
                                #         header_bold,header_align,header_italic
  border       = "tfl",         # "tfl"(デフォルト) | NULL(なし) | list(部分上書き)
  col_rel_width = NULL,         # 相対幅 c(3,1,1,2) ← 合計比率
  column_widths_twips = NULL,   # 絶対幅 (優先度最高)
  table_width_twips = NULL,
  table_width_pct_of_writable = NULL,
  row_height_twips = 0L,        # 0=自動(RTFリーダー決定), 正=最小, 負=固定
  header_row_height_twips = NULL,
  cell_padding_left_twips  = 72L,  # 0.05" 左右余白（上下は row_height で制御）
  cell_padding_right_twips = 72L,
  cell_valign  = "bottom"       # "top"|"center"|"bottom"
)
```

### border仕様

```r
# border = "tfl" のデフォルト値
list(
  header    = list(top="single", bottom="single", left="none", right="none", width=15L),
  spanning  = list(top="none",   bottom="none",   left="none", right="none", width=15L),
  body      = list(top="none",   bottom="none",   left="none", right="none", width=15L),
  first_row = list(),
  last_row  = list(bottom="single")
)

# border = NULL → 罫線コマンド一切出力しない
# border = list(header=list(top="double")) → TFLデフォルトへの部分上書き

# border種別
# "none"   → コマンド出力なし（完全消去）
# "single" → \brdrs
# "double" → \brdrdb
# "thick"  → \brdrth
# "dash"   → \brdrdash
# "dot"    → \brdrdot
```

### col_spec仕様

```r
col_spec = list(
  list(col = 1,     align = "left"),
  list(col = "SEX", align = "center", bold = FALSE),
  list(col = 3,     header_bold = TRUE, header_align = "center")
)
# col: 列番号(int) または 列名(chr)
# 未指定の属性はデフォルト値（align="left", bold=FALSE, header_bold=TRUE等）
```

### テキスト処理パイプライン

全セルテキストに以下を適用:
1. `^{text}` → `{\super text}` （上付き）
2. `_{text}` → `{\sub text}` （下付き）
3. `\n`（改行文字）→ `\line `
4. `>=` → `\u8805?`（≥）
5. `<=` → `\u8804?`（≤）
6. `\`, `{`, `}` → RTFエスケープ
7. 非ASCII文字 → `\uNNNN?`

### 行高とセル余白の関係

- `row_height_twips` = `\trrh` コマンドのみで行高を制御
- 上下セル余白は**公開しない**（`\trrh` と競合するため）
- 左右セル余白は `cell_padding_left_twips`/`cell_padding_right_twips` で `\li`/`\ri` に反映
- `col_spec$indent_twips` は `\li` に加算（階層インデント用）

### rtfplot API

```r
rtfplot$new(
  path,                      # PNG または JPEG ファイルパス
  width_twips  = NULL,       # NULL = 書き込み可能幅に合わせる
  height_twips = NULL,       # NULL = アスペクト比を維持
  align        = "center"    # "left"|"center"|"right"
)
# RTF \pict コマンドで実ファイルをバイナリ埋め込み（Hex形式）
```

### 新規・更新ファイル

| ファイル | 種別 |
|---------|------|
| `R/rtftable.R` | 新規 |
| `R/rtfplot.R` | 新規 |
| `inst/resources/rtf_commands.R` | 更新（罫線・装飾コマンド追加） |
| `R/generate_rtfreport.R` | 大幅更新（レンダリング刷新） |
| `R/rtfreport.R` | 軽微更新（validate拡張） |
| `tests/test_rtfreport.R` | 更新（新機能テスト追加） |

*以上の仕様で実装します。*
