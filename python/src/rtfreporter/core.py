from __future__ import annotations

import json
import os
from importlib.resources import files
from typing import Any, Optional


def hello_rtfreporter() -> str:
    """Return a greeting string from the Python package."""
    return "Hello from rtfreporter (Python)"


# ---------------------------------------------------------------------------
# Internal utilities
# ---------------------------------------------------------------------------

def _in_to_twips(x: float) -> int:
    return int(round(x * 1440))


def _load_rtf_commands() -> dict[str, Any]:
    resource_path = files("rtfreporter").joinpath("resources/rtf_commands.json")
    with resource_path.open("r", encoding="ascii") as f:
        return json.load(f)


RTF_COMMANDS = _load_rtf_commands()


def _merge_dict(base: dict, override: dict) -> dict:
    out = dict(base)
    for k, v in override.items():
        out[k] = v
    return out


def _cmd_fmt(template: str, values: Optional[dict[str, Any]] = None) -> str:
    out = template
    if not values:
        return out
    for key, value in values.items():
        out = out.replace("{" + str(key) + "}", str(value))
    return out


def _assert_index(x: Any, max_value: int, label: str) -> int:
    if not isinstance(x, (int, float)) or x != int(x) or int(x) < 1 or int(x) > max_value:
        raise ValueError(f"{label} is out of range.")
    return int(x)


def _rtf_escape(x: Optional[str]) -> str:
    if x is None:
        return ""
    x = str(x)
    x = x.replace("\\", "\\\\")
    x = x.replace("{", "\\{")
    x = x.replace("}", "\\}")
    return x


def _render_tokens(
    x: Optional[str],
    current_page: Optional[int] = None,
    total_pages: Optional[int] = None,
) -> str:
    if x is None:
        return ""
    out = str(x)
    if current_page is not None:
        out = out.replace("{PAGE}", str(current_page))
    if total_pages is not None:
        out = out.replace("{TOTAL_PAGES}", str(total_pages))
    return _rtf_escape(out)


def _render_header_footer(
    hf: Optional[dict],
    writable_width_twips: int,
    is_footer: bool = False,
    current_page: Optional[int] = None,
    total_pages: Optional[int] = None,
) -> list[str]:
    """Render header/footer rows to RTF table row strings.

    hf structure::

        {
            "rows": [
                {"columns": {"l": "left", "r": "right"}},  # 2-column
                {"columns": {"c": "center"}},               # 1-column center
                {"columns": {"l": "left"}},                 # 1-column left
            ],
            "width_twips": None,   # or integer
            "top_border":  False,  # or True
        }
    """
    if hf is None or not hf.get("rows"):
        return []

    rows = hf["rows"]
    top_border = bool(hf.get("top_border", False))
    width = hf.get("width_twips") or writable_width_twips

    out_rows: list[str] = []
    table_cmd = RTF_COMMANDS["table"]
    align_cmd = RTF_COMMANDS["alignment"]

    for row_idx, row_def in enumerate(rows):
        cols = row_def.get("columns") if isinstance(row_def, dict) else row_def
        if not cols:
            cols = {}

        # Determine columns and alignment from named dict keys (l/r/c)
        if isinstance(cols, dict):
            has_l = "l" in cols
            has_r = "r" in cols
            has_c = "c" in cols

            if has_c:
                n_cols = 1
                aligns = ["center"]
                cols_display = [cols["c"]]
            elif has_l and has_r:
                n_cols = 2
                aligns = ["left", "right"]
                cols_display = [cols["l"], cols["r"]]
            elif has_l:
                n_cols = 1
                aligns = ["left"]
                cols_display = [cols["l"]]
            elif has_r:
                n_cols = 1
                aligns = ["right"]
                cols_display = [cols["r"]]
            else:
                # Fallback: plain values list from dict
                items = list(cols.values())
                n_cols = len(items) or 1
                if n_cols > 3:
                    raise ValueError("Header/footer supports up to 3 columns per row.")
                aligns = _default_aligns(n_cols, is_footer)
                cols_display = items
        else:
            # Sequence fallback
            items = list(cols)
            n_cols = len(items) or 1
            if n_cols > 3:
                raise ValueError("Header/footer supports up to 3 columns per row.")
            aligns = _default_aligns(n_cols, is_footer)
            cols_display = items

        cell_w = width // n_cols
        cellx = [cell_w * (i + 1) for i in range(n_cols)]

        apply_border = top_border and row_idx == 0

        row = table_cmd["row_start"]
        for cx in cellx:
            if apply_border:
                row += _cmd_fmt(table_cmd["cell_boundary_top_border_template"], {"cx": cx})
            else:
                row += _cmd_fmt(table_cmd["cell_boundary_template"], {"cx": cx})

        align_map = {
            "left": align_cmd["left"],
            "right": align_cmd["right"],
            "center": align_cmd["center"],
        }
        for i in range(n_cols):
            align_tag = align_map.get(aligns[i], align_cmd["default"])
            text = cols_display[i] if i < len(cols_display) else ""
            rendered = _render_tokens(text, current_page=current_page, total_pages=total_pages)
            row += _cmd_fmt(table_cmd["cell_text_aligned_template"], {"align": align_tag, "text": rendered})

        row += table_cmd["row_end"]
        out_rows.append(row)

    return out_rows


