# install_packages.R
# Purpose: Install all required R packages for this replication package.
#          Run once on a new machine: Rscript code/install_packages.R
# Date:    2026-03-03

packages <- c(
  # Data handling
  "haven",       # read/write Stata .dta files
  "dplyr",
  "tidyr",
  "readr",
  "readxl",
  "lubridate",
  "stringr",
  "here",        # relative paths

  # Spatial / GIS
  "sf",
  "tigris",
  "ggplot2",
  "scales",
  "viridis",

  # Econometrics
  "fixest",      # feols, feglm (replaces reghdfe/ivreghdfe in R)

  # Misc
  "purrr",
  "forcats"
)

install.packages(packages, repos = "https://cloud.r-project.org")

# Record versions for reproducibility
cat("\nInstalled package versions:\n")
for (pkg in packages) {
  cat(sprintf("  %-20s %s\n", pkg, as.character(packageVersion(pkg))))
}
