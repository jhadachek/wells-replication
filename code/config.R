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

# GIS subdirectories
GIS_GWDEPTH <- file.path(DERIVED, "gis", "groundwater_depth")
GIS_GWQUAL  <- file.path(DERIVED, "gis", "groundwater_quality")

message("ROOT:    ", ROOT)
message("RAW:     ", RAW_DIR)
message("DERIVED: ", DERIVED)
message("TABLES:  ", TABLES)
message("FIGURES: ", FIGURES)
