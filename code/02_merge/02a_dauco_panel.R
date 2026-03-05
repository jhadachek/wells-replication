# ==============================================================================
# 02a_dauco_panel.R
# Purpose: Spatially aggregate well completion data to DAU-county (DAUCO) ×
#          year panel, merge with weather and surface water allocations, and
#          produce the main ag-construction analytical panel (dauco_construction_panel.dta).
#
# Source:  cleaning_code/dau_simplified.R — ported with path substitutions.
#          Dead code and unused packages removed.
#
# Inputs:
#   RAW_DIR/gis/DAU_County_2018/DAU_County_2018.shp
#   DERIVED/well_construction.csv
#   DERIVED/well_destruction.csv
#   DERIVED/well_dd.csv
#   DERIVED/well_maintain.csv
#   DERIVED/failures.csv
#   DERIVED/weather_dauco_annual.dta
#   DERIVED/dauco_gwdepth_annual.dta   (DAUCO × year average GW depth, from 02c)
#
# Outputs:
#   DERIVED/dauco_construction_panel.dta   (DAUCO-year ag construction panel)
#
# Authors: [Author names]
# Date:    2026-03-04
# ==============================================================================

# source config.R — sets ROOT, RAW_DIR, DERIVED, TABLES, FIGURES
source(here::here("code", "config.R"))

pacman::p_load(sf, readr, dplyr, lubridate, haven)

#Read in the Detailed Analysis Unit boundary shapefile
dau <- st_read(file.path(RAW_DIR, "gis", "DAU_County_2018", "DAU_County_2018.shp"))%>%
  mutate(DAUCO=as.numeric(DAUCO))


###############AGGREGATION FUNCTION#########################
#Function that aggregates Well Completion data to DAU by CO
# Inputs: well_type = "all" or "Agriculture" or "Domestic"
#         measure   = "count" or "depth"

wells_to_dau <- function(well_type="all", measure="count", input_data="construction"){

#Loads Well Completion Data
well_construction <- read_csv(file.path(DERIVED, "well_construction.csv"))%>%
  filter(type!="Monitor")

well_destruction <- read_csv(file.path(DERIVED, "well_destruction.csv"))
well_dd          <- read_csv(file.path(DERIVED, "well_dd.csv"))
well_maintain    <- read_csv(file.path(DERIVED, "well_maintain.csv"))

failures <- read_csv(file.path(DERIVED, "failures.csv"))%>%
  rename(DecimalLongitude=LONGITUDE, DecimalLatitude=LATITUDE, TotalCompletedDepth=`Well Depth`)%>%
  mutate(date=as.Date(`CREATE DATE`, format="%m/%d/%Y"), year=year(date))

if (input_data=="failure"){
  well_construction <- failures%>%rename(DateWorkEnded=date)
}else if(input_data=="destruction"){
  well_construction <- well_destruction
}else if(input_data=="dd"){
  well_construction <- well_dd
}else if(input_data=="maintain"){
  well_construction <- well_maintain
}

#List of years in final panel
if (input_data %in% c("construction", "destruction", "dd","maintain")){
  year_list <- as.character(seq(1701,2021,1))
} else{
  year_list <- as.character(seq(2014,2021,1))
}

if (well_type=="all"){
  new_wells <- well_construction%>%
    mutate(year=year(DateWorkEnded))
}else{
  new_wells <- well_construction%>%
    filter(type==paste(well_type))%>%
    mutate(year=year(DateWorkEnded))
}

#Selects only the columns needed
well_year <- new_wells%>%
  drop_na(DecimalLatitude)%>%
  dplyr::select(DecimalLongitude, DecimalLatitude, TotalCompletedDepth, year)

#Converts to spatial dataframe
points <- st_as_sf(well_year, coords=c("DecimalLongitude", "DecimalLatitude"))
points <- st_set_crs(points, "+proj=longlat +datum=WGS84 +no_defs")

#Converts to the same CRS
dau <- st_transform(dau, st_crs(points))%>%
  dplyr::select(DAUCO)

merge_final <- st_join(points, dau)

#Calculates the outcome at the DAU by CO level
if (measure=="count"){
  tmp <- data.frame(merge_final)%>%
    dplyr::select(!geometry)%>%
    group_by(DAUCO, year)%>%
    summarize(outcome=n())
} else{
  tmp <- data.frame(merge_final)%>%
    drop_na(TotalCompletedDepth)%>%
    group_by(DAUCO, year)%>%
    summarize(outcome=mean(TotalCompletedDepth))
}

#Dataframe with a unique row for each DAU by Co and year
grid <- expand.grid(DAUCO=unique(dau$DAUCO), year=as.numeric(year_list))

#If NA values for wells constructed, turn to 0.
#If Depth measure, leave as NA
if (measure=="count"){
  grid <- grid%>%
    left_join(tmp)%>%
    within(outcome[is.na(outcome)]<- 0)%>%
    arrange(DAUCO, year)%>%
    group_by(DAUCO)%>%
    mutate(cum_sum_outcome=cumsum(outcome))
}else{
  grid <- grid%>%
    left_join(tmp)
}

grid <- data.frame(grid)%>%
  filter(year>=1993 & year<=2021)

return(grid)
}

