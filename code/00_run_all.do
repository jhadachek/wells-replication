********************************************************************************
// 00_run_all.do
// Purpose: Single entry point for full replication of Wells et al. (JPE).
//          Sources config.do to set all paths, then runs each stage in order.
//
// Usage:   Run from the replication/ directory (NOT from code/):
//              cd /path/to/replication
//              stata -b do code/00_run_all.do
//
// Stages:
//   Stage 1: Raw data cleaning (Stata) — requires raw data in data/raw/
//   Stage 2: GIS raster processing (ArcPy) — NOT REPRODUCIBLE; outputs provided
//   Stage 3: Panel construction (R) — merge pipeline (partially reconstructed)
//   Stage 4: Analysis + tables (Stata) — START HERE with derived data
//   Stage 5: Figures (R)
//
// STAGE 2 NOTE: The GIS interpolation step (groundwater depth and quality
//   rasters) was performed using ArcGIS Desktop + Python 2 / ArcPy, which
//   is no longer available. The derived GIS outputs are provided in
//   data/derived/gis/ and are treated as fixed inputs to Stage 1 (Stata).
//   Replicators should start at Stage 4 using data/derived/ as provided.
//
// STAGE 3 NOTE: The full merge pipeline is partially reconstructed.
//   See code/02_merge/02_merge_panels.R for details.
//
// Authors: [Author names]
// Date:    2026-03-03
********************************************************************************

version 18
clear all
set more off

// ---- Set root and load path globals ----
// Must run from the replication/ directory
cd "`c(pwd)'"
do "code/config.do"

// ---- Install required Stata packages ----
// Uncomment on first run; comment out thereafter for speed.
// do "code/install_packages.do"

// ============================================================
// STAGE 1: Clean raw data (Stata)
// Requires: data/raw/ populated per data/raw/README_raw.md
// Produces: data/derived/*.dta intermediate files
// ============================================================

// do "code/01_clean/01a_gw_depth_stata.do"
// do "code/01_clean/01c_gw_quality_stata.do"
// do "code/01_clean/01e_weather.do"
// do "code/01_clean/01f_well_completions.R"  // via shell Rscript

// ============================================================
// STAGE 2: GIS raster processing — NOT REPRODUCIBLE
// Requires ArcGIS Desktop + Python 2.7/ArcPy (no longer available).
// Derived outputs are provided in data/derived/gis/.
// DO NOT uncomment — these scripts cannot be run.
// ============================================================

// shell python "code/01_clean/01b_gw_depth_python.py"   // NOT REPRODUCIBLE
// shell python "code/01_clean/01d_gw_quality_python.py"  // NOT REPRODUCIBLE

// ============================================================
// STAGE 3: Merge panels (R)
// Produces: data/derived/all_wells*.dta, final*.dta, failures*.dta
// ============================================================

// shell Rscript "code/02_merge/02_merge_panels.R"

// ============================================================
// STAGE 4: Analysis + tables (Stata)
// Requires: data/derived/ populated (from Stages 1-3, or provided)
// Produces: output/tables/*.tex
// ============================================================

do "code/03_analysis/03a_summary_stats.do"
do "code/03_analysis/03b_ag_construction.do"
capture noisily do "code/03_analysis/03c_domestic_failures.do"
capture noisily do "code/03_analysis/03d_gw_depth.do"

// ============================================================
// STAGE 5: Figures (R)
// Produces: output/figures/*.png, *.pdf
// ============================================================

shell Rscript "code/04_figures/04a_maps.R"
shell Rscript "code/04_figures/04b_failure_maps.R"
shell Rscript "code/04_figures/04c_env_justice.R"
shell Rscript "code/04_figures/04d_descriptive.R"

di "Replication complete. Check output/tables/ and output/figures/."
