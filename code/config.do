********************************************************************************
// config.do
// Purpose: Set all path globals relative to the replication/ root directory.
//          Every script in this package sources this file via 00_run_all.do.
//          No hardcoded paths anywhere else.
//
// Usage:   Run 00_run_all.do from the replication/ directory:
//              cd /path/to/replication
//              do code/00_run_all.do
//
//          The ROOT global is set dynamically using Stata's c(pwd), so this
//          file works on any machine without modification.
//
// Authors: [Author names]
// Date:    2026-03-03
********************************************************************************

// ---- Root (set dynamically — do NOT hardcode) ----
global ROOT    "`c(pwd)'"

// ---- Data ----
global RAW       "$ROOT/data/raw"
global DERIVED   "$ROOT/data/derived"

// ---- Output ----
global TABLES    "$ROOT/output/tables"
global FIGURES   "$ROOT/output/figures"

// ---- Subdirectories (raw data) ----
// Schlenker California daily weather grids — not publicly available;
// request from Wolfram Schlenker (Columbia). Place files as:
//   $RAW_SCHLENKER_CA/california{year}.dta  (years 1993–2019)
global RAW_SCHLENKER_CA  "$RAW/weather_schlenker_ca"

// ---- Subdirectories (derived data) ----
global GIS_GWDEPTH  "$DERIVED/gis/groundwater_depth"

// ---- Confirm globals ----
di "ROOT:    $ROOT"
di "RAW:     $RAW"
di "DERIVED: $DERIVED"
di "TABLES:  $TABLES"
di "FIGURES: $FIGURES"
