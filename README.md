# rtfreporter
Generate TFLs as RTF reports.

A cross-language toolkit for creating RTF reports.

## Repository layout

- `r/rtfreporter`: R package (CRAN target)
- `python`: Python package (PyPI target)
- `specs`: shared API contracts for parity tests
- `.github/workflows`: CI for both language implementations

## Quick start

### Python

```bash
cd python
pip install -e .
pytest
```

### R

```r
setwd("r/rtfreporter")
source("R/hello.R")
hello_rtfreporter()
```

## Release strategy

- Publish `r/rtfreporter` to CRAN
- Publish `python` to PyPI as `rtfreporter`
- Keep behavior aligned using `specs/api_contract.md`
