# ==============================================================================
# 04a_maps.R
# Purpose: Groundwater depth change maps and agricultural well location maps
# Source:  depth_map.R, water_wells_map.R
#
# Inputs:  DERIVED/all_wells2.dta
#          RAW_DIR/gis/DAU_County_2018.shp
#          DERIVED/allocations_aggregate_dauco.dta
#          DERIVED/well_construction2.csv
#
# Outputs: FIGURES/ag_sw_cross.png
#          FIGURES/ag_wells_cross2.png
#
# Paper element: Groundwater depth change maps (long-run DTW shift by DAU);
#                Agricultural surface water allocation maps;
#                New agricultural well counts by DAU
#
# Authors: Hadachek et al.
# Date:    2026-03-03
# ==============================================================================

library(here)
# Paths set via code/config.R (run from replication/ directory)
source(here::here("code", "config.R"))

# ==============================================================================
# SECTION 1: Groundwater Depth Maps (from depth_map.R)
# ==============================================================================

pacman::p_load(dplyr, tmap, haven, tidyr, ggplot2, sf)

all_wells2 <- read_dta(file.path(DERIVED, "all_wells2.dta"))

grid<-expand.grid(wellid=unique(all_wells2$wellid), year=unique(all_wells2$year))%>%
  left_join(all_wells2)

grid_final<-grid%>%
  arrange(wellid, year)%>%
  group_by(wellid,year)%>%
  ungroup()%>%
  group_by(wellid)%>%
  mutate(dtw2=lead(dtw,1,default=NA), diff_depth=dtw2-lag(dtw2, 1, default=NA))%>%
  group_by(DAUCO)%>%
  mutate(pct90=quantile(diff_depth, .9, na.rm=T)*1.5)%>%
  filter(pct90>abs(diff_depth))


by_year<-all_wells2%>%
  group_by(wellid)%>%
  filter(year>=1981 & year<2021)%>%
  mutate(n=n())%>%
  filter(n>=30)%>%
  group_by(year)%>%
  summarize(dtw=mean(dtw))


ggplot(by_year)+geom_line(aes(year, dtw), color="darkblue", lwd=2)+
  theme_minimal()+
  scale_y_reverse(limits=c(100,60))+
  ylab("Avg. Depth to the Groundwater (ft)")+
  xlab("")




long_change<-all_wells2%>%
  filter(year %in% c(1981, 1982,1983, 2018,2019,2020))%>%
  select(wellid,DAUCO, year, dtw)%>%
  mutate(period=1)%>%
  within(period[year>2000]<-2)%>%
  group_by(wellid,DAUCO, period)%>%
  summarize(dtw=mean(dtw, na.rm=T))%>%
  pivot_wider(id_cols=c("wellid", "DAUCO"), values_from="dtw", names_from="period", names_prefix="dtw")%>%
  mutate(diff=dtw2-dtw1)

summary(long_change$diff)

dau<-st_read(file.path(RAW_DIR, "gis", "DAU_County_2018.shp"))%>%
  mutate(DAUCO=as.numeric(DAUCO))

dauco_long<-long_change%>%
  left_join(dau)%>%
  group_by(DAUCO)%>%
  summarize(diff=mean(diff, na.rm=T))

dauco_map<-dau%>%
  left_join(dauco_long)%>%
  st_as_sf()


tm_shape(dauco_map)+tm_polygons(fill="diff",
                                fill.scale = tm_scale_continuous(values="bu_rd",
                                                                 value.na="gray"
                                                                 ),
                                fill.legend = tm_legend("Long Diff \n DTW (ft)")
                                )


# ==============================================================================
# SECTION 2: Well Location Maps (from water_wells_map.R)
# ==============================================================================

pacman::p_load(sf, dplyr, tmap, haven)

allocations_aggregate_dauco <- read_dta(file.path(DERIVED, "allocations_aggregate_dauco.dta"))%>%
  select(dauco_id, year, pct_allocation_ag)%>%
  mutate(pct_allocation_ag=pct_allocation_ag*100)

dau<-st_read(file.path(RAW_DIR, "gis", "DAU_County_2018.shp"))%>%
  mutate(DAUCO=as.numeric(DAUCO))



allocations_1994<-allocations_aggregate_dauco%>%
  filter(year==1994)


allocations_2005<-allocations_aggregate_dauco%>%
  filter(year==2005)


allocations_2015<-allocations_aggregate_dauco%>%
  filter(year==2015)


