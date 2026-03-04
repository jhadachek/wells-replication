# ==============================================================================
# 04b_failure_maps.R
# Purpose: Well failure maps for Fresno/SJV region and monitoring well locations
# Source:  fresno_failures.R, monitoring wells.R
#
# Inputs:  RAW_DIR/householdwatersupplyshortagereportingsystemdata.csv
#          DERIVED/well_construction2.csv
#          RAW_DIR/gis/PWS_shp/SABL_Public_211025.shp
#          RAW_DIR/nhgis0006_ds249_20205_tract.csv
#          DERIVED/depth_allrawobs.dta
#
# Outputs: FIGURES/fresno_pws.png
#          FIGURES/sjv_density.png
#          FIGURES/cal_hisp.png
#          FIGURES/cal_pov.png
#          FIGURES/cal_failures.png
#
# Paper element: Fresno area PWS vs. well failure locations;
#                SJV population density, demographics, and failure maps;
#                Monitoring well locations across California
#
# Authors: Hadachek et al.
# Date:    2026-03-03
# ==============================================================================

library(here)
# Paths set via code/config.R (run from replication/ directory)
source(here::here("code", "config.R"))

# ==============================================================================
# SECTION 1: Fresno Failure Maps (from fresno_failures.R)
# ==============================================================================

pacman::p_load(readr,tmap,sf, ggplot2, dplyr, ggmap, lubridate, tidyr, stringr, raster, readxl)


HouseholdWater<- read_csv(file.path(RAW_DIR, "householdwatersupplyshortagereportingsystemdata.csv"))

domestic<- read_csv(file.path(DERIVED, "well_construction2.csv"))%>%
  filter(type=="Domestic")%>%
  st_as_sf(coords=c("DecimalLongitude","DecimalLatitude"))%>%
  mutate(year=year(DateWorkEnded))%>%
  filter(year>1950)

domestic<-st_set_crs(domestic, "+proj=longlat +datum=WGS84 +no_defs")%>%
  st_transform(st_crs(counties))%>%
  st_join(counties)

domestic_county<-domestic%>%
  mutate(ALAND=ALAND*0.00000038610, AWATER=AWATER*0.00000038610)%>%
  st_drop_geometry()%>%
  group_by(NAME, ALAND, AWATER)%>%
  summarize(domestic_count=n())%>%
  mutate(domestic_count=domestic_count/(ALAND+AWATER))%>%
  ungroup()%>%
  dplyr::select(-ALAND, -AWATER)%>%
  right_join(counties)%>%
  st_as_sf(sf_column_name="geometry")


HouseholdWater_new<-HouseholdWater%>%
  drop_na(LONGITUDE, LATITUDE)%>%
  #Filter only observations in California
  filter(LONGITUDE< -113)%>%
  #Select only pertinent variables.
  dplyr::select(`CREATE DATE`,
                Status,
                `Shortage Type`,
                `Primary Usages`,
                `Approximate Issue Start Date`,
                LONGITUDE,
                LATITUDE,
                `Well Depth`,
                `Well to Water Depth`)%>%
  #Create dummy if it was a pump issue. Will remove pump data later.
  mutate(pump=str_detect(`Shortage Type`, "pump|Pump"))



failures_sf<-HouseholdWater_new%>%
  st_as_sf(coords=c("LONGITUDE","LATITUDE"))

failures_sf<-st_set_crs(failures_sf, "+proj=longlat +datum=WGS84 +no_defs")

counties<-tigris::counties(state="California")
tracts<-tigris::tracts(state="California")

demographics<- read_csv(file.path(RAW_DIR, "nhgis0006_ds249_20205_tract.csv"))%>%
  filter(STATE=="California")%>%
  dplyr::select(GISJOIN,TRACTA, AMPVE001, AMP3E012, AMR8E001, AMR5E001, AMR5E002, AMPWE002)%>%
  rename(Pop=AMPVE001, HispPop=AMP3E012, MedianIncom=AMR8E001, HH=AMR5E001, HH_pov=AMR5E002, WhitePop=AMPWE002)%>%
  mutate(pct_hisp=HispPop/Pop*100, pct_pov=HH_pov/HH*100, pct_white=WhitePop/Pop*100)%>%
  rename(TRACTCE=TRACTA)%>%
  mutate(TRACTCE=str_pad(TRACTCE, 6, side="left", pad="0"))



tracts<-tracts%>%
  rename(CensusTract=GEOID)%>%
  left_join(demographics)%>%
  mutate(ALAND=ALAND*0.00000038610, AWATER=AWATER*0.00000038610)%>%
  mutate(density=Pop/(ALAND+AWATER))


pws<-st_read(file.path(RAW_DIR, "gis", "SABL_Public_211025.shp"))%>%
  filter(COUNTY=="FRESNO", FEDERAL_CL=="COMMUNITY", BOUNDARY_T=="Water Service Area")%>%
  filter(WATER_SY_1 %in% c("CITY OF FRESNO", "CITY OF CLOVIS"
                           ))



