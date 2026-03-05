# ==============================================================================
# 01g_clean_wells.R
# Purpose: Clean OSWCR well completion reports and household water shortage
#          (failure) reports. Produces categorized well datasets and failures.
#
# Source:  cleaning_code/cleaning_wells.R — ported with path substitutions only.
#          No logic altered.
#
# Inputs:
#   RAW_DIR/raw_data/wellcompletionreports.csv
#   RAW_DIR/raw_data/UseCategoryGrouping (1).csv
#   RAW_DIR/raw_data/householdwatersupplyshortagereportingsystemdata.csv
#
# Outputs:
#   DERIVED/well_construction.csv
#   DERIVED/well_destruction.csv
#   DERIVED/well_dd.csv
#   DERIVED/well_maintain.csv
#   DERIVED/failures.csv
#
# Authors: [Author names]
# Date:    2026-03-04
# ==============================================================================

# source config.R — sets ROOT, RAW_DIR, DERIVED, TABLES, FIGURES
source(here::here("code", "config.R"))

pacman::p_load(readr, dplyr, lubridate, stringr)


#####Well Completion Reports######
wells <- read_csv(file.path(RAW_DIR, "raw_data", "wellcompletionreports.csv"))%>%
    rename(PlannedUseFormerUse=PLANNEDUSEFORMERUSE,
           DecimalLongitude=DECIMALLONGITUDE,
           DecimalLatitude=DECIMALLATITUDE,
           RecordType=RECORDTYPE,
           TotalDrillDepth=TOTALDRILLDEPTH,
           TotalCompletedDepth=TOTALCOMPLETEDDEPTH,
           DateWorkEnded=DATEWORKENDED)%>%
    mutate(DateWorkEnded=as.Date(DateWorkEnded, format="%m/%d/%Y"))

UseCategoryGrouping<- read_csv(file.path(RAW_DIR, "raw_data", "UseCategoryGrouping (1).csv"))

UseCategoryGrouping<-UseCategoryGrouping%>%
  rename(PlannedUseFormerUse=OSWCRPlannedUseFormerUse)


wells<-wells%>%
  left_join(UseCategoryGrouping)

new_wells<-wells%>%
#Drop observations with out geographic coordinates
  drop_na(DecimalLongitude, DecimalLatitude)%>%
#Keep only new wells
   filter(RecordType=="WellCompletion/New/Production or Monitoring/NA")

destruct_wells<-wells%>%
  drop_na(DecimalLongitude, DecimalLatitude)%>%
  #Keep only new wells
  filter(RecordType=="WellCompletion/Destruction/NA/NA")

maintain_wells<-wells%>%
  drop_na(DecimalLongitude, DecimalLatitude)%>%
  #Keep only new wells
  filter(RecordType=="WellCompletion/Modification or Repair/Production or Monitoring/NA")

dd_wells<-wells%>%
  drop_na(DecimalLongitude, DecimalLatitude)%>%
  #Keep only new wells
  filter(RecordType=="WellCompletion/Drill and Destroy/NA/NA")


well_type<-function(input=new_wells){

#Filter only wells within California's coordinates extent
new_wells<-input%>%
  within(DecimalLongitude[DecimalLongitude>0]<--1*DecimalLongitude[DecimalLongitude>0])%>%
  filter(between(DecimalLongitude, -125, -113), between(DecimalLatitude, 32,43))


#Select only pertinent variables
new_wells<-new_wells%>%
  dplyr::select(DecimalLongitude,
                DecimalLatitude,
                PlannedUseFormerUse,
                DateWorkEnded,
                TotalDrillDepth,
                TotalCompletedDepth,
                B118WellUse)

##Sort wells by types into more general bins
## NOTE HERE: Agricultural captures both animal agriculture and irrigation. Can revisit later.
wells_filtered<-new_wells%>%
  mutate(Ag=str_detect(PlannedUseFormerUse, "Agri"),
         Domestic=str_detect(PlannedUseFormerUse, "Domestic"),
         Destruct=str_detect(PlannedUseFormerUse, "Destruct"),
        Monitoring=str_detect(PlannedUseFormerUse, "Monitor"),
        Public=str_detect(PlannedUseFormerUse, "Public"),
        None=str_detect(PlannedUseFormerUse, "None"),
        Other=str_detect(PlannedUseFormerUse, "Other"))%>%
        filter(Ag==T | Domestic==T | Public==T | Monitoring==T | None==T | Other==T)

#Create into single character vector
wells_filtered$type<-"NA"
wells_filtered$type[wells_filtered$Ag==TRUE]<-"Agriculture"
wells_filtered$type[wells_filtered$Domestic==TRUE]<-"Domestic"
wells_filtered$type[wells_filtered$Public==TRUE]<-"Public"
wells_filtered$type[wells_filtered$Monitoring==TRUE]<-"Monitoring"
wells_filtered$type[wells_filtered$Other==TRUE]<-"Other"

wells_filtered<-wells_filtered%>%
  dplyr::select(-Ag:-Other)

return(wells_filtered)
}

dd_wells<-well_type(input=dd_wells)
maintain_wells<-well_type(input=maintain_wells)
new_wells<-well_type()
destroy_wells<-well_type(input=destruct_wells)

#Save cleaned well construction data
write.csv(dd_wells, file.path(DERIVED, "well_dd.csv"), row.names=FALSE)
write.csv(maintain_wells, file.path(DERIVED, "well_maintain.csv"), row.names=FALSE)
write.csv(new_wells, file.path(DERIVED, "well_construction.csv"))
write.csv(destroy_wells, file.path(DERIVED, "well_destruction.csv"), row.names=FALSE)

####WELL FAILURE DATA####
HouseholdWater<- read_csv(file.path(RAW_DIR, "raw_data", "householdwatersupplyshortagereportingsystemdata.csv"))

 #Drop observations without geographic identifiers
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


#Saved cleaned failure data
write.csv(HouseholdWater_new, file.path(DERIVED, "failures.csv"))
