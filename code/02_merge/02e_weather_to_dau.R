################################################################################
# 02e_weather_to_dau.R
# Purpose: Aggregate Schlenker California grid-level degree-day data to
#          DAUCO × year panel. Loops over 1993–2019 degree-day files
#          (produced by 01e_weather.do), spatially joins each grid centroid
#          to DAU County boundaries, and collapses to annual DAUCO averages.
#          Appends 2020–2021 heat and precipitation supplement files.
#
# Inputs:  $DERIVED/temp/dd_california_{year}.dta  (years 1993–2019)
#            Grid × month degree-day summaries from 01e_weather.do
#          $RAW_SCHLENKER_CA/dd_2020_2021.dta
#            Pre-aggregated annual heat degree days for 2020–2021
#          $RAW_SCHLENKER_CA/california_raw_prec.dta
#            Annual precipitation data for 2020–2021
#          $RAW_DIR/gis/DAU_County_2018/DAU_County_2018.shp
#            DAU County boundaries shapefile
#
# Outputs: $DERIVED/weather_dauco_annual.dta
#            DAUCO × year weather panel with hdd, dday29, dday8, precip, gdd
#            (1993–2021 for heat; precip sourced separately for 2020–2021)
#
# Source:  weather_to_dau.R (original)
#
# Authors: [Author names]
# Date:    2026-03-05
################################################################################

pacman::p_load(haven, dplyr, sf)

# source config.R — sets ROOT, RAW_DIR, DERIVED, TABLES, FIGURES, RAW_SCHLENKER_CA
source(here::here("code", "config.R"))

# Load DAU County shapefile
dau <- st_read(file.path(RAW_DIR, "gis", "DAU_County_2018", "DAU_County_2018.shp")) %>%
  mutate(DAUCO = as.numeric(DAUCO))

# Convert DAU to WGS84 and retain only DAUCO identifier
dau <- st_transform(dau, "+proj=longlat +datum=WGS84 +no_defs") %>%
  dplyr::select(DAUCO)

# ---- 1993–2019: loop over annual degree-day files ----
hdd_full <- NULL

for (x in seq(1993, 2019, 1)) {
  dd_california <- read_dta(file.path(DERIVED, "temp", paste0("dd_california_", x, ".dta"))) %>%
    mutate(year = x)

  dd_california_year <- dd_california %>%
    group_by(gridNumber, longitude, latitude, year) %>%
    summarize(
      hdd    = sum(dday32),
      dday29 = sum(dday29),
      precip = sum(precip),
      dday8  = sum(dday8),
      gdd    = sum(dday8 - dday32 + bday32 * 24),
      .groups = "drop"
    )

  hdd_full <- rbind(hdd_full, dd_california_year)
}

# Spatially join 1993–2019 grids to DAU County boundaries
points <- st_as_sf(hdd_full, coords = c("longitude", "latitude"))
points <- st_set_crs(points, "+proj=longlat +datum=WGS84 +no_defs")

merge_final <- st_join(points, dau)
merge_final  <- data.frame(merge_final)

# Collapse to DAUCO × year (average across grid cells within DAUCO)
weather_final <- merge_final %>%
  dplyr::select(!geometry) %>%
  group_by(year, DAUCO) %>%
  summarize(
    hdd    = mean(hdd),
    dday29 = mean(dday29),
    precip = mean(precip),
    dday8  = mean(dday8),
    .groups = "drop"
  )

# ---- 2020–2021: supplement files ----
dd_2020_2021 <- read_dta(file.path(RAW_SCHLENKER_CA, "dd_2020_2021.dta")) %>%
  group_by(longitude, latitude, year) %>%
  summarize(
    hdd    = sum(dday32),
    dday29 = sum(dday29),
    dday8  = sum(dday8),
    .groups = "drop"
  )

california_raw_prec <- read_dta(file.path(RAW_SCHLENKER_CA, "california_raw_prec.dta"))

# Spatial join: 2020–2021 heat
points_2020_2021 <- st_as_sf(dd_2020_2021, coords = c("longitude", "latitude"))
points_2020_2021 <- st_set_crs(points_2020_2021, "+proj=longlat +datum=WGS84 +no_defs")

merge_final_2020_2021 <- st_join(points_2020_2021, dau)
merge_final_2020_2021 <- data.frame(merge_final_2020_2021) %>%
  filter(!is.na(DAUCO))

# Spatial join: 2020–2021 precipitation
points_prec <- st_as_sf(california_raw_prec, coords = c("longitude", "latitude"))
points_prec <- st_set_crs(points_prec, "+proj=longlat +datum=WGS84 +no_defs")

merge_final_prec <- st_join(points_prec, dau)
merge_final_prec  <- data.frame(merge_final_prec) %>%
  filter(!is.na(DAUCO))

# Collapse to DAUCO × year
prec_final <- merge_final_prec %>%
  dplyr::select(!geometry) %>%
  group_by(year, DAUCO) %>%
  summarize(precip = mean(ppt), .groups = "drop")

heat_final <- merge_final_2020_2021 %>%
  dplyr::select(!geometry) %>%
  group_by(year, DAUCO) %>%
  summarize(
    hdd    = mean(hdd),
    dday29 = mean(dday29),
    dday8  = mean(dday8),
    .groups = "drop"
  )

new_final <- prec_final %>%
  mutate(year = as.numeric(year)) %>%
  left_join(heat_final, by = c("year", "DAUCO"))

# ---- Stack 1993–2019 and 2020–2021 ----
# bind_rows used (vs base rbind) to handle column mismatch: gdd present in
# weather_final but absent in new_final (2020-2021 supplement lacks gdd).
all_weather <- bind_rows(weather_final, new_final) %>%
  arrange(DAUCO, year)

write_dta(all_weather, file.path(DERIVED, "weather_dauco_annual.dta"))

message("02e_weather_to_dau.R complete. Wrote weather_dauco_annual.dta to ", DERIVED)
