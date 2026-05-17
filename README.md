# rtfreporter (R package)

This package provides RTF report generation features specialized for clinical tables and listings. It is not a general-purpose RTF library, but is focused on the needs of clinical trial reporting (TFLs).

Currently, only RTF output is supported. In the future, embedding objects from table creation tools (e.g., rtables, huxtable) will be implemented.

## Main Functions

- `rtfreport`: Create and manage RTF report objects
- `generate_rtfreport`: Output to RTF file
- `rtftable`: Table object (data.frame + formatting)
- `rtfplot`: Embed PNG/JPEG images into RTF
- `hello_rtfreporter`: Simple greeting for testing

---

Cross-language RTF reporting toolkit - R implementation.
