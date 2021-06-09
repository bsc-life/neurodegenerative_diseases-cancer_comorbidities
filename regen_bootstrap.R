#.libPaths( c( "R/libs", .libPaths()) )

# Zero, cleanup of libs
unlink(list.dirs("renv/library", recursive = FALSE), recursive = TRUE)

# Install renv (if it is needed!)
options(renv.consent = TRUE)
if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv")
}

renv::init(bare = TRUE, restart = TRUE)

# Enable this only if BioConductor packages are involved
#if (!requireNamespace("BiocManager", quietly = TRUE)) {
#  install.packages("BiocManager")
#}

# This line adding the Bioconductor repositories is needed,
# in order to have the URLs to their repos in the
# reproducible snapshot
# Enable this only if BioConductor packages are involved
#options(repos = BiocManager::repositories())

packageList <-
  c(
    "shiny",
    "shinythemes",
    "shinydashboard",
    "shinydashboardPlus",
    "igraph",
    "magrittr",
    "visNetwork",
    "data.table",
    "DT"
  )

renv::install(packageList)

# Enable this only if BioConductor packages are involved
#BiocManager::install("somepackage")

renv::snapshot(prompt = FALSE)
