# config.R
# Purpose: Set all path variables relative to the replication/ root directory.
#          Source this file at the top of every R script in this package.
#
# Usage:   source(here::here("code", "config.R"))
#          Requires the `here` package (install.packages("here")).
#          here::here() resolves to the directory containing the .here file,
#          which should be placed at the replication/ root.
#
# Authors: [Author names]
# Date:    2026-03-03

library(here)

ROOT      <- here::here()
RAW_DIR   <- file.path(ROOT, "data", "raw")
DERIVED   <- file.path(ROOT, "data", "derived")
TABLES    <- file.path(ROOT, "output", "tables")
FIGURES   <- file.path(ROOT, "output", "figures")

# Raw data subdirectories
# Schlenker California daily weather grids — not publicly available;
# request from Wolfram Schlenker (Columbia). Place files as:
#   RAW_SCHLENKER_CA/california{year}.dta  (years 1993–2019)
#   RAW_SCHLENKER_CA/dd_2020_2021.dta
#   RAW_SCHLENKER_CA/california_raw_prec.dta
RAW_SCHLENKER_CA <- file.path(RAW_DIR, "weather_schlenker_ca")


message("ROOT:    ", ROOT)
message("RAW:     ", RAW_DIR)
message("DERIVED: ", DERIVED)
message("TABLES:  ", TABLES)
message("FIGURES: ", FIGURES)