map_1994<-allocations_1994%>%
  rename(DAUCO=dauco_id)%>%
  right_join(dau)%>%
  st_as_sf(sf_column_name = "geometry")%>%
  tm_shape()+tm_borders()+
  tm_fill(col="pct_allocation_ag",
       style="cont",
       palette = "-OrRd",
       title="Ag Allocation %",
       breaks=c(0,20,40,60,80,100),
       legend.show = FALSE)+
  tm_layout(main.title="1994")

map_1994


map_2006<-allocations_2006%>%
  rename(DAUCO=dauco_id)%>%
  right_join(dau)%>%
  st_as_sf(sf_column_name = "geometry")%>%
  tm_shape()+tm_borders()+
  tm_fill(col="pct_allocation_ag",
          style="cont",
          palette = "-OrRd",
          title="Ag Allocation %",
          breaks=c(0,20,40,60,80,100),
          legend.show = FALSE)+
  tm_layout(main.title="2006")


map_2006


map_2015<-allocations_2015%>%
  rename(DAUCO=dauco_id)%>%
  right_join(dau)%>%
  st_as_sf(sf_column_name = "geometry")%>%
  tm_shape()+tm_borders()+
  tm_fill(col="pct_allocation_ag",
          style="cont",
          palette = "-OrRd",
          title="Allocation %")+
  tm_layout(main.title="2015")


map_2015

ag_sw<-tmap_arrange(map_1994,map_2006, map_2015, nrow=1)
ag_sw


tmap_save(ag_sw, file.path(FIGURES, "ag_sw_cross.png"), width=7, height=5)


well_construction <- read_csv(file.path(DERIVED, "well_construction2.csv"))%>%
  #Filters out Monitoring Wells
  filter(type=="Agriculture")

new_wells<-well_construction%>%
  #filter(type==paste(well_type))%>%
  mutate(year=year(DateWorkEnded))

well_year<-new_wells%>%
  drop_na(DecimalLatitude)%>%
  dplyr::select(DecimalLongitude, DecimalLatitude, TotalCompletedDepth, year)

#Converts to spatial dataframe
points<-st_as_sf(well_year, coords=c("DecimalLongitude", "DecimalLatitude"))
points<-st_set_crs(points, "+proj=longlat +datum=WGS84 +no_defs" )

#Converts to the same CRS
dau<-st_transform(dau, st_crs(points))%>%
  dplyr::select(DAUCO)

merge_final<-st_join(points, dau)


tmp<-data.frame(merge_final)%>%
  dplyr::select(!geometry)%>%
  group_by(DAUCO, year)%>%
  summarize(outcome=n())

wells_2015<-tmp%>%
  filter(year==2015)%>%
  right_join(dau)%>%
  within(outcome[is.na(outcome)==T]<- 0)%>%
  st_as_sf(sf_column_name = "geometry")%>%
  tm_shape()+tm_borders()+
  tm_fill(col="outcome",
          style="cont",
          breaks=c(0,10,20,30,40,50),
          labels=c("0","10","20","30","40",">50"),
          palette="BuGn",
          title="New Ag Wells")+
  tm_layout(main.title="2015")

wells_2015


wells_2006<-tmp%>%
  filter(year==2006)%>%
  right_join(dau)%>%
  within(outcome[is.na(outcome)==T]<- 0)%>%
  st_as_sf(sf_column_name = "geometry")%>%
  tm_shape()+tm_borders()+
  tm_fill(col="outcome",
          style="cont",
          breaks=c(0,10,20,30,40,50),
          labels=c("0","10","20","30","40",">50"),
          palette = "BuGn",
          title="Count of Wells",
          legend.show=FALSE)+
  tm_layout(main.title="2006")

wells_2006


wells_1994<-tmp%>%
  filter(year==1994)%>%
  right_join(dau)%>%
  within(outcome[is.na(outcome)==T]<- 0)%>%
  st_as_sf(sf_column_name = "geometry")%>%
  tm_shape()+tm_borders()+
  tm_fill(col="outcome",
          style="cont",
          breaks=c(0,10,20,30,40,50),
          labels=c("0","10","20","30","40",">50"),
          palette = "BuGn",
          title="Count of Wells",
          legend.show=FALSE)+
  tm_layout(main.title="1994")

wells_1994


wells<-tmap_arrange(wells_1994,wells_2006, wells_2015, nrow=1)
wells

tmap_save(wells, file.path(FIGURES, "ag_wells_cross2.png"), height=5, width=7)
