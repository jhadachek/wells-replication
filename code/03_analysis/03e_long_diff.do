********************************************************************************
// 03e_long_diff.do
// Purpose: Long-difference regressions estimating effects of cumulative surface
//          water shocks on agricultural well construction and groundwater depth.
// Source:  long_diff.do
//
// Inputs:  $DERIVED/final3.dta          (DAUCO-year panel, ag construction/deliveries)
//          $DERIVED/dtw_long_diff.dta   (long-difference DTW panel)
// Outputs: $TABLES/long_diff1.tex
//
// Paper element: Long Differences table
//
// Authors: [Author names]
// Date:    2026-03-03
********************************************************************************

// Paths set via code/config.do (run from replication/ directory)

********************************************************************************
// PART 1: Compute long-difference variables from DAUCO panel
********************************************************************************

use "$DERIVED/final.dta", clear


drop if DAUCO==.

xtset DAUCO year

gen crop_acres=dauco_area*247.105*dauco_pctcrop
cap drop ag_allocation_acre
gen ag_allocation_acre=pct_allocation_ag*vol_maximum_ag/crop_acres
replace ag_allocation_acre=10 if ag_allocation_acre>10

gen l_ag_allocation_acre=log(ag_allocation_acre)

label var p_construction "count public well construction"
label var cum_sum_p_construction "cumulative total public wells (1701 - to year)"
label var d_depth "average domestic well depth"
label var d_construction "count domestic well construction"
label var cum_sum_d_construction "cumulative total domestic wells (1701 - to year)"
label var depth "average depth of new agricultural wells"
label var failures "count of reported domestic well failures"
label var cum_failures "cumulative number of reported well failures"
label var construction "New Ag Wells per DAUCO"
label var cum_construction "cumulative number of agricultural wells (1701-to year)"
label var hdd "Harmful Degree Days"
label var precip "Annual Precipitation"
label var dday8 "Growing Degree Days"
label var crop_acres "Crop Acres"
label var ag_allocation "total agricultural volume (AF)"
label var ag_allocation_acre "Ag SW Allocation per crop acre (AF)"


gen ag_deliveries_acre=vol_deliv_cy_ag/crop_acres
*Winsorize Deliveries at 10 AF per crop acre
replace ag_deliveries_acre=10 if ag_deliveries_acre>10

gen l_ag_deliveries_acre=log(ag_deliveries_acre)


label var ag_deliveries_acre "Ag SW Deliveries per crop acre (AF)"
label var l_ag_deliveries_acre "log(Ag SW Deliveries per crop acre (AF))"

*Growing degree days between 32 celsius and 8 celsius
gen gdd=dday8-hdd
label var gdd "Growing Degree Days"


bysort DAUCO: egen mean_hdd=mean(hdd)
bysort DAUCO: egen mean_gdd=mean(gdd)
bysort DAUCO: egen mean_precip=mean(precip)
bysort DAUCO: egen mean_ag_deliveries=mean(ag_deliveries_acre)
bysort DAUCO: egen mean_ag_allocations=mean(ag_allocation_acre)

gen vol_maximum_ag_acre=vol_maximum_ag/crop_acres
replace vol_maximum_ag_acre=10 if vol_maximum_ag_acre>10

gen dev_deliveries=ag_deliveries_acre-vol_maximum_ag_acre
gen dev_hdd = hdd-mean_hdd
gen dev_gdd= gdd-mean_gdd
gen dev_precip= precip-mean_precip
gen dev_allocations= ag_allocation_acre-vol_maximum_ag_acre

gen hot_yr=0
replace hot_yr=1 if dev_hdd>0

bysort DAUCO: gen ag_wells_1993=cum_construction if year==1993

bysort DAUCO: egen ag_wells_1993_2=max(ag_wells_1993)


bysort DAUCO: gen ag_wells_2020=cum_construction if year==2020

bysort DAUCO: egen ag_wells_2020_2=max(ag_wells_2020)


gen ag_wells_longdiff=ag_wells_2020_2-ag_wells_1993_2
gen ag_wells_longdiff_share=(ag_wells_2020_2-ag_wells_1993_2)/ag_wells_1993_2



collapse (sum) dev_allocations dev_deliveries dev_hdd dev_precip dev_gdd hdd gdd precip hot_yr (mean) ag_wells_longdiff  ag_wells_longdiff_share crop_acres ag_allocation_acre ag_deliveries_acre, by(DAUCO)


reg ag_wells_longdiff dev_allocations  [w=crop_acres], robust
estimates store ld_wells
ivreg ag_wells_longdiff (dev_deliveries=dev_allocations) [w=crop_acres], robust
estimates store ld_wells_iv

replace dev_allocations=0 if dev_allocations>0

********************************************************************************
// PART 2: Long-difference regressions on groundwater depth
********************************************************************************

use "$DERIVED/dtw_long_diff.dta", clear


reg long_diff dev_allocations  hot_yr [w=crop_acres], robust
estimates store ld_dtw
ivreg long_diff (dev_deliveries=dev_allocations) [w=crop_acres], robust
estimates store ld_dtw_iv

esttab ld_* using "$TABLES/long_diff1.tex", keep( dev_allocations dev_deliveries )  se  replace title("Long Difference Effects of Surface Water Shocks") mgroups("New Ag Wells" "DTW", pattern(1 0 1 0)) width(75%)
