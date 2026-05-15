# ydisctools 機能調査・取り込み提案
**作成日**: 2026-05-16  
**対象**: `C:\Yrepo\Rrepo\ydisctools\R\r2rtf_tools.R`  
**方針**: ydisctools から **アイデアのみ** 取り込み、コードはゼロから書く。r2rtf 依存を一切持ち込まない。

---

## 調査概要

ydisctools は r2rtf のラッパーとして高機能な Clinical TFL 生成機能を持つ。  
rtfreporter との主な違い:

| 観点 | ydisctools | rtfreporter |
|------|-----------|-------------|
| 依存 | r2rtf 必須 | 依存なし |
| RTF 生成 | r2rtf に委譲 | 独自レンダラー |
| セクション | なし（ページのみ） | Document→Section→Page 階層 |
| フォントサイズ依存行高 | あり（問題）| なし（\trrh のみ）|
| 空白行挿入 | `rtf_blank_rows` 属性 | `blank_rows` パラメータ（実装済）|

---

## 取り込み候補機能

### ★★★ 高優先度

#### H-2: `assemble_rtf()` — 複数 RTF ファイルを一つに結合
- **概要**: 複数の独立した RTF ファイルを一つの RTF に連結する。各ファイルはセクション区切りで繋ぐ。
- **用途**: TFL セット（T14.1.1, T14.2.1, …）を単一 RTF に一括出力する場合。
- **実装アイデア**:
  - `assemble_rtf(input = c("t1.rtf","t2.rtf"), output = "combined.rtf")`
  - 各ファイルの `{\rtf1...}` ブロックを解析し、文書ヘッダー（フォントテーブル等）は最初の 1 つだけ使う。
  - セクション間に `\pard\sect` を挿入。
  - ydisctools の `assemble_rtf()` では「白ページ」オプション（セクション間に空ページ）も持つ。
  - ページ番号を全体通番にするか、セクション別に振るかも制御できるとよい。
- **優先度**: ★★★（臨床試験のTFLパッケージ生成に必須）

#### H-3: RTF ページフィールド (`{PAGE}` / `{NUMPAGES}`)
- **概要**: ページ番号を真の RTF フィールドとして埋め込む。
- **現状**: rtfreporter はヘッダーに `{PAGE}` と書くとリテラル文字列になってしまう。
- **実装アイデア**:
  - `{PAGE}` → `{\field{\*\fldinst { PAGE }}{\fldrslt 1}}`
  - `{TOTAL_PAGES}` → `{\field{\*\fldinst { NUMPAGES }}{\fldrslt 1}}`
  - `{SECTION_PAGES}` → `{\field{\*\fldinst { SECTIONPAGES }}{\fldrslt 1}}`
  - `generate_rtfreport.R` の `.format_cell_text()` でプレースホルダーを置換する。
- **優先度**: ★★★（ページ番号の正確な表示は帳票の基本要件）

---

### ★★ 中優先度

#### I-1: `text_width()` — フォント別文字幅推定
- **概要**: テキスト文字列の表示幅をポイント単位で推定する。列幅の自動計算に使用。
- **対象フォント**: Courier New（等幅：1文字 = 7.22pt）、Arial（プロポーショナル：文字ごとに幅テーブル）。
- **実装アイデア**:
  - `text_width(text, font = "courier_new")` → 幅（インチ）
  - Courier New は簡単：`nchar(text) * 7.22 / 72`
  - Arial は文字別幅テーブル（ydisctools が定義済み）を参考に独自定義
  - `auto_col_widths(df, font = "courier_new", margin_inch = 0.1)` で列幅自動計算
- **用途**: ユーザーが `col_rel_width` を指定しないときのデフォルト幅計算。
- **優先度**: ★★（使い勝手が大幅向上）

#### I-2: `pageby` — グループ変数によるページ分割 + ヘッダー繰り返し
- **概要**: データのグループ変数（例: `VISITNUM`）が変わるたびに改ページし、各ページでカラムヘッダーを繰り返す。
- **用途**: Visit-by-visit の Adverse Event listing など。
- **実装アイデア**:
  - `rtftable$new(df, pageby = "VISITNUM")` で指定
  - グループごとに別々の `\trowd...\row` ブロックを生成し、ページ間で `\page` を挿入
  - グループラベル行（太字・全幅スパン）を各グループ先頭に自動挿入するオプションも追加
