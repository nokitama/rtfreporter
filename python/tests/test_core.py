"""Tests for rtfreporter Python package."""
import os
import tempfile

import pandas as pd
import pytest

from rtfreporter import generate_rtfreport, hello_rtfreporter, rtfreport

TESTDATA = os.path.join(os.path.dirname(__file__), "testdata")
DM = pd.read_csv(os.path.join(TESTDATA, "dm.csv"))
AE = pd.read_csv(os.path.join(TESTDATA, "ae.csv"))
DM_COHORT = pd.read_csv(os.path.join(TESTDATA, "dm_cohort.csv"))
AE_COHORT = pd.read_csv(os.path.join(TESTDATA, "ae_cohort.csv"))


def test_hello_rtfreporter() -> None:
    assert hello_rtfreporter() == "Hello from rtfreporter (Python)"


# ---------------------------------------------------------------------------
# Basic test: named-column header format + page token embedding
# ---------------------------------------------------------------------------

def test_basic_dm_ae_report(tmp_path: "pytest.TempPathFactory") -> None:
    report = rtfreport()
    sec = report.add_section(
        header={"columns": {"l": "DM/AE Listing", "r": "Page {PAGE} of {TOTAL_PAGES}"}}
    )

    report.add_page(
        section_index=sec,
        title="Demographics (DM)",
        content=[{"type": "table", "data": DM, "footer": "Source: DM domain"}],
        footer_notes="Confidential",
    )
    report.add_page(
        section_index=sec,
        title="Adverse Events (AE)",
        content=[{"type": "listing", "data": AE, "footer": "Source: AE domain"}],
    )
    report.set_section_footer(sec, {"columns": {"l": "Confidential - Do Not Distribute"}})

    outfile = str(tmp_path / "dm_ae_report.rtf")
    generate_rtfreport(report, outfile, overwrite=True)

    assert os.path.exists(outfile)
    rtf_txt = open(outfile, encoding="ascii", errors="replace").read()

    assert r"\rtf1" in rtf_txt
    assert "Demographics (DM)" in rtf_txt
    assert "Adverse Events (AE)" in rtf_txt
    assert "DM/AE Listing" in rtf_txt
    # Page tokens embedded as actual numbers
    assert "1 of 2" in rtf_txt
    assert "2 of 2" in rtf_txt
    # Single-column footer: top border and left align
    assert "clbrdrt" in rtf_txt
    assert r"\ql" in rtf_txt


# ---------------------------------------------------------------------------
# Negative test: unsupported block type
# ---------------------------------------------------------------------------

def test_unsupported_block_type(tmp_path: "pytest.TempPathFactory") -> None:
    bad_report = rtfreport()
    sec = bad_report.add_section()
    bad_report.add_page(
        section_index=sec,
        title="Bad page",
        content=[{"type": "unknown", "data": DM}],
    )
    with pytest.raises((ValueError, Exception), match="Unsupported block type"):
        generate_rtfreport(bad_report, str(tmp_path / "bad.rtf"), overwrite=True)


# ---------------------------------------------------------------------------
# Manual builder methods test
# ---------------------------------------------------------------------------

def test_manual_builder(tmp_path: "pytest.TempPathFactory") -> None:
    report = rtfreport()
    report.set_document_defaults(
        default_format={"font_size_half_points": 16},
        default_page={"margin_left_twips": 900},
    )

    sec = report.add_section()
    report.set_section_header(sec, {"columns": {"l": "Protocol: XYZ", "r": "HOGE company"}})
    report.set_section_footer(sec, {"columns": {"l": "Page {PAGE} of {TOTAL_PAGES}"}})

    page = report.add_page(section_index=sec, title="Manual Build")
    report.add_table(sec, page, data=DM, footer="DM table footer")
    report.add_listing(sec, page, data=AE, footer="AE listing footer")
    report.set_page_footer_notes(sec, page, "Manual footer note")

    outfile = str(tmp_path / "manual_builder_report.rtf")
    generate_rtfreport(report, outfile, overwrite=True)

    assert os.path.exists(outfile)
    rtf_txt = open(outfile, encoding="ascii", errors="replace").read()

    assert "Manual Build" in rtf_txt
    assert "Protocol: XYZ" in rtf_txt
    assert "DM table footer" in rtf_txt
    assert "AE listing footer" in rtf_txt
    assert "Manual footer note" in rtf_txt
    # Single page: "1 of 1"
    assert "1 of 1" in rtf_txt
    # Top border on single-column footer
    assert "clbrdrt" in rtf_txt