def _default_aligns(n_cols: int, is_footer: bool) -> list[str]:
    if n_cols == 1:
        return ["left"] if is_footer else ["center"]
    elif n_cols == 2:
        return ["left", "right"]
    else:
        return ["left", "center", "right"]


def _resolve_table_layout(
    ncol_df: int,
    writable_width_twips: int,
    metadata: Optional[dict[str, Any]],
) -> tuple[list[int], Optional[int]]:
    meta = metadata if isinstance(metadata, dict) else {}

    if "column_widths_twips" in meta and meta["column_widths_twips"] is not None:
        widths = [int(x) for x in list(meta["column_widths_twips"])]
        if len(widths) != ncol_df:
            raise ValueError("`column_widths_twips` length must match number of columns.")
    else:
        if meta.get("table_width_twips") is not None:
            table_width = int(meta["table_width_twips"])
        elif meta.get("table_width_pct_of_writable") is not None:
            pct = float(meta["table_width_pct_of_writable"])
            table_width = int(round(writable_width_twips * pct))
        else:
            table_width = int(writable_width_twips)

        cell_w = max(1, table_width // ncol_df)
        widths = [cell_w] * ncol_df

    cellx: list[int] = []
    running = 0
    for width in widths:
        running += int(width)
        cellx.append(running)

    row_height_twips: Optional[int] = None
    if meta.get("row_height_twips") is not None:
        row_height_twips = int(meta["row_height_twips"])

    return cellx, row_height_twips


def _resolve_block_metadata(
    default_format: dict[str, Any],
    page_options: Optional[dict[str, Any]],
    block: dict[str, Any],
) -> dict[str, Any]:
    resolved: dict[str, Any] = {}

    if default_format.get("table_cell_height_twips") is not None:
        resolved["row_height_twips"] = int(default_format["table_cell_height_twips"])
    if page_options and isinstance(page_options, dict):
        defaults = page_options.get("table_metadata_defaults")
        if isinstance(defaults, dict):
            resolved = _merge_dict(resolved, defaults)
    if block.get("metadata") and isinstance(block["metadata"], dict):
        resolved = _merge_dict(resolved, block["metadata"])

    return resolved


def _render_dataframe_table(df: Any, writable_width_twips: int, metadata: Optional[dict[str, Any]] = None) -> list[str]:
    """Render a pandas DataFrame as simple RTF table rows."""
    try:
        import pandas as pd
    except ImportError as exc:
        raise ImportError("pandas is required to render table/listing blocks.") from exc

    if not isinstance(df, pd.DataFrame):
        raise TypeError("Table/listing block requires a pandas DataFrame.")
    if df.shape[1] == 0:
        return [RTF_COMMANDS["paragraph"]["empty_table"]]

    ncol_df = df.shape[1]
    table_cmd = RTF_COMMANDS["table"]
    cellx, row_height_twips = _resolve_table_layout(ncol_df, writable_width_twips, metadata)

    lines: list[str] = []

    # Header row
    header_row = table_cmd["row_start"]
    if row_height_twips is not None:
        header_row += _cmd_fmt(table_cmd["row_height_template"], {"row_height_twips": row_height_twips})
    for cx in cellx:
        header_row += _cmd_fmt(table_cmd["cell_boundary_template"], {"cx": cx})
    for nm in df.columns:
        header_row += _cmd_fmt(table_cmd["header_cell_text_template"], {"text": _rtf_escape(str(nm))})
    header_row += table_cmd["row_end"]
    lines.append(header_row)

    # Data rows
    for _, row_data in df.iterrows():
        row = table_cmd["row_start"]
        if row_height_twips is not None:
            row += _cmd_fmt(table_cmd["row_height_template"], {"row_height_twips": row_height_twips})
        for cx in cellx:
            row += _cmd_fmt(table_cmd["cell_boundary_template"], {"cx": cx})
        for v in row_data:
            try:
                cell_str = "" if pd.isna(v) else str(v)
            except Exception:
                cell_str = "" if v is None else str(v)
            row += _cmd_fmt(table_cmd["cell_text_template"], {"text": _rtf_escape(cell_str)})
        row += table_cmd["row_end"]
        lines.append(row)

    return lines


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

class rtfreport:
    """RTF report object.

    Stores content in document -> section -> page hierarchy.
    Matches the R rtfreport R6 class API.
    """

    def __init__(
        self,
        font_table: Optional[list] = None,
        color_table: Optional[list] = None,
        default_page: Optional[dict] = None,
        default_header: Optional[dict] = None,
        default_footer: Optional[dict] = None,
        default_format: Optional[dict] = None,
    ) -> None:
        if font_table is None:
            font_table = [{"name": "Courier"}]
        if color_table is None:
            color_table = ["#000000"]
        if default_page is None:
            default_page = {
                "paper": "letter",
                "orientation": "landscape",
                "width_twips": _in_to_twips(11),
                "height_twips": _in_to_twips(8.5),
                "margin_top_twips": _in_to_twips(0.75),
                "margin_bottom_twips": _in_to_twips(0.75),
                "margin_left_twips": _in_to_twips(0.5),
                "margin_right_twips": _in_to_twips(0.5),
            }
        if default_header is None:
            default_header = {"rows": [], "width_twips": None}
        if default_footer is None:
            default_footer = {"rows": [], "width_twips": None, "top_border": True}
        if default_format is None:
            default_format = {
                "font_index": 0,
                "font_size_half_points": 18,
                "line_spacing": 1,
                "table_cell_height_twips": 240,
            }

        self.document: dict = {
            "font_table": font_table,
            "color_table": color_table,
            "default_page": default_page,
            "default_header": default_header,
            "default_footer": default_footer,
            "default_format": default_format,
        }
        self.sections: list[dict] = []

    # ------------------------------------------------------------------
    # Section methods
    # ------------------------------------------------------------------

    def add_section(self, header: Optional[dict] = None, footer: Optional[dict] = None) -> int:
        """Add a section and return its 1-based index."""
        self.sections.append({"header": header, "footer": footer, "pages": []})
        return len(self.sections)

    def get_section(self, section_index: int) -> dict:
        idx = _assert_index(section_index, len(self.sections), "section_index")
        return self.sections[idx - 1]

    def set_section_header(self, section_index: int, header: dict) -> "rtfreport":
        idx = _assert_index(section_index, len(self.sections), "section_index")
        self.sections[idx - 1]["header"] = header
        return self

    def set_section_footer(self, section_index: int, footer: dict) -> "rtfreport":
        idx = _assert_index(section_index, len(self.sections), "section_index")
        self.sections[idx - 1]["footer"] = footer
        return self

    # ------------------------------------------------------------------
    # Page methods
    # ------------------------------------------------------------------

    def add_page(
        self,
        section_index: int,
        title: Optional[str] = None,
        content: Optional[list] = None,
        footer_notes: Optional[str] = None,
        page_options: Optional[dict] = None,
    ) -> int:
        """Add a page to a section and return its 1-based index."""
        sec_idx = _assert_index(section_index, len(self.sections), "section_index")
        page: dict = {
            "title": title,
            "content": content if content is not None else [],
            "footer_notes": footer_notes,
            "page_options": page_options,
        }
        self.sections[sec_idx - 1]["pages"].append(page)
        return len(self.sections[sec_idx - 1]["pages"])

    def get_page(self, section_index: int, page_index: int) -> dict:
        sec_idx = _assert_index(section_index, len(self.sections), "section_index")
        sec = self.sections[sec_idx - 1]
        page_idx = _assert_index(page_index, len(sec["pages"]), "page_index")
        return sec["pages"][page_idx - 1]

    def set_page_title(self, section_index: int, page_index: int, title: str) -> "rtfreport":
        sec_idx = _assert_index(section_index, len(self.sections), "section_index")
        page_idx = _assert_index(page_index, len(self.sections[sec_idx - 1]["pages"]), "page_index")
        self.sections[sec_idx - 1]["pages"][page_idx - 1]["title"] = title
        return self

    def set_page_footer_notes(self, section_index: int, page_index: int, footer_notes: str) -> "rtfreport":
        sec_idx = _assert_index(section_index, len(self.sections), "section_index")
        page_idx = _assert_index(page_index, len(self.sections[sec_idx - 1]["pages"]), "page_index")
        self.sections[sec_idx - 1]["pages"][page_idx - 1]["footer_notes"] = footer_notes
        return self

    def set_page_options(self, section_index: int, page_index: int, page_options: dict) -> "rtfreport":
        sec_idx = _assert_index(section_index, len(self.sections), "section_index")
        page_idx = _assert_index(page_index, len(self.sections[sec_idx - 1]["pages"]), "page_index")
        self.sections[sec_idx - 1]["pages"][page_idx - 1]["page_options"] = page_options
        return self

    # ------------------------------------------------------------------
    # Block methods
    # ------------------------------------------------------------------

    def add_block(self, section_index: int, page_index: int, block: dict) -> "rtfreport":
        if not isinstance(block, dict) or block.get("type") is None:
            raise ValueError("`block` must be a dict with `type`.")
        sec_idx = _assert_index(section_index, len(self.sections), "section_index")
        page_idx = _assert_index(page_index, len(self.sections[sec_idx - 1]["pages"]), "page_index")
        self.sections[sec_idx - 1]["pages"][page_idx - 1]["content"].append(block)
        return self

    def add_table(
        self, section_index: int, page_index: int,
        data: Any, footer: Optional[str] = None, metadata: Optional[dict] = None,
    ) -> "rtfreport":
        return self.add_block(section_index, page_index,
                              {"type": "table", "data": data, "footer": footer, "metadata": metadata})

    def add_listing(
        self, section_index: int, page_index: int,
        data: Any, footer: Optional[str] = None, metadata: Optional[dict] = None,
    ) -> "rtfreport":
        return self.add_block(section_index, page_index,
                              {"type": "listing", "data": data, "footer": footer, "metadata": metadata})

    def add_figure(
        self, section_index: int, page_index: int,
        path: str, footer: Optional[str] = None, metadata: Optional[dict] = None,
    ) -> "rtfreport":
        return self.add_block(section_index, page_index,
                              {"type": "figure", "path": path, "footer": footer, "metadata": metadata})

    # ------------------------------------------------------------------
    # Document defaults
    # ------------------------------------------------------------------

    def set_document_defaults(
        self,
        font_table: Optional[list] = None,
        color_table: Optional[list] = None,
        default_page: Optional[dict] = None,
        default_header: Optional[dict] = None,
        default_footer: Optional[dict] = None,
        default_format: Optional[dict] = None,
    ) -> "rtfreport":
        if font_table is not None:
            self.document["font_table"] = font_table
        if color_table is not None:
            self.document["color_table"] = color_table
        if default_page is not None:
            self.document["default_page"] = _merge_dict(self.document["default_page"], default_page)
        if default_header is not None:
            self.document["default_header"] = _merge_dict(self.document["default_header"], default_header)
        if default_footer is not None:
            self.document["default_footer"] = _merge_dict(self.document["default_footer"], default_footer)
        if default_format is not None:
            self.document["default_format"] = _merge_dict(self.document["default_format"], default_format)
        return self

    def set_default_header(self, header: dict) -> "rtfreport":
        self.document["default_header"] = _merge_dict(self.document["default_header"], header)
        return self

    def set_default_footer(self, footer: dict) -> "rtfreport":
        self.document["default_footer"] = _merge_dict(self.document["default_footer"], footer)
        return self

    def set_default_page(self, page: dict) -> "rtfreport":
        self.document["default_page"] = _merge_dict(self.document["default_page"], page)
        return self

    def set_default_format(self, fmt: dict) -> "rtfreport":
        self.document["default_format"] = _merge_dict(self.document["default_format"], fmt)
        return self

    # ------------------------------------------------------------------
    # Validation
    # ------------------------------------------------------------------

    def validate(self) -> bool:
        if len(self.sections) == 0:
            raise ValueError("rtfreport must contain at least one section.")
        for i, sec in enumerate(self.sections, start=1):
            if len(sec["pages"]) == 0:
                raise ValueError(f"Section {i} must contain at least one page.")
            for j, page in enumerate(sec["pages"], start=1):
                if not isinstance(page["content"], list):
                    raise ValueError(f"Section {i} page {j} content must be a list.")
                for k, block in enumerate(page["content"], start=1):
                    if block.get("type") is None:
                        raise ValueError(f"Section {i} page {j} block {k} must define `type`.")
                    if block["type"] not in ("table", "listing", "figure"):
                        raise ValueError(f"Unsupported block type `{block['type']}`.")
                    if block["type"] in ("table", "listing") and block.get("data") is None:
                        raise ValueError(f"Section {i} page {j} block {k} requires `data`.")
                    if block["type"] == "figure" and block.get("path") is None:
                        raise ValueError(f"Section {i} page {j} block {k} requires `path`.")
        return True


def generate_rtfreport(report: rtfreport, file_path: str, overwrite: bool = False) -> str:
    """Convert an rtfreport object to an RTF file.

    Parameters
    ----------
    report:
        An :class:`rtfreport` object.
    file_path:
        Output path for the RTF file.
    overwrite:
        If ``False`` (default), raise an error when *file_path* already exists.

    Returns
    -------
    str
        The *file_path* that was written.
    """
    if not isinstance(report, rtfreport):
        raise TypeError("`report` must be an rtfreport object.")
    if os.path.exists(file_path) and not overwrite:
        raise FileExistsError("`file_path` already exists. Set overwrite=True.")

    report.validate()

    doc = report.document
    page_defaults = doc["default_page"]
    primary_font = "Courier"
    if doc["font_table"] and doc["font_table"][0].get("name"):
        primary_font = doc["font_table"][0]["name"]

    writable_width = (
        page_defaults["width_twips"]
        - page_defaults["margin_left_twips"]
        - page_defaults["margin_right_twips"]
    )

    total_pages = sum(len(sec["pages"]) for sec in report.sections)

    doc_cmd = RTF_COMMANDS["document"]
    para_cmd = RTF_COMMANDS["paragraph"]

    lines: list[str] = [
        doc_cmd["rtf_header_open"],
        _cmd_fmt(doc_cmd["font_table_template"], {"font_name": _rtf_escape(primary_font)}),
        doc_cmd["color_table_default"],
        _cmd_fmt(doc_cmd["page_settings_template"], {
            "width_twips": page_defaults["width_twips"],
            "height_twips": page_defaults["height_twips"],
            "margin_left_twips": page_defaults["margin_left_twips"],
            "margin_right_twips": page_defaults["margin_right_twips"],
            "margin_top_twips": page_defaults["margin_top_twips"],
            "margin_bottom_twips": page_defaults["margin_bottom_twips"],
            "font_size_half_points": doc["default_format"]["font_size_half_points"],
        }),
    ]

    global_page_num = 1

    for s_idx, sec in enumerate(report.sections, start=1):
        # Build combined header: document-wide rows + optional section-specific row
        header_rows = list(doc["default_header"].get("rows") or [])
        if sec.get("header") is not None:
            header_rows = header_rows + [sec["header"]]
        header_hf = {
            "rows": header_rows,
            "width_twips": doc["default_header"].get("width_twips"),
        }

        # Build combined footer: document-wide rows + optional section-specific row
        footer_rows = list(doc["default_footer"].get("rows") or [])
        if sec.get("footer") is not None:
            footer_rows = footer_rows + [sec["footer"]]
        footer_hf = {
            "rows": footer_rows,
            "width_twips": doc["default_footer"].get("width_twips"),
            "top_border": bool(doc["default_footer"].get("top_border", False)),
        }

        lines.append(doc_cmd["section_defaults"])

        for p_idx, page in enumerate(sec["pages"], start=1):
            header_rtf = _render_header_footer(
                header_hf, writable_width, is_footer=False,
                current_page=global_page_num, total_pages=total_pages,
            )
            footer_rtf = _render_header_footer(
                footer_hf, writable_width, is_footer=True,
                current_page=global_page_num, total_pages=total_pages,
            )

            if header_rtf:
                lines.append(_cmd_fmt(doc_cmd["header_wrapper"], {"content": "".join(header_rtf)}))
            if footer_rtf:
                lines.append(_cmd_fmt(doc_cmd["footer_wrapper"], {"content": "".join(footer_rtf)}))

            if page.get("title") and str(page["title"]).strip():
                lines.append(_cmd_fmt(para_cmd["center_bold_template"], {"text": _rtf_escape(page["title"])}))

            for block in page["content"]:
                if block["type"] in ("table", "listing"):
                    block_metadata = _resolve_block_metadata(
                        default_format=doc["default_format"],
                        page_options=page.get("page_options"),
                        block=block,
                    )
                    lines.extend(
                        _render_dataframe_table(
                            block["data"],
                            writable_width_twips=writable_width,
                            metadata=block_metadata,
                        )
                    )
                    if block.get("footer") and str(block["footer"]).strip():
                        lines.append(_cmd_fmt(para_cmd["left_template"], {"text": _rtf_escape(block["footer"])}))
                elif block["type"] == "figure":
                    fig_path = block["path"]
                    if not os.path.exists(fig_path):
                        raise FileNotFoundError(f"Figure file not found: {fig_path}")
                    lines.append(_cmd_fmt(
                        para_cmd["figure_placeholder_center_template"],
                        {"filename": _rtf_escape(os.path.basename(fig_path))},
                    ))
                    if block.get("footer") and str(block["footer"]).strip():
                        lines.append(_cmd_fmt(para_cmd["left_template"], {"text": _rtf_escape(block["footer"])}))

            if page.get("footer_notes") and str(page["footer_notes"]).strip():
                lines.append(_cmd_fmt(para_cmd["left_template"], {"text": _rtf_escape(page["footer_notes"])}))

            is_last = p_idx == len(sec["pages"]) and s_idx == len(report.sections)
            if not is_last:
                lines.append(doc_cmd["page_break"])

            global_page_num += 1

        if s_idx < len(report.sections):
            lines.append(doc_cmd["section_break"])

    lines.append(doc_cmd["document_close"])

    os.makedirs(os.path.dirname(os.path.abspath(file_path)), exist_ok=True)
    with open(file_path, "w", encoding="ascii", errors="replace") as f:
        f.write("\n".join(lines))

    return file_path