- **優先度**: ★★（Listing 用途では重要）

#### I-3: セル背景色 (`cell_background_color`)
- **概要**: セル単位または列単位に背景色（ハイライト）を指定する。
- **RTFコマンド**: `\clcbpat{N}` (color table index)
- **実装アイデア**:
  - `col_spec` に `bg_color = "#FFFF00"` を追加
  - RTF カラーテーブル（`{\colortbl...}`）に色を登録し、`\clcbpat` で参照
  - 安全なデフォルト: 背景色なし（空文字）
- **用途**: Odd/even 行の縞模様、特定値のハイライト。
- **優先度**: ★★

#### I-4: グループ見出し行 (sub-row / group label row)
- **概要**: データ行とは別に、グループ境界に「見出し専用行」を挿入する。  
  ydisctools では `rtf_by_subline` に相当。
- **実装アイデア**:
  - `blank_rows` と同様の仕組みで `group_label_rows` パラメータを追加
  - `group_label_rows = list(list(after = 0, label = "Group A", bold = TRUE))` のような指定
  - あるいは `data` 自体にグループ行を含め、`col_spec` で特定行を bold 化する（現行 API で対応可能）
- **優先度**: ★★

---

### ★ 低優先度（将来検討）

#### J-1: 複数フォント対応（フォントテーブル拡張）
- **概要**: フォントテーブルに複数フォントを登録し、セル・列単位でフォントを切り替える。
- **現状**: rtfreporter は `\f0` (Times New Roman) / `\f3` (Arial) を想定しているが、フォントテーブルは固定。
- **実装アイデア**: `default_font = "Courier New"` をセクションレベルで指定可能にする。
- **優先度**: ★

#### J-2: 用紙サイズ自動設定 (`get_paper_dimension()`)
- **概要**: "letter", "a4", "a3" など文字列で用紙サイズを指定する。
- **現状**: rtfreporter では `paper_width_inches`, `paper_height_inches` を直接指定。
- **実装アイデア**: `page_size = "letter"` のショートカットを追加。
- **優先度**: ★

#### J-3: テキスト折り返し幅制限 (`split_column_by_max_bytes`)
- **概要**: セル内テキストが指定バイト数を超えたら自動的に折り返す。
- **用途**: Listing で極端に長い文字列が列幅を崩さないように。
- **優先度**: ★

---

## 実装しない機能

以下は ydisctools にあるが rtfreporter では実装しない：

| 機能 | 理由 |
|------|------|
| `r2rtf_*` 系ラッパー | r2rtf 依存を避けるため |
| フォントサイズ→行高マッピング | 設計上のアンチパターン（`\trrh` で直接指定） |
| `rtf_encode_figure()` の r2rtf 呼び出し | rtfplot クラスで代替済み |
| `as_rtf_section()` の r2rtf セクション構造 | rtfreporter の独自セクション階層で対応済み |

---

## 実装済みの機能（本セッション）

| ID | 機能 | 状態 |
|----|------|------|
| H-1 | 空白行挿入 (`blank_rows`) | ✅ 実装済み（2026-05-16）|
| A-1 | 手動列ヘッダー | ✅ 実装済み |
| A-2 | スパニングヘッダー | ✅ 実装済み |
| B-1 | セル単位罫線制御 | ✅ 実装済み |
| C-1 | テキスト装飾 | ✅ 実装済み |
| C-2 | セル内インデント | ✅ 実装済み |
| E-1/E-2 | Unicode 強化・特殊記法変換 | ✅ 実装済み |
| G | 相対列幅 | ✅ 実装済み |

---

## 推奨実装順序（次フェーズ）

1. **H-3** RTF ページフィールド（`{PAGE}` が現在リテラル文字）— 影響大・実装容易
2. **H-2** `assemble_rtf()` — TFL パッケージ生成に必須
3. **I-1** `text_width()` — 列幅の自動計算（使い勝手向上）
4. **I-2** `pageby` — Listing 系で重要
5. **I-3** セル背景色 — 視覚的な差別化

---

*本ドキュメントは将来の実装計画であり、優先度は利用状況により変更することがある。*