# ---------------------------------------------------------------------------
# Multi-page + multi-section (cohort) test
# ---------------------------------------------------------------------------

def test_multi_section_cohort(tmp_path: "pytest.TempPathFactory") -> None:
    dm_agg = (
        DM_COHORT.groupby(["COHORT", "SEX"])
        .agg(N=("AGE", "count"), Mean_Age=("AGE", "mean"))
        .reset_index()
    )
    dm_agg["Mean_Age"] = dm_agg["Mean_Age"].round(1)

    ae_agg = (
        AE_COHORT.groupby(["COHORT", "AETERM"])
        .size()
        .reset_index(name="Count")
    )

    report = rtfreport()
    report.set_default_header({
        "rows": [
            {"columns": {"l": "Protocol: XXXXX", "r": "HOGE company"}},
            {"columns": {"l": "Study Title", "r": "Page {PAGE} of {TOTAL_PAGES}"}},
            {"columns": {"c": "Table 14.1.1 Demographic and Safety Summary"}},
        ]
    })
    report.set_default_footer({
        "rows": [{"columns": {"l": "Confidential"}}]
    })

    sec1 = report.add_section(header={"columns": {"l": "Cohort: Cohort 1"}})
    report.add_page(
        section_index=sec1,
        title="Demographics Summary (Cohort 1)",
        content=[{"type": "table", "data": dm_agg[dm_agg["COHORT"] == "Cohort 1"]}],
    )
    report.add_page(
        section_index=sec1,
        title="Adverse Events (Cohort 1)",
        content=[{"type": "table", "data": ae_agg[ae_agg["COHORT"] == "Cohort 1"]}],
    )

    sec2 = report.add_section(header={"columns": {"l": "Cohort: Cohort 2"}})
    report.add_page(
        section_index=sec2,
        title="Demographics Summary (Cohort 2)",
        content=[{"type": "table", "data": dm_agg[dm_agg["COHORT"] == "Cohort 2"]}],
    )
    report.add_page(
        section_index=sec2,
        title="Adverse Events (Cohort 2)",
        content=[{"type": "table", "data": ae_agg[ae_agg["COHORT"] == "Cohort 2"]}],
    )

    outfile = str(tmp_path / "cohort_multi_section_report.rtf")
    generate_rtfreport(report, outfile, overwrite=True)

    assert os.path.exists(outfile)
    rtf_txt = open(outfile, encoding="ascii", errors="replace").read()

    # Page numbers embedded as actual numbers (4 pages total)
    assert "1 of 4" in rtf_txt
    assert "2 of 4" in rtf_txt
    assert "3 of 4" in rtf_txt
    assert "4 of 4" in rtf_txt

    # Document-wide header rows
    assert "HOGE company" in rtf_txt
    assert "Study Title" in rtf_txt
    assert "Demographic and Safety Summary" in rtf_txt

    # Section-specific header rows
    assert "Cohort: Cohort 1" in rtf_txt
    assert "Cohort: Cohort 2" in rtf_txt

    # Footer top border present
    assert "clbrdrt" in rtf_txt

    # Page breaks and section breaks
    assert r"\page" in rtf_txt
    assert r"\sect" in rtf_txt


# ---------------------------------------------------------------------------
# overwrite=False should raise when file exists
# ---------------------------------------------------------------------------

def test_overwrite_protection(tmp_path: "pytest.TempPathFactory") -> None:
    report = rtfreport()
    sec = report.add_section()
    report.add_page(section_index=sec, title="T")
    outfile = str(tmp_path / "existing.rtf")
    generate_rtfreport(report, outfile, overwrite=True)
    with pytest.raises((FileExistsError, Exception)):
        generate_rtfreport(report, outfile, overwrite=False)


def test_table_metadata_controls_layout(tmp_path: "pytest.TempPathFactory") -> None:
    report = rtfreport()
    sec = report.add_section()

    report.add_page(
        section_index=sec,
        title="Metadata Layout",
        content=[
            {
                "type": "table",
                "data": DM[["USUBJID", "SEX"]],
                "metadata": {
                    "row_height_twips": 360,
                    "column_widths_twips": [1200, 3600],
                },
            }
        ],
    )

    outfile = str(tmp_path / "metadata_layout.rtf")
    generate_rtfreport(report, outfile, overwrite=True)
    rtf_txt = open(outfile, encoding="ascii", errors="replace").read()

    assert "\\trrh360" in rtf_txt
    assert "\\cellx1200" in rtf_txt
    assert "\\cellx4800" in rtf_txt

