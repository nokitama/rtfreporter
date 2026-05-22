# Test RTF file generation from Pipe API
# Generates an actual RTF file to verify end-to-end workflow

library(devtools)
load_all(quiet = TRUE)
library(magrittr)

cat("\n=== RTF File Generation Test ===\n")

# Create test data
df_safety <- data.frame(
  Event = c("Headache", "Nausea", "Dizziness"),
  Mild = c(5, 3, 2),
  Moderate = c(2, 1, 1),
  Severe = c(0, 0, 1)
)

df_efficacy <- data.frame(
  Response = c("Complete", "Partial", "No Response"),
  Count = c(25, 15, 10),
  Percent = c("50%", "30%", "20%")
)

# Build pipe API document
cat("Building document with pipe API...\n")

report <- rtf_document() %>%
  rtf_config(page = list(
    orientation = "landscape",
    width_in = 11,
    height_in = 8.5
  )) %>%
  rtf_tables(list(df_safety, df_efficacy)) %>%
  rtf_section(page = 1, secinfo = list(
    header = rtf_header(rows = list(l = "Clinical Report", r = "Safety")),
    footer = rtf_footer(rows = list(c = "Page 1"))
  )) %>%
  rtf_section(page = 2, secinfo = list(
    header = rtf_header(rows = list(l = "Clinical Report", r = "Efficacy")),
    footer = rtf_footer(rows = list(c = "Page 2"))
  )) %>%
  rtf_table_format(pages = "all", border = "tfl", row_height_twips = 280L) %>%
  rtf_header_format(pages = "all", border = "top", row_height_twips = 300L)

cat("✓ Document built successfully\n")
cat("  Pages:", length(report$contents), "\n")
cat("  Sections:", length(report$sections), "\n")

# Generate RTF file
output_file <- tempfile(fileext = ".rtf")
cat("\nGenerating RTF file...\n")

tryCatch({
  generate_rtfreport(report, output_file, overwrite = TRUE)
  cat("✓ RTF file generated\n")

  # Check file exists
  if (file.exists(output_file)) {
    cat("✓ File exists: ", output_file, "\n")
    file_size <- file.info(output_file)$size
    cat("  File size:", file_size, "bytes\n")

    if (file_size > 0) {
      cat("✓ File is not empty\n")

      # Check for RTF signature
      file_content <- readChar(output_file, nchars = 6)
      if (grepl("^\\{\\\\rtf", file_content)) {
        cat("✓ File has valid RTF header\n")
      } else {
        cat("✗ Warning: RTF header not found\n")
      }
    } else {
      cat("✗ ERROR: File is empty\n")
      stop("Generated RTF file is empty")
    }
  } else {
    cat("✗ ERROR: File was not created\n")
    stop("RTF file generation failed")
  }
}, error = function(e) {
  cat("✗ ERROR:", e$message, "\n")
  stop(e)
})

cat("\n=== RTF GENERATION TEST PASSED ===\n")
cat("Pipe API is fully integrated with RTF generation!\n")
cat("Generated file:", output_file, "\n\n")

# Cleanup
unlink(output_file)
