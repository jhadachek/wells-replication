# ==============================================================================
# 04c_env_justice.R
# Purpose: Environmental justice analysis — spatial join of well failures to
#          SB535 Disadvantaged Community census tracts; IV regression on
#          agricultural water delivery and failure rates
# Source:  SB535_tracts.R
#
# Inputs:  DERIVED/domestic_failures_panel.dta
#          RAW_DIR/SB535DACresultsdatadictionary_F_2022.xlsx
#
# Outputs: DERIVED/failures_SB535.dta
#
# Paper element: Environmental justice / DAC tract classification of well
#                failures; IV (2SLS) regressions on failure rates
#
# Authors: Hadachek et al.
# Date:    2026-03-03
# ==============================================================================

library(here)
# Paths set via code/config.R (run from replication/ directory)
source(here::here("code", "config.R"))

pacman::p_load(dplyr, MASS, ggplot2, hrbrthemes, haven, tigris, sf, fixest, readxl)

df <- read_dta(file.path(DERIVED, "domestic_failures_panel.dta")) %>%
  rename(failure = treat)

# Parse each character string into numeric vector
df$lon <- sapply(df$id, function(x) as.numeric(strsplit(gsub("[c()]", "", x), ",")[[1]])[1])
df$lat <- sapply(df$id, function(x) as.numeric(strsplit(gsub("[c()]", "", x), ",")[[1]])[2])


failures_sf<-st_as_sf(df, coords = c("lon", "lat"), crs=4326)

SB535 <- read_excel(file.path(RAW_DIR, "SB535DACresultsdatadictionary_F_2022.xlsx"),
                    sheet = "SB535 tract list (2022)")

SB535 <- read_excel(file.path(RAW_DIR, "SB535DACresultsdatadictionary_F_2022.xlsx"),
                    sheet = "SB535 tract list (2022)")


census<-tracts(state="CA",cb=T, year=2010)


census<-st_transform(census, crs=st_crs(failures_sf))


census_merge<-census%>%
  mutate(GEOID=paste(STATE, COUNTY, TRACT, sep=""))%>%
  dplyr::select(GEOID)%>%
  mutate(GEOID=as.numeric(GEOID))

SB535_merge<-SB535%>%
  rename(GEOID=`Census Tract`)%>%
  dplyr::select(GEOID, `Total Population`)

census_SB535<- census_merge%>%
  left_join(SB535_merge)%>%
  dplyr::mutate(SB535_tract= 1 - as.numeric(is.na(`Total Population`)))




failures_SB535<-st_join(failures_sf, census_SB535)

failures_df<-st_drop_geometry(failures_SB535)%>%
  dplyr::select(-`Total Population`)

write_dta(failures_df, file.path(DERIVED, "failures_SB535.dta"))

failures<-failures_SB535%>%
  filter(year>2014, year<2021)%>%
  mutate(
    total_acres = dauco_area*247.105,
    crop_acres=total_acres*dauco_pctcrop,
    ag_allocation = pct_allocation_ag*vol_maximum_ag,
    ag_allocation_acre=ag_allocation/crop_acres,
    ag_deliv_acre=vol_deliv_cy_ag/crop_acres)%>%
  within(ag_allocation_acre [ag_allocation_acre>10]<- 10)%>%
  within(ag_deliv_acre [ag_deliv_acre>10]<- 10)



feols(data=failures, failure~hdd+dday8+precip|id+year|ag_deliv_acre~ag_allocation_acre, cluster="DAUCO", weights=failures$crop_acres)


failures_dauco<-failures%>%
  group_by(DAUCO, year)%>%
  summarize(failures=sum(failure),
            count=n(),
            crop_acres=mean(crop_acres, na.rm=T),
            ag_allocation_acre=mean(ag_allocation_acre, na.rm=T),
            ag_deliv_acre=mean(ag_deliv_acre, na.rm=T),
            weight=count*crop_acres,
            hdd=mean(hdd),
            gdd=mean(dday8),
            precip=mean(precip))%>%
  mutate(fr=failures/count)


feols(data=failures_dauco, fr~gdd+hdd+precip|DAUCO+year|ag_deliv_acre~ag_allocation_acre, cluster="DAUCO", weights=failures_dauco$weight)
