# ==============================================================================
# 02c_depth_panel.R
# Purpose: Spatially join monitoring well depth observations to DAU-county
#          boundaries and construct the balanced well × year groundwater depth
#          panel.  Merges surface water allocations and weather.
#
# Source:  cleaning_code/depth_to_dau.R — ported with path substitutions.
#          Two duplicate code blocks consolidated into one; dead code removed.
#
# Inputs:
#   DERIVED/gwdepth_raw_obs.dta
#   RAW_DIR/gis/DAU_County_2018/DAU_County_2018.shp
#   RAW_DIR/from_nick/surface_water/allocations_aggregate_dauco.dta
#   DERIVED/weather_dauco_annual.dta
#
# Outputs:
#   DERIVED/dauco_gwdepth_annual.dta   (DAUCO × year average GW depth — used by 02a)
#   DERIVED/gwdepth_well_panel.dta     (monitoring well × year panel)
#
# Authors: [Author names]
# Date:    2026-03-04
# ==============================================================================

# source config.R — sets ROOT, RAW_DIR, DERIVED, TABLES, FIGURES
source(here::here("code", "config.R"))

pacman::p_load(haven, sf, dplyr)

depth_allrawobs <- read_dta(file.path(DERIVED, "gwdepth_raw_obs.dta"))

dau <- st_read(file.path(RAW_DIR, "gis", "DAU_County_2018", "DAU_County_2018.shp"))%>%
  mutate(DAUCO=as.numeric(DAUCO))%>%
  st_transform("+proj=longlat +datum=WGS84 +no_defs")%>%
  dplyr::select(DAUCO)

allocations_aggregate_dauco <- read_dta(file.path(RAW_DIR, "from_nick", "surface_water", "allocations_aggregate_dauco.dta"))%>%
  rename(DAUCO=dauco_id)

all_weather <- read_dta(file.path(DERIVED, "weather_dauco_annual.dta"))

# ---- DAUCO × year average depth (used by 02a_dauco_panel.R) ----

depth_points <- st_as_sf(depth_allrawobs, coords=c("longitude", "latitude"))%>%
  st_set_crs("+proj=longlat +datum=WGS84 +no_defs")

dauco_gwdepth_annual <- data.frame(st_join(depth_points, dau))%>%
  dplyr::select(!geometry)%>%
  group_by(DAUCO, year)%>%
  summarize(av_depth=mean(dtw), count=n())

write_dta(dauco_gwdepth_annual, file.path(DERIVED, "dauco_gwdepth_annual.dta"))

# ---- Monitoring well × year panel ----

points <- st_as_sf(depth_allrawobs, coords=c("longitude", "latitude"))%>%
  st_set_crs("+proj=longlat +datum=WGS84 +no_defs")

merge_final <- data.frame(st_join(points, dau))%>%
  group_by(wellid)%>%
  mutate(dtw2=dplyr::lead(dtw, 1),
         diff_depth=dtw2-lag(dtw, 1))

grid <- expand.grid(wellid=unique(merge_final$wellid), year=unique(merge_final$year))%>%
  left_join(merge_final)

gwdepth_well_panel <- grid%>%
  left_join(allocations_aggregate_dauco)%>%
  left_join(all_weather)%>%
  dplyr::select(!geometry)

write_dta(gwdepth_well_panel, file.path(DERIVED, "gwdepth_well_panel.dta"))