failure       <- wells_to_dau(well_type="all",         measure="count", input_data="failure")%>%
  rename(failures=outcome, cum_failures=cum_sum_outcome)

ag            <- wells_to_dau(well_type="Agriculture", measure="count")%>%
  rename(construction=outcome, cum_construction=cum_sum_outcome)

ag_depth      <- wells_to_dau(well_type="Agriculture", measure="depth")%>%
  rename(depth=outcome)

domestic      <- wells_to_dau(well_type="Domestic",    measure="count")%>%
  rename(d_construction=outcome, cum_sum_d_construction=cum_sum_outcome)

domestic_depth <- wells_to_dau(well_type="Domestic",   measure="depth")%>%
  rename(d_depth=outcome)

public        <- wells_to_dau(well_type="Public",      measure="count")%>%
  rename(p_construction=outcome, cum_sum_p_construction=cum_sum_outcome)

all_weather <- read_dta(file.path(DERIVED, "weather_dauco_annual.dta"))
dauco_gwdepth_annual <- read_dta(file.path(DERIVED, "dauco_gwdepth_annual.dta"))

ag <- ag%>%
  left_join(all_weather)

ag_failures <- failure%>%
  dplyr::select(DAUCO, year, failures, cum_failures)%>%
  right_join(ag)

ag_fail_depth <- ag_depth%>%
  dplyr::select(DAUCO, year, depth)%>%
  right_join(ag_failures)

ag_domestic <- domestic%>%
  dplyr::select(DAUCO, year, d_construction, cum_sum_d_construction)%>%
  right_join(ag_fail_depth)

full_data <- domestic_depth%>%
  dplyr::select(DAUCO, year, d_depth)%>%
  right_join(ag_domestic)

full_data <- public%>%
  dplyr::select(DAUCO, year, p_construction, cum_sum_p_construction)%>%
  right_join(full_data)

full_data <- full_data%>%
  left_join(dauco_gwdepth_annual)

full_data <- full_data%>%
  mutate(total_acres          = dauco_area*247.105,
         crop_acres           = total_acres*dauco_pctcrop,
         ag_allocation        = pct_allocation_ag*vol_maximum_ag,
         ag_allocation_totacre = ag_allocation/total_acres,
         ag_construction_totacre = construction/total_acres,
         ag_allocation_acre   = ag_allocation/crop_acres,
         ag_construction_acre = construction/crop_acres,
         prop_fail            = failures/cum_sum_d_construction)%>%
  group_by(DAUCO)%>%
  mutate(diff_depth       = av_depth - dplyr::lag(av_depth, 1),
         diff_w_depth     = depth    - dplyr::lag(depth, 1),
         diff_w_dom_depth = d_depth  - dplyr::lag(d_depth, 1),
         lag_allocation_ag = dplyr::lag(ag_allocation_acre, 1))

full_data <- full_data%>%
  within(ag_allocation_acre[ag_allocation_acre>10]<-10)

write_dta(full_data, file.path(DERIVED, "dauco_construction_panel.dta"))
