# ==============================================================================
# 02_merge_panels.R
# Purpose: Construct the main analytical panels by merging cleaned well
#          monitoring data with surface water allocations and weather.
#          Produces the all_wells*.dta dataset used in the groundwater depth
#          analysis (03d_gw_depth.do).
#
# Source:  add_lagged_weather.R (Code/3Merge/) — ported here in full.
#          That script was a fragment (no library() calls, no data loading);
#          the upstream data-loading steps are reconstructed below based on
#          object names and variable structure inferred from the analysis scripts.
#
# CANONICAL DATASET DECISIONS (from Phase 1 audit):
#   - all_wells2.dta is the canonical GW depth panel (used by 03d_gw_depth.do)
#   - all_wells5.dta is what add_lagged_weather.R produces (newer version)
#   - failures_11_23.dta is the canonical domestic failure panel (Nov 2023 freeze)
#   - final.dta is the canonical DAUCO-year ag construction panel
#
# Inputs:
#   DERIVED/farmgrid_gwdepth_long.dta
#     Well-level groundwater depth panel (wellid × year). Produced by Stage 1
#     GIS pipeline (01a + ArcPy interpolation). Contains at minimum:
#       wellid, year, dtw (depth to water, ft), DAUCO, w (weight)
#     NOTE: Exact file name and variable list must be verified against 01a output.
#
#   RAW_DIR/surface_water/allocations_aggregate_dauco.{dta,csv}
#     DAU-county-level surface water allocations (from Nick Hagerty).
#     Contains at minimum: DAUCO, year, sw_alloc
#     NOTE: Request from Nick Hagerty; file name and path to verify.
#
#   DERIVED/weather_prepped_yearly.dta  (from 01e_weather.do)
#     Schlenker weather data aggregated to gridNumber × year.
#     NOTE: Merge to wellid requires farmgrid_weather_crosswalk.dta (from 01e)
#     and the farmgrid-to-DAUCO crosswalk. This merge step is not fully
#     documented in the original scripts; reconstruct or request from authors.
#
# Outputs:
#   DERIVED/all_wells5.dta   (well-year balanced panel with allocations + weather)
#
# KNOWN GAPS (document for replicators):
#   1. The step merging weather data (weather_prepped_yearly.dta) to well-level
#      is not documented — it likely requires a spatial crosswalk from wellid
#      to gridNumber. See farmgrid_weather_crosswalk.dta from 01e.
#   2. The step producing the input well_depth_panel from Stage 1 GIS outputs
#      is not fully documented. The derived file all_wells2.dta (canonical)
#      is provided in data/derived/ for replicators.
#   3. The diff_depth variable (year-on-year change in dtw) must be computed
#      before or within this script.
#
# Date:    2026-03-03
# ==============================================================================

source(here::here("code", "config.R"))

library(haven)
library(dplyr)


# ==============================================================================
# STEP 1: Load well-level groundwater depth panel
# TODO: Verify exact file name and variable names produced by 01a + GIS pipeline
# ==============================================================================

# NOTE: Replace with correct file name once Stage 1 outputs are verified.
# The analysis (03d_gw_depth.do) loads all_wells2.dta which contains:
#   wellid, year, dtw, diff_depth, DAUCO, hdd, gdd, precip*, sw_alloc, w
# For replicators: use the provided data/derived/all_wells2.dta directly
# and skip this script.

well_depth_panel <- read_dta(
  file.path(DERIVED, "farmgrid_gwdepth_long.dta")  # TODO: verify file name
)

# Compute year-on-year change in depth to water
well_depth_panel <- well_depth_panel %>%
  arrange(wellid, year) %>%
  group_by(wellid) %>%
  mutate(diff_depth = dtw - lag(dtw, 1)) %>%
  ungroup()


# ==============================================================================
# STEP 2: Load surface water allocations (DAU-county level)
# TODO: Verify file name and path — request from Nick Hagerty
# ==============================================================================

# NOTE: allocations_aggregate_dauco has columns DAUCO, year, sw_alloc (at minimum)
allocations_aggregate_dauco <- read_dta(
  file.path(RAW_DIR, "surface_water", "allocations_aggregate_dauco.dta")  # TODO: verify
)


# ==============================================================================
# STEP 3: Load weather data (already aggregated to gridNumber × year by 01e)
# and merge to well level via spatial crosswalk
# TODO: The wellid → gridNumber crosswalk step is not documented.
#       This likely uses farmgrid_weather_crosswalk.dta + a wellid-to-farmgrid
#       lookup. Reconstruct or request from authors.
# ==============================================================================

# NOTE: all_weather has columns wellid (or DAUCO), year, hdd, gdd, precip* (at minimum)
all_weather <- read_dta(
  file.path(DERIVED, "all_weather25.dta")  # TODO: verify; may need spatial crosswalk
)


# ==============================================================================
# STEP 4: Construct balanced panel and merge
# Source: add_lagged_weather.R (Code/3Merge/) — ported verbatim below
# ==============================================================================

well_depth_panel_new <- well_depth_panel %>%
  select(wellid, year, diff_depth, DAUCO, w)

well_info <- well_depth_panel_new %>%
  select(wellid, DAUCO) %>%
  distinct(.keep_all = TRUE)

grid <- expand.grid(
  wellid = unique(well_depth_panel$wellid),
  year   = unique(well_depth_panel$year)
) %>%
  left_join(well_info)

well_depth_grid <- grid %>%
  left_join(well_depth_panel_new) %>%
  left_join(allocations_aggregate_dauco) %>%
  left_join(all_weather)


# ==============================================================================
# STEP 5: Save output
# ==============================================================================

write_dta(well_depth_grid, file.path(DERIVED, "all_wells5.dta"))

cat("02_merge_panels.R: wrote", nrow(well_depth_grid), "rows to all_wells5.dta\n")
cat("NOTE: Canonical analysis dataset is all_wells2.dta (provided in data/derived/).\n")
cat("      all_wells5.dta is a newer version produced by this pipeline.\n")
