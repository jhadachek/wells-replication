# ==============================================================================
# 02d_failures_depth.R
# Purpose: Add nearest-neighbor groundwater depth observations to each failure
#          record.  For each year, finds the k=5 nearest monitoring wells and
#          attaches their depth-to-water values and distances.
#
# Source:  cleaning_code/failures_depth.R — ported with path substitutions only.
#          No logic altered.
#
# Inputs:
#   DERIVED/gwdepth_raw_obs.dta
#   merge_final_failures   (produced by 02b_failures_panel.R — must be in scope)
#   allocations_aggregate_dauco  (produced by 02b_failures_panel.R — in scope)
#   all_weather            (produced by 02b_failures_panel.R — in scope)
#
# Outputs:
#   DERIVED/domestic_failures_gwdepth.dta
#
# Authors: [Author names]
# Date:    2026-03-04
# ==============================================================================

# source config.R — sets ROOT, RAW_DIR, DERIVED, TABLES, FIGURES
source(here::here("code", "config.R"))

pacman::p_load(dplyr, sf, haven, nngeo)

depth_allrawobs <- read_dta(file.path(DERIVED, "gwdepth_raw_obs.dta"))

depth_points<-st_as_sf(depth_allrawobs, coords=c("longitude", "latitude"))
depth_points<-st_set_crs(depth_points, "+proj=longlat +datum=WGS84 +no_defs")

cnames<-colnames(merge_final_failures)

new_data<-as.data.frame(matrix(data=NA, 0, length(cnames)))
colnames(new_data)<-cnames


for(y in c(seq(2014,2021,1))){
  print(paste("Working on year",y, sep=" "))

  wells<-merge_final_failures%>%
    filter(year==y)


  depth<-depth_points%>%
    filter(year==y)

  nn<-st_nn(wells, depth, k=5, returnDist = TRUE)

  for (i in 1:length(wells$id)){
  wells$near_depth1[i]<-depth$dtw[nn$nn[[i]][1]]
  wells$near_depth2[i]<-depth$dtw[nn$nn[[i]][2]]
  wells$near_depth3[i]<-depth$dtw[nn$nn[[i]][3]]
  wells$near_depth4[i]<-depth$dtw[nn$nn[[i]][4]]
  wells$near_depth5[i]<-depth$dtw[nn$nn[[i]][5]]


  wells$near_dist1[i]<-nn$dist[[i]][1]
  wells$near_dist2[i]<-nn$dist[[i]][2]
  wells$near_dist3[i]<-nn$dist[[i]][3]
  wells$near_dist4[i]<-nn$dist[[i]][4]
  wells$near_dist5[i]<-nn$dist[[i]][5]


}


new_data<-rbind(new_data, wells)
}

merge_final<-new_data%>%
  rename(dauco_id=DAUCO)%>%
  left_join(allocations_aggregate_dauco)%>%
  rename(DAUCO=dauco_id)%>%
  left_join(all_weather)

merge_final<-data.frame(merge_final)%>%
  dplyr::select(!geometry)

merge_final<-merge_final%>%
  rename(create_date=CREATE.DATE,
         shortage_type=Shortage.Type,
         primary_usages=Primary.Usages,
         start_date=Approximate.Issue.Start.Date,
         well_depth=Well.Depth,
         well_to_water_depth=Well.to.Water.Depth)

write_dta(merge_final, file.path(DERIVED, "domestic_failures_gwdepth.dta"))
