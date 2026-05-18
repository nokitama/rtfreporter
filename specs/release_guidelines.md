# Release Guidelines for rtfreporter

このドキュメントはエージェント（GitHub Copilot等）が GitHub Release を作成・管理する際の注意事項をまとめたものです。

---

## リポジトリ構成

```
rtfreporter/
├── r/rtfreporter/   ← Rパッケージ（DESCRIPTION, NAMESPACE, R/, man/ など）
├── python/          ← Pythonパッケージ（pyproject.toml, src/ など）
└── specs/
```

RとPythonは**同一リポジトリ内に共存**しており、それぞれ独立したパッケージとして管理する。

---

## GitHub Release 作成手順

### 1. バージョン表記のルール

| 対象 | 形式 | 例 |
|------|------|----|
| GitHub タグ / Release 名 | `vX.Y.Z-alpha` などサフィックスOK | `v0.0.2-alpha` |
| R の `DESCRIPTION` の `Version` | **数字とピリオドのみ**（サフィックス不可） | `0.0.2` |
| Python の `pyproject.toml` の `version` | PEP 440 準拠（`0.0.2a1` など） | `0.0.2a1` |

> ⚠️ **重要**: R の `DESCRIPTION` に `Version: 0.0.2-alpha` のようにサフィックスを付けると
> `Malformed package version` エラーになる。GitHub タグと R バージョンは別管理。

### 2. インストール用アセットの作成

GitHub Release には**RとPython個別のtar.gzをアセットとして添付**する。
リポジトリ全体の自動生成tar.gz（`Source code`）は使わない（サブディレクトリにパッケージがあるため）。

#### Rパッケージ

```powershell
# r/rtfreporter ディレクトリのみをパッケージング
tar -czf rtfreporter_X.Y.Z.tar.gz -C "r" "rtfreporter"
```

命名規則: `rtfreporter_X.Y.Z.tar.gz`（例: `rtfreporter_0.0.2.tar.gz`）

#### Pythonパッケージ

```powershell
# python ディレクトリをパッケージング
tar -czf rtfreporter_python_X.Y.Z.tar.gz -C "." "python"
```

命名規則: `rtfreporter_python_X.Y.Z.tar.gz`（例: `rtfreporter_python_0.0.2.tar.gz`）

### 3. アップロード

```powershell
gh release upload vX.Y.Z-alpha rtfreporter_X.Y.Z.tar.gz rtfreporter_python_X.Y.Z.tar.gz
```

---

## ユーザー向けインストール方法

### R

```r
url <- "https://github.com/ichirio/rtfreporter/releases/download/vX.Y.Z-alpha/rtfreporter_X.Y.Z.tar.gz"
download.file(url, "rtfreporter_X.Y.Z.tar.gz")
devtools::install_local("rtfreporter_X.Y.Z.tar.gz")
```

### Python

```bash
pip install https://github.com/ichirio/rtfreporter/releases/download/vX.Y.Z-alpha/rtfreporter_python_X.Y.Z.tar.gz
```

---

## チェックリスト（リリース前確認）

- [ ] `r/rtfreporter/DESCRIPTION` の `Version` が数字のみか確認
- [ ] R用 tar.gz を `r/` ディレクトリのみで作成したか確認
- [ ] Python用 tar.gz を `python/` ディレクトリのみで作成したか確認
- [ ] 両アセットを Release にアップロードしたか確認
- [ ] 作業用の一時 tar.gz ファイルを削除したか確認
