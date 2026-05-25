# Release Guidelines for rtfreporter

このドキュメントはエージェント（GitHub Copilot等）が GitHub Release を作成・管理する際の注意事項をまとめたものです。

---

## リポジトリ構成

```
rtfreporter/             ← Git リポジトリルート = R パッケージルート
├── DESCRIPTION
├── NAMESPACE
├── r/                   ← R ソースファイル
├── inst/resources/      ← RTF コマンドリソース
├── tests/               ← テストスクリプト
├── vignettes/
│   ├── *.Rmd            ← ユーザー向けビニェット
│   └── articles/
│       ├── internal-design.qmd   ← 内部クラス設計書
│       └── external-api.qmd      ← 外部 API 仕様書
└── specs/
    └── release_guidelines.md     ← このファイル
```

---

## GitHub Release 作成手順

### 1. バージョン表記のルール

| 対象 | 形式 | 例 |
|------|------|----|
| GitHub タグ / Release 名 | `vX.Y.Z` | `v0.1.0` |
| R の `DESCRIPTION` の `Version` | **数字とピリオドのみ**（サフィックス不可） | `0.1.0` |

> ⚠️ **重要**: R の `DESCRIPTION` に `Version: 0.1.0-alpha` のようにサフィックスを付けると
> `Malformed package version` エラーになる。

### 2. ビニェットの事前ビルド

```powershell
# from repo root
cd C:\Yrepo\rtfreporter

# 1. ビルド
Rscript -e "devtools::build_vignettes()"

# 2. inst/doc/ にコピー
Copy-Item "doc\*" "inst\doc\" -Recurse -Force

# 3. 確認
Rscript -e "devtools::install(); vignette(package='rtfreporter')"
```

### 3. インストール用 tar.gz の作成

```powershell
# リポジトリルートの親ディレクトリから実行
cd C:\Yrepo
tar -czf rtfreporter_X.Y.Z.tar.gz rtfreporter
```

### 4. GitHub Release へのアップロード

```powershell
cd C:\Yrepo\rtfreporter
gh release create vX.Y.Z rtfreporter_X.Y.Z.tar.gz --title "vX.Y.Z" --notes "See CHANGELOG.md"
```

---

## ユーザー向けインストール方法

```r
# GitHub からのインストール
remotes::install_github("ichirio/rtfreporter")

# または Release tar.gz から
url <- "https://github.com/ichirio/rtfreporter/releases/download/vX.Y.Z/rtfreporter_X.Y.Z.tar.gz"
install.packages(url, repos = NULL, type = "source")
```

---

## リリース前チェックリスト

- [ ] `DESCRIPTION` の `Version` が数字のみか確認
- [ ] `CHANGELOG.md` を更新したか確認
- [ ] ビニェットを `inst/doc/` にビルド済みHTMLとして配置したか確認
- [ ] テストがすべてパスするか確認（`Rscript tests/test-rtf-generation.R`）
- [ ] `NAMESPACE` が最新か確認（`roxygen2::roxygenise()` 実行済み）
- [ ] `man/` ドキュメントが最新か確認

---

## バージョン管理ポリシー

- バージョン形式: `major.minor.patch`（例: 0.1.0、0.1.1、0.2.0）
- CHANGELOG: **v0.1.0 以降のみ記録**、開発版変更は不記録
- 破壊的変更: minor バージョンを上げる（0.1.x → 0.2.0）
- バグ修正: patch バージョンを上げる（0.1.0 → 0.1.1）
