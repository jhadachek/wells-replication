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
#   - gwdepth_well_panel.dta is the canonical GW depth panel (used by 03d_gw_depth.do)
#   - gwdepth_well_panel_lagged.dta is what add_lagged_weather.R produces (newer version)
#   - domestic_failures_panel.dta is the canonical domestic failure panel (Nov 2023 freeze)
#   - dauco_construction_panel.dta is the canonical DAUCO-year ag construction panel
#
# Inputs:
#   DERIVED/gwdepth_well_panel.dta
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
#   DERIVED/gwdepth_well_panel_lagged.dta   (well-year balanced panel with allocations + weather)
#
# KNOWN GAPS (document for replicators):
#   1. The step merging weather data (weather_prepped_yearly.dta) to well-level
#      is not documented — it likely requires a spatial crosswalk from wellid
#      to gridNumber. See farmgrid_weather_crosswalk.dta from 01e.
#   2. The step producing the input well_depth_panel from Stage 1 GIS outputs
#      is not fully documented. The derived file gwdepth_well_panel.dta (canonical)
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
# ==============================================================================

# NOTE: gwdepth_well_panel.dta is produced by 02c_depth_panel.R (reads
# gwdepth_raw_obs.dta from 01a and spatially joins to DAU County boundaries).
# For replicators: use the provided data/derived/gwdepth_well_panel.dta directly
# and skip this script.

well_depth_panel <- read_dta(
  file.path(DERIVED, "gwdepth_well_panel.dta")
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
  file.path(DERIVED, "weather_dauco_annual.dta")  # TODO: verify; may need spatial crosswalk
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

write_dta(well_depth_grid, file.path(DERIVED, "gwdepth_well_panel_lagged.dta"))

cat("02_merge_panels.R: wrote", nrow(well_depth_grid), "rows to gwdepth_well_panel_lagged.dta\n")
cat("NOTE: Canonical analysis dataset is gwdepth_well_panel.dta (provided in data/derived/).\n")
cat("      gwdepth_well_panel_lagged.dta is a newer version produced by this pipeline.\n")
