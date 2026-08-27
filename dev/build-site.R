# ==============================================================================
# build-site.R -- rebuild the pkgdown site into docs/.
#
# Run from anywhere:  Rscript dev/build-site.R
#
# Regenerate the figures first if they changed:  Rscript dev/graphics/make-graphics.R
# ==============================================================================

args <- commandArgs(trailingOnly = FALSE)
script <- sub("^--file=", "", grep("^--file=", args, value = TRUE)[1])
root <- normalizePath(file.path(dirname(script), ".."))

# Rscript has no pandoc on PATH; borrow RStudio's copy if none is set.
if (Sys.getenv("RSTUDIO_PANDOC") == "" && !nzchar(Sys.which("pandoc"))) {
  rstudio_pandoc <- "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools"
  if (dir.exists(rstudio_pandoc)) Sys.setenv(RSTUDIO_PANDOC = rstudio_pandoc)
}

pkgdown::build_site(root, install = TRUE, preview = FALSE, new_process = TRUE)

# pkgdown 2.1.1 on Windows percent-encodes the "/" in vignette image paths
# (figures%2Fx.svg), which breaks every embedded figure. Undo it.
articles <- list.files(file.path(root, "docs", "articles"),
                       pattern = "[.]html$", full.names = TRUE)
for (f in articles) {
  html <- readLines(f, warn = FALSE)
  fixed <- gsub("figures%2F", "figures/", html, fixed = TRUE)
  if (!identical(html, fixed)) {
    writeLines(fixed, f)
    message("repaired image paths in ", basename(f))
  }
}
