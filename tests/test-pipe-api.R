# Basic tests for Pipe Composition API (rtf_document)
# Run this script to verify pipe API functionality

# Load package from development directory
library(devtools)
load_all(quiet = TRUE)

# Load magrittr for pipe operator %>%
library(magrittr)

# ==============================================================================
# Test 1: Create and configure document
# ==============================================================================
cat("\n=== Test 1: Document Creation and Configuration ===\n")

doc <- rtf_document()
cat("✓ rtf_document() created\n")
cat("  Class:", class(doc), "\n")
cat("  Structure:", paste(names(doc), collapse=", "), "\n")

# Check default values
stopifnot(doc$document$page$orientation == "landscape")
stopifnot(doc$document$page$width_in == 11)
stopifnot(doc$document$page$height_in == 8.5)
cat("✓ Default clinical trial settings applied\n")

# Configure document
doc2 <- rtf_config(doc, page = list(orientation = "portrait"))
stopifnot(doc2$document$page$orientation == "portrait")
stopifnot(doc$document$page$orientation == "landscape")  # Original unchanged
cat("✓ rtf_config() works (immutable pattern)\n")

# ==============================================================================
# Test 2: Add content
# ==============================================================================
cat("\n=== Test 2: Content Addition ===\n")

# Create test data
df1 <- data.frame(A = 1:3, B = c("x", "y", "z"))
df2 <- data.frame(ID = c(10, 20, 30), Value = c(100, 200, 300))

# Add tables
doc3 <- rtf_document() %>%
  rtf_tables(list(df1, df2))

stopifnot(length(doc3$contents) == 2)
cat("✓ rtf_tables() appends content\n")
cat("  Pages created:", length(doc3$contents), "\n")

# Multiple tables on one page
doc4 <- rtf_document() %>%
  rtf_tables(list(df1, list(df2)))

stopifnot(length(doc4$contents) == 2)
cat("✓ Multi-table pages supported\n")

# ==============================================================================
# Test 3: Section definition
# ==============================================================================
cat("\n=== Test 3: Section Definition ===\n")

doc5 <- rtf_document() %>%
  rtf_tables(list(df1, df2)) %>%
  rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL))

stopifnot(length(doc5$sections) == 1)
stopifnot(!is.null(doc5$sections[["1"]]))
cat("✓ rtf_section() maps pages to sections\n")
cat("  Sections defined:", length(doc5$sections), "\n")

# Multiple sections
doc6 <- rtf_document() %>%
  rtf_tables(list(df1, df2)) %>%
  rtf_section(page = c(1, 2), secinfo = list(
    list(header = NULL, footer = NULL),
    list(header = NULL, footer = NULL)
  ))

stopifnot(length(doc6$sections) == 2)
cat("✓ Multiple sections supported\n")

# ==============================================================================
# Test 4: Formatting
# ==============================================================================
cat("\n=== Test 4: Formatting Functions ===\n")

doc7 <- rtf_document() %>%
  rtf_tables(list(df1, df2)) %>%
  rtf_table_format(pages = "all", border = "tfl", row_height_twips = 280L)

stopifnot(!is.null(doc7$table_formats[["all"]]))
stopifnot(doc7$table_formats[["all"]]$border == "tfl")
cat("✓ rtf_table_format() with pages='all'\n")

# Page-specific override
doc8 <- doc7 %>%
  rtf_table_format(pages = 1, border = "none")

stopifnot(doc8$table_formats[["1"]]$border == "none")
stopifnot(doc8$table_formats[["all"]]$border == "tfl")  # Global unchanged
cat("✓ Page-specific format override (immutable)\n")

# Header and footer formatting
doc9 <- rtf_document() %>%
  rtf_tables(list(df1, df2)) %>%
  rtf_header_format(pages = "all", border = "top", row_height_twips = 300L) %>%
  rtf_footer_format(pages = c(1, 2), border = "bottom")

stopifnot(!is.null(doc9$header_formats[["all"]]))
stopifnot(!is.null(doc9$footer_formats[["1"]]))
cat("✓ rtf_header_format() and rtf_footer_format()\n")

# ==============================================================================
# Test 5: NULL-safe parameters
# ==============================================================================
cat("\n=== Test 5: NULL-Safe Parameters (Safe for Repeated Calls) ===\n")

doc10 <- rtf_document() %>%
  rtf_tables(list(df1, df2)) %>%
  rtf_table_format(pages = "all", border = "tfl", row_height_twips = 280L)

# Second call with partial params (only overwrites what's specified)
doc11 <- doc10 %>%
  rtf_table_format(pages = "all", row_height_twips = 320L)

# Check: border unchanged, row_height updated
stopifnot(doc11$table_formats[["all"]]$border == "tfl")
stopifnot(doc11$table_formats[["all"]]$row_height_twips == 320L)
cat("✓ NULL parameters don't overwrite (safe for repeated calls)\n")

# ==============================================================================
# Test 6: Print method
# ==============================================================================
cat("\n=== Test 6: Print S3 Method ===\n")

doc12 <- rtf_document() %>%
  rtf_tables(list(df1, df2, df1)) %>%
  rtf_section(page = 1, secinfo = list(header = NULL, footer = NULL))

cat("Document output:\n")
print(doc12)

# ==============================================================================
# Test 7: Integration test - full workflow
# ==============================================================================
cat("\n=== Test 7: Full Workflow Integration ===\n")

# Create a complete report
workflow_doc <- rtf_document() %>%
  rtf_config(page = list(
    orientation = "landscape",
    width_in = 11,
    height_in = 8.5
  )) %>%
  rtf_tables(list(df1, df2)) %>%
  rtf_section(page = 1, secinfo = list(
    header = list(l = "Section 1", r = "Page 1"),
    footer = list(c = "Footer 1")
  )) %>%
  rtf_section(page = 2, secinfo = list(
    header = list(l = "Section 2", r = "Page 2"),
    footer = list(c = "Footer 2")
  )) %>%
  rtf_table_format(pages = "all", border = "tfl", row_height_twips = 280L) %>%
  rtf_header_format(pages = "all", border = "top", row_height_twips = 300L)

stopifnot(length(workflow_doc$contents) == 2)
stopifnot(length(workflow_doc$sections) == 2)
stopifnot(!is.null(workflow_doc$table_formats[["all"]]))
stopifnot(!is.null(workflow_doc$header_formats[["all"]]))
cat("✓ Complete workflow successful\n")

# ==============================================================================
# Summary
# ==============================================================================
cat("\n=== ALL TESTS PASSED ===\n")
cat("✓ Document creation and configuration\n")
cat("✓ Content addition (tables and multiple tables per page)\n")
cat("✓ Section definition (single and multiple)\n")
cat("✓ Formatting (table, header, footer with page selection)\n")
cat("✓ NULL-safe parameters (repeated calls don't overwrite)\n")
cat("✓ Print S3 method\n")
cat("✓ Full workflow integration\n")
cat("\nPipe Composition API is fully functional!\n\n")
