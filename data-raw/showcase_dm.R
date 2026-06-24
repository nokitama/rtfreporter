# data-raw/showcase_dm.R
# ---------------------------------------------------------------------------
# Regenerate the Demographics (DM) showcase RTFs.
#
# SINGLE SOURCE OF TRUTH: the article vignettes/articles/showcase-dm.Rmd.  This
# script does NOT duplicate any table-building logic -- it extracts the article's
# own code chunks with knitr::purl() and runs them, so the committed
# inst/rtf-examples/showcase/dm_*.rtf can never drift from the article again.
#
# The article's display-only chunks (the snapshot helper, the `library()` setup,
# and every `img-*` screenshot chunk) are marked `purl = FALSE`, so only the
# data / furniture / framework chunks run here.  Each framework chunk ends with
# `generate_rtfreport(doc, "dm_<framework>.rtf", ...)` -- written relative to the
# working directory, which we point at the output folder below.
#
# Requires every framework the article uses (gtsummary, cards, rtables, tern,
# tfrmt, Tplyr, ...) to be installed.
#
# PNG snapshots are still captured MANUALLY (open each .rtf in Word) and saved
# next to the .rtf as dm_<framework>.png; see showcase-dm.Rmd / the
# data-raw/showcase_placeholders.R note.
#
# Run with:  Rscript data-raw/showcase_dm.R
# ---------------------------------------------------------------------------

suppressMessages(devtools::load_all(".", quiet = TRUE))

rmd    <- "vignettes/articles/showcase-dm.Rmd"
outdir <- "inst/rtf-examples/showcase"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# Extract the article's runnable code chunks (purl = FALSE chunks are skipped).
code <- knitr::purl(rmd, output = tempfile(fileext = ".R"),
                    quiet = TRUE, documentation = 0)

cat("Generating DM showcase RTFs from", rmd, "...\n")
old <- setwd(outdir)
on.exit(setwd(old), add = TRUE)
source(code, local = new.env())          # data + furniture + framework chunks
setwd(old)

for (f in sort(list.files(outdir, "^dm_.*\\.rtf$")))
  cat(sprintf("  wrote %s (%d bytes)\n", f, file.size(file.path(outdir, f))))
