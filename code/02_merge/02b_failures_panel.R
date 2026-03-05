# ==============================================================================
# 02b_failures_panel.R
# Purpose: Construct the domestic well failure panel by matching failure reports
#          to the nearest registered domestic well and assembling a well × year
#          treatment panel.  Merges surface water allocations and weather.
#
# Source:  cleaning_code/clean_failures.R — ported with path substitutions.
#          Dead code and unused variables removed. Paper-vintage script (Nov
#          2023 data freeze) that produces domestic_failures_panel.dta used by
#          03c_domestic_failures.do.
#
# Inputs:
#   RAW_DIR/gis/DAU_County_2018/DAU_County_2018.shp
#   RAW_DIR/from_nick/surface_water/allocations_aggregate_dauco.dta
#   DERIVED/well_construction.csv
#   DERIVED/well_destruction.csv
#   DERIVED/failures.csv
#   DERIVED/weather_dauco_annual.dta
#
# Outputs:
#   DERIVED/domestic_failures_panel.dta   (domestic failure panel — canonical for 03c)
#
# Authors: [Author names]
# Date:    2026-03-04
# ==============================================================================

# source config.R — sets ROOT, RAW_DIR, DERIVED, TABLES, FIGURES
source(here::here("code", "config.R"))

pacman::p_load(dplyr, readr, lubridate, sf, haven, nngeo)

dau <- st_read(file.path(RAW_DIR, "gis", "DAU_County_2018", "DAU_County_2018.shp"))%>%
  mutate(DAUCO=as.numeric(DAUCO))

allocations_aggregate_dauco <- read_dta(file.path(RAW_DIR, "from_nick", "surface_water", "allocations_aggregate_dauco.dta"))

well_construction <- read_csv(file.path(DERIVED, "well_construction.csv"))%>%
  filter(type=="Domestic")%>%
  select(!...1)%>%
  mutate(Longitude=DecimalLongitude, Latitude=DecimalLatitude)%>%
  st_as_sf(coords = c("DecimalLongitude","DecimalLatitude"))%>%
  mutate(id=as.character(geometry))%>%
  as.data.frame()%>%
  select(!geometry)%>%
  group_by(id, Longitude, Latitude)%>%
  mutate(count=n())%>%
  arrange(count, id, DateWorkEnded)%>%
  summarize(DateWorkEnded=max(DateWorkEnded, na.rm=TRUE),
            TotalCompletedDepth2=last(TotalCompletedDepth),
            TotalCompletedDepth=max(TotalCompletedDepth, na.rm=TRUE))%>%
  within(TotalCompletedDepth2[is.na(TotalCompletedDepth2)]<-TotalCompletedDepth[is.na(TotalCompletedDepth2)])%>%
  within(TotalCompletedDepth2[is.infinite(TotalCompletedDepth2)]<-NA)%>%
  filter(year(DateWorkEnded)<2014)

well_destructions <- read_csv(file.path(DERIVED, "well_destruction.csv"))

dates <- well_destructions%>%
  st_as_sf(coords = c("DecimalLongitude","DecimalLatitude"))%>%
  mutate(id=as.character(geometry))%>%
  select(id, DateWorkEnded)%>%
  rename(DateDestruct=DateWorkEnded)%>%
  as.data.frame()%>%
  right_join(well_construction)%>%
  select(id, DateWorkEnded, DateDestruct)

failures <- read_csv(file.path(DERIVED, "failures.csv"))%>%
  rename(DecimalLongitude=LONGITUDE, DecimalLatitude=LATITUDE)%>%
  mutate(date=as.Date(`CREATE DATE`, format="%m/%d/%Y"), year=year(date))%>%
  mutate(DecimalLongitude=as.double(DecimalLongitude), DecimalLatitude=as.double(DecimalLatitude))%>%
  select(!...1)

points <- st_as_sf(well_construction, coords=c("Longitude", "Latitude"))%>%
  mutate(id=as.character(geometry))
points <- st_set_crs(points, "+proj=longlat +datum=WGS84 +no_defs")

geometry <- points%>%select(id, geometry)

depth <- as.data.frame(points)%>%
  select(id, TotalCompletedDepth2)%>%
  rename(TotalCompletedDepth3=TotalCompletedDepth2)

grid <- expand.grid(id=unique(c(points$id)), year=seq(2014,2021,1))%>%
  filter(!is.na(year))

failures <- st_as_sf(failures, coords=c("DecimalLongitude","DecimalLatitude"))
st_crs(failures) <- "+proj=longlat +datum=WGS84 +no_defs"

nn_fail <- st_join(failures, geometry, join=st_nn, k=1)%>%
  rename(year_fl=year)

nn_dist <- st_nn(failures, points, k=1, returnDist=TRUE)
nn_fail[["dist"]] <- sapply(nn_dist[[2]], "[", 1)

join <- grid%>%
  left_join(depth)%>%
  left_join(nn_fail)

join <- join%>%
  mutate(failure=year==year_fl)%>%
  within(failure[is.na(failure)]<- FALSE)

dau <- st_transform(dau, "+proj=longlat +datum=WGS84 +no_defs")%>%
  dplyr::select(DAUCO)

join <- join%>%
  select(!geometry)%>%
  left_join(geometry)

join <- st_as_sf(join, sf_column_name="geometry")

merge_final_failures <- st_join(join, dau)

all_weather <- read_dta(file.path(DERIVED, "weather_dauco_annual.dta"))

new_data <- merge_final_failures%>%
  rename(dauco_id=DAUCO)%>%
  left_join(allocations_aggregate_dauco)%>%
  rename(DAUCO=dauco_id)%>%
  left_join(all_weather)%>%
  left_join(dates)

write_dta_df <- data.frame(new_data)%>%
  dplyr::select(!geometry)%>%
  rename(creat_date=CREATE.DATE,
         shortage_type=Shortage.Type,
         primary_usages=Primary.Usages,
         start_date=Approximate.Issue.Start.Date,
         well_depth=Well.Depth,
         well_to_water_depth=Well.to.Water.Depth)

write_dta(write_dta_df, file.path(DERIVED, "domestic_failures_panel.dta"))
