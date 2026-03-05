********************************************************************************
// 03a_summary_stats.do
// Purpose: Produce summary statistics tables for agricultural wells, groundwater
//          depth, and domestic well failures panels.
// Source:  summarystats.do
//
// Inputs:  $DERIVED/dauco_construction_panel.dta  (DAUCO-year panel, ag construction/deliveries)
//          $DERIVED/gwdepth_well_panel.dta        (well-level groundwater depth panel)
//          $DERIVED/domestic_failures_panel.dta   (domestic well failures panel)
// Outputs: $TABLES/summarystats.tex
//
// Paper element: Summary Statistics table
//
// Authors: [Author names]
// Date:    2026-03-03
********************************************************************************

// Paths set via code/config.do (run from replication/ directory)

********************************************************************************
// PANEL 1: Agricultural construction and surface water deliveries
********************************************************************************

use "$DERIVED/dauco_construction_panel.dta"

drop if DAUCO==.

xtset DAUCO year

label var construction "New Ag Wells per DAUCO"
label var hdd "Harmful Degree Days"
label var precip "Annual Precipitation"
label var crop_acres "Crop Acres"
label var ag_allocation_acre "Ag SW Allocation per crop acre (AF)"
gen l_ag_allocation_acre=log(ag_allocation_acre)
label var l_ag_allocation_acre "log(Ag SW per crop acre (AF))"

gen ag_deliveries_acre=vol_deliv_cy_ag/crop_acres
replace ag_deliveries_acre=10 if ag_deliveries_acre>10

gen l_ag_deliveries_acre=log(ag_deliveries_acre)


label var ag_deliveries_acre "Ag SW Deliveries per crop acre (AF)"
label var l_ag_deliveries_acre "log(Ag SW Deliveries per crop acre (AF))"


gen gdd=dday8-hdd
label var gdd "Growing Degree Days"


estpost sum construction ag_allocation_acre ag_deliveries_acre hdd gdd precip crop_acres  [weight=crop_acres] if year<2021
estimates store sumstats1

// .html output omitted (not needed for AEA package)
esttab  sumstats1 using "$TABLES/summarystats.tex", label replace cells("count mean(fmt(3)) sd(fmt(3)) min max") noobs not nonumbers


********************************************************************************
// PANEL 2: Well-level groundwater depth
********************************************************************************

use "$DERIVED/gwdepth_well_panel.dta", clear

xtset wellid year


gen dtw2=F.dtw

gen diff_depth=dtw2 - L.dtw2


gen crop_acres=dauco_area*247.105*dauco_pctcrop
gen ag_allocation_acre=pct_allocation_ag*vol_maximum_ag/crop_acres
replace ag_allocation_acre=10 if ag_allocation_acre>10

gen l_ag_allocation_acre=log(ag_allocation_acre)
gen ag_deliv_acre=vol_deliv_cy_ag/crop_acres
replace ag_deliv_acre=10 if ag_deliv_acre>10

gen l_ag_deliv_acre=log(ag_deliv_acre)

gen gdd=dday8-hdd

label var diff_depth "\Delta DTW"
label var dtw2 "Depth to Groundwater (ft)"
bysort DAUCO: egen pct90=pctile(diff_depth), p(90)

drop if abs(diff_depth)>1.5*pct90


estpost tabstat dtw2 diff_depth  [weight=crop_acres] if year<2021, statistics(count mean sd min max) columns(statistics)
estimates store sumstats2

// .html output omitted (not needed for AEA package)
esttab sumstats2 using "$TABLES/summarystats.tex", label append cells("count mean(fmt(3)) sd(fmt(3)) min max") noobs not nonumbers


********************************************************************************
// PANEL 3: Domestic well failures
********************************************************************************

use "$DERIVED/domestic_failures_panel.dta", clear

egen wellid=group(id)

gen crop_acres=dauco_area*247.105*dauco_pctcrop
gen ag_allocation_acre=pct_allocation_ag*vol_maximum_ag/crop_acres
replace ag_allocation_acre=10 if ag_allocation_acre>10

gen l_ag_allocation_acre=log(ag_allocation_acre)
gen ag_deliv_acre=vol_deliv_cy_ag/crop_acres
replace ag_deliv_acre=10 if ag_deliv_acre>10

gen l_ag_deliv_acre=log(ag_deliv_acre)

gen gdd=dday8-hdd



label var l_ag_allocation_acre "log(Ag SW Allocation per crop acre (AF))"
label var ag_allocation_acre "Ag SW Allocation per crop acre (AF)"

label var l_ag_deliv_acre "log(Ag SW Deliveries per crop acre (AF))"
label var ag_deliv_acre "Ag SW Deliveries per crop acre (AF)"

label var hdd "Harmful Degree Days"
label var gdd "Growing Degree Days"
label var precip "Precipitation (mm)"

gen uniqueid=_n

bysort uniqueid: egen dist1=min(dist)
bysort wellid: egen min_dist=min(dist)




keep if dist1==min_dist| dist==.
tab failure
bysort wellid year: gen count=_N
tab count
bysort wellid: egen min_date=min(date)
keep if date==min_date | date==.
drop count
bysort wellid year: gen count=_N
tab failure
tab count
bysort wellid year: gen count2=_n
keep if count2==1
tab failure
tab count

label var failure "Domestic Well Failure (0,1)"

estpost tabstat failure  [weight=crop_acres] if year<2021 & year>2014, statistics(count mean sd min max) columns(statistics)
estimates store sumstats3

// .html output omitted (not needed for AEA package)
esttab sumstats3 using "$TABLES/summarystats.tex", label append cells("count mean(fmt(3)) sd(fmt(3)) min max") noobs not nomtitles nonumbers