failures_sf<-st_transform(failures_sf, st_crs(counties))
pws<-st_transform(pws, st_crs(counties))


failures_county<-failures_sf%>%
  st_join(counties)%>%
  filter(NAME %in% c("Tulare", "Fresno","San Joaquin","Kern","Madera","Kings","Merced","Stanislaus"))

bbox<-st_bbox(pws)

bbox<-c(-120,36.55, -119.5, 37)

sjv_counties<-counties%>%
  filter(NAME %in% c("Tulare", "Fresno","San Joaquin","Kern","Madera","Kings","Merced","Stanislaus"))




pws_well<-tm_shape(pws, bbox=bbox)+tm_fill(col="blue",alpha=0.5)+
  tm_shape(failures_county)+tm_symbols(col="black", shape=4, size=0.2)+
  tm_shape(counties)+tm_borders(lwd=2)+
  tm_add_legend(type="fill", col="blue", alpha=0.5,labels=("Public Water System Area"))+
  tm_add_legend(type="symbol", col="black", shape=4, labels = "Well Failure")+
  tm_layout(legend.position=c("left","top"))

density<-tm_shape(tracts)+tm_fill(col="density", style = "cont",
                                    title="Population Density (per sq mile)",
                                    breaks = c(0,2000,4000,6000,8000,10000))+
  #tm_shape(failures_county)+tm_symbols(col="black", shape=4, size=0.2)+
  tm_shape(counties)+tm_borders(lwd=1)+
  tm_shape(sjv_counties)+tm_borders(lwd=3, col="black")
  #tm_add_legend(type="symbol", labels="Well Failure", shape=4, col="black")

hisp<-tm_shape(tracts)+tm_fill(col="pct_hisp", style = "cont",
                                    title="% Hispanic Population")+
  #tm_shape(failures_county)+tm_symbols(col="black", shape=4, size=0.2)+
  tm_shape(counties)+tm_borders(lwd=1)+
  tm_shape(sjv_counties)+tm_borders(lwd=3, col="black")

  tm_add_legend(type="symbol", labels="Well Failure", shape=4, col="black")

pov<-tm_shape(tracts)+tm_fill(col="pct_pov", style = "cont",
                                          title="% Below Poverty Line",
                              breaks=c(0,10,20,30,40,50)
                              labels=c("0","10","20","30","40",">50"))+
  #tm_shape(failures_county)+tm_symbols(col="black", shape=4, size=0.2)+
  tm_shape(counties)+tm_borders(lwd=1)+
  tm_shape(sjv_counties)+tm_borders(lwd=3, col="black")

  tm_add_legend(type="symbol", labels="Well Failure", shape=4, col="black")

domestic_map<-tm_shape(domestic_county)+tm_fill(col="domestic_count", style = "cont",
                                 title="Domestic wells (per sq. mile)",
                                 breaks=c(0,1,2,3,4,5))+
    #tm_shape(failures_county)+tm_symbols(col="black", shape=4, size=0.2)+
    tm_shape(counties)+tm_borders(lwd=1)+
    tm_shape(sjv_counties)+tm_borders(lwd=3, col="black")


tmap_save(pws_well, filename = file.path(FIGURES, "fresno_pws.png"))

tmap_save(density, filename = file.path(FIGURES, "sjv_density.png"))
tmap_save(hisp, filename = file.path(FIGURES, "cal_hisp.png"))
tmap_save(pov, filename = file.path(FIGURES, "cal_pov.png"))

failures<-tm_shape(failures_sf)+tm_symbols(col="darkred", shape=4, size=0.1)+
  tm_shape(counties)+tm_borders(lwd=1)+
  tm_shape(sjv_counties)+tm_borders(lwd=3, col="black")+
  tm_add_legend(type="symbol", labels="Well Failure", shape=4, col="darkred")

tmap_save(failures, filename = file.path(FIGURES, "cal_failures.png"))

filter(NAME %in% c("San Joaquin","Kings","Merced","Stanislaus","Fresno","Madera","Tulare"))

# ==============================================================================
# SECTION 2: Monitoring Well Locations (from monitoring wells.R)
# ==============================================================================

depth_allrawobs <- read_dta(file.path(DERIVED, "depth_allrawobs.dta"))

depth_allrawobs<-depth_allrawobs%>%
  select(latitude, longitude, wellid)%>%
  group_by(latitude, longitude, wellid)%>%
  summarize(count=n())%>%
  st_as_sf(coords=c("longitude", "latitude"))


counties<-tigris::counties(state="California")

tm_shape(depth_allrawobs)+tm_symbols(alpha=0.2,size=0.001, shape=21, col="black")+
  tm_shape(counties)+tm_borders()+
  tm_add_legend(type="symbol",labels="Monitoring Well",shape=21, col="black")
