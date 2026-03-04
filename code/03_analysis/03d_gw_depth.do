********************************************************************************
// 03d_gw_depth.do
// Purpose: Estimate panel regressions for groundwater depth (DTW).
//          Reduced form and IV specifications with adjusted weights.
//          Includes robustness checks with lagged specifications.
// Source:  gwdepth_table_2024.do
//
// Inputs:  $DERIVED/all_wells2.dta  (monitoring well × year panel)
//
// Outputs: $TABLES/wells_adjweight2.tex   (main IV results)
//          $TABLES/wells_levels.tex       (levels specification, if present)
//
// Paper element: Groundwater Depth table
//
// Authors: [Author names]
// Date:    2026-03-03
********************************************************************************

clear all

// Paths set via code/config.do (run from replication/ directory)

use "$DERIVED/all_wells2.dta", clear



 xtset wellid year


*GW Depth measure for prior to next year's growing season. Current year's observation is taken before a majority of water is pumped.
gen dtw2=F.dtw

*Gen delta DTW
gen diff_depth=dtw2 - L.dtw2

*Calculate the 90th percentile change in local groundwater depth
bysort DAUCO: egen pct90=pctile(diff_depth), p(90)

*Tranform variables
gen crop_acres=dauco_area*247.105*dauco_pctcrop
cap drop ag_allocation_acre
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
label var precip "Annual Precipitation (mm)"




********************************************************************************
**************1. SW Allocation and Deliveries on GW Depth***********************
********************************************************************************


preserve
bysort DAUCO year: gen numb_wells=_N
gen w=crop_acres/numb_wells

drop if abs(diff_depth)>1.5*pct90
sum diff_depth
xtset wellid year




ivreghdfe diff_depth ag_allocation_acre [weight=w] if year<2021 &  year>1992, a(year wellid) cluster (DAUCO)
estadd local weights "Crop Acres/# wells"
estadd local time "\checkmark"
estadd local individual "\checkmark"
estimates store rf_lvl1



ivreghdfe diff_depth ag_allocation_acre  hdd gdd  precip if year<2021 [weight=w], abs(wellid year) cluster (DAUCO)
estadd local weights "Crop Acres/# wells"
estadd local time "\checkmark"
estadd local individual "\checkmark"
estimates store rf_lvl2

// restore  // NOTE: removed — IV models must also run on filtered data (inside preserve)


ivreghdfe diff_depth (ag_deliv_acre=ag_allocation_acre)  [weight=w], abs(wellid year) cluster (DAUCO)
estadd local weights "Crop Acres/# wells"
estadd local time "\checkmark"
estadd local individual "\checkmark"
estimates store iv_lvl


ivreghdfe diff_depth (ag_deliv_acre=ag_allocation_acre) hdd gdd precip* [weight=w] if year<2021, abs(wellid year) cluster (DAUCO)
estadd local weights "Crop Acres/# wells"
estadd local time "\checkmark"
estadd local individual "\checkmark"
estimates store iv_lvl_ppt

restore  // closes preserve at line 71



esttab rf* iv* using "$TABLES/wells_adjweight2.tex",booktabs keep(ag_allocation_acre ag_deliv_acre hdd ) order(ag_allocation_acre ag_deliv_acre hdd) label se mgroups("Reduced Form" "IV", pattern(1 0  1 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) nomtitles scalar("N_g N Groups" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE") replace title("Changes in GW Depth") note("Note: Dependent variable is the change in the depth to the groundwater from the surface (ft) from 1994-2020 at the monitoring well level. Columns (1) and (2) report results from the reduced-form OLS model. Columns (3) and (4) report the second-stage IV results, where Ag surface water allocations are used as an instrument. All regressions are weighted by the DAUCO crop acres divided by the numbr of monitoring wells and include year and DAUCO fixed effects. Standard errors are clustered at the DAUCO level and are reported in parentheses.")

capture restore


************************************Robustness Checks**********************************

// Re-generate w and sort panel (restore cleared the preserve block's state)
bysort DAUCO year: gen numb_wells2 = _N
gen w = crop_acres / numb_wells2
sort wellid year
xtset wellid year

rename ag_deliv_acre ag_deliveries_acre

ivreghdfe diff_depth hdd gdd precip (ag_deliveries_acre = ag_allocation_acre) [weight=w] if year<2021, abs(wellid year) cluster(DAUCO)
estimates store iv_lag0
estadd local weights "Crop Acres/# wells"
estadd local time "\checkmark"
estadd local individual "\checkmark"

test hdd=0
estadd scalar cumu1=_b[hdd]
estadd scalar p1=r(p)
test ag_deliveries_acre=0
estadd scalar cumu2=_b[ag_deliveries_acre]

estimates restore iv_lag0
margins, expression (_b[ag_deliveries_acre]) post
estimates store sw0
estadd scalar p2=r(p)



ivreghdfe diff_depth L(0/1).hdd  gdd precip (L(0/1).ag_deliveries_acre= L(0/1).ag_allocation_acre) [weight=w] if year<2021, abs(wellid year) cluster(DAUCO)
estimates store iv_lag1
estadd local weights "Crop Acres/# wells"
estadd local time "\checkmark"
estadd local individual "\checkmark"


estimates restore iv_lag1

lincom hdd+L.hdd
estadd scalar cumu1=r(estimate)
estadd scalar se1=r(se)
lincom ag_deliveries_acre+L.ag_deliveries_acre

margins, expression (_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre]) post
estimates store sw1


estadd scalar cumu2=r(estimate)
estadd scalar se2=r(se)


ivreghdfe diff_depth L(0/2).hdd  gdd precip (L(0/2).ag_deliveries_acre= L(0/2).ag_allocation_acre)  [weight=w] if year<2021, abs(wellid year) cluster(DAUCO)
estimates store iv_lag2
estadd local weights "Crop Acres/# wells"
estadd local time "\checkmark"
estadd local individual "\checkmark"

lincom hdd+L.hdd+L2.hdd
estadd scalar cumu1=r(estimate)
estadd scalar se1=r(se)
lincom ag_deliveries_acre+L.ag_deliveries_acre+L2.ag_deliveries_acre

estimates restore iv_lag2
margins, expression (_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre] + _b[L2.ag_deliveries_acre]) post
estimates store sw2

estadd scalar cumu2=r(estimate)
estadd scalar se2=r(se)


forvalues i= 1(1)6{
	gen diff_depth`i' = L`i'.diff_depth

}

forvalues i=0(1)6{
ivreghdfe diff_depth L(0/`i').hdd  gdd precip (L(0/`i').ag_deliveries_acre= L(0/`i').ag_allocation_acre) [weight=w] if year<2021, abs(wellid year) cluster(DAUCO)

}
estimates store iv_lag3
estadd local weights "Crop Acres/# wells"
estadd local time "\checkmark"
estadd local individual "\checkmark"


lincom hdd+L.hdd+L2.hdd+L3.hdd
estadd scalar cumu1=r(estimate)
estadd scalar se1=r(se)
lincom ag_deliveries_acre+L.ag_deliveries_acre+L2.ag_deliveries_acre+L3.ag_deliveries_acre

estimates restore iv_lag3
margins, expression (_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre] + _b[L2.ag_deliveries_acre]+ _b[L3.ag_deliveries_acre]) post
estimates store sw3
estadd scalar cumu2=r(estimate)
estadd scalar se2=r(se)


ivreghdfe diff_depth L(0/4).hdd gdd precip (L(0/4).ag_deliveries_acre= L(0/4).ag_allocation_acre) [weight=w] if year<2021, abs(wellid year) cluster(DAUCO)
estimates store iv_lag4
estadd local weights "Crop Acres/# wells"
estadd local time "\checkmark"
estadd local individual "\checkmark"

lincom hdd+L.hdd+L2.hdd+L3.hdd+L4.hdd
estadd scalar cumu1=r(estimate)
estadd scalar se1=r(se)
lincom ag_deliveries_acre+L.ag_deliveries_acre+L2.ag_deliveries_acre+L3.ag_deliveries_acre+L4.ag_deliveries_acre

estimates restore iv_lag4
margins, expression (_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre] + _b[L2.ag_deliveries_acre]+ _b[L3.ag_deliveries_acre] + _b[L4.ag_deliveries_acre]) post
estimates store sw4
estadd scalar cumu2=r(estimate)
estadd scalar se2=r(se)

ivreghdfe diff_depth L(0/5).hdd gdd precip (L(0/5).ag_deliveries_acre= L(0/5).ag_allocation_acre) [weight=w] if year<2021, abs(wellid year) cluster(DAUCO)
estimates store iv_lag5
estadd local weights "Crop Acres/# wells"
estadd local time "\checkmark"
estadd local individual "\checkmark"

lincom hdd+L.hdd+L2.hdd+L3.hdd+L4.hdd+L5.hdd
estadd scalar cumu1=r(estimate)
estadd scalar se1=r(se)
lincom ag_deliveries_acre+L.ag_deliveries_acre+L2.ag_deliveries_acre+L3.ag_deliveries_acre+L4.ag_deliveries_acre +L5.ag_deliveries_acre

estimates restore iv_lag5
margins, expression (_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre] + _b[L2.ag_deliveries_acre]+ _b[L3.ag_deliveries_acre] + _b[L4.ag_deliveries_acre] + _b[L5.ag_deliveries_acre]) post
estimates store sw5
estadd scalar cumu2=r(estimate)
estadd scalar se2=r(se)

ivreghdfe diff_depth L(0/3).hdd gdd precip (L(0/3).ag_deliveries_acre= L(0/3).ag_allocation_acre) [weight=w] if year<2021, abs(wellid year) cluster(DAUCO)
estimates store iv_lag6
estadd local weights "Crop Acres/# wells"
estadd local time "\checkmark"
estadd local individual "\checkmark"

capture lincom hdd+L.hdd+L2.hdd+L3.hdd+L4.hdd+L5.hdd+L6.hdd
capture estadd scalar cumu1=r(estimate)
capture estadd scalar se1=r(se)
capture lincom ag_deliveries_acre+L.ag_deliveries_acre+L2.ag_deliveries_acre+L3.ag_deliveries_acre+L4.ag_deliveries_acre+L5.ag_deliveries_acre+L6.ag_deliveries_acre



estimates restore iv_lag6
margins, expression(_b[ag_deliveries_acre]) post
estimates store sw0
estimates restore iv_lag6
margins, expression(_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre]) post
estimates store sw1
estimates restore iv_lag6
margins, expression(_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre] + _b[L2.ag_deliveries_acre]) post
estimates store sw2
estimates restore iv_lag6
margins, expression(_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre] + _b[L2.ag_deliveries_acre]+ _b[L3.ag_deliveries_acre]) post
estimates store sw3
capture {
estimates restore iv_lag6
margins, expression(_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre] + _b[L2.ag_deliveries_acre]+ _b[L3.ag_deliveries_acre] + _b[L4.ag_deliveries_acre]) post
estimates store sw4
}
capture {
estimates restore iv_lag6
margins, expression(_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre] + _b[L2.ag_deliveries_acre]+ _b[L3.ag_deliveries_acre] + _b[L4.ag_deliveries_acre] + _b[L5.ag_deliveries_acre]) post
estimates store sw5
}
capture {
estimates restore iv_lag6
margins, expression(_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre] + _b[L2.ag_deliveries_acre]+ _b[L3.ag_deliveries_acre] + _b[L4.ag_deliveries_acre] + _b[L5.ag_deliveries_acre] + _b[L6.ag_deliveries_acre]) post
estimates store sw6
}


estimates restore iv_lag6
margins, expression(_b[hdd]) post
estimates store hdd0
estimates restore iv_lag6
margins, expression(_b[hdd]+_b[L.hdd]) post
estimates store hdd1
estimates restore iv_lag6
margins, expression(_b[hdd]+_b[L.hdd] + _b[L2.hdd]) post
estimates store hdd2
estimates restore iv_lag6
margins, expression(_b[hdd]+_b[L.hdd] + _b[L2.hdd]+ _b[L3.hdd]) post
estimates store hdd3
capture {
estimates restore iv_lag6
margins, expression(_b[hdd]+_b[L.hdd] + _b[L2.hdd]+ _b[L3.hdd] + _b[L4.hdd]) post
estimates store hdd4
}
capture {
estimates restore iv_lag6
margins, expression(_b[hdd]+_b[L.hdd] + _b[L2.hdd]+ _b[L3.hdd] + _b[L4.hdd] + _b[L5.hdd]) post
estimates store hdd5
}
capture {
estimates restore iv_lag6
margins, expression(_b[hdd]+_b[L.hdd] + _b[L2.hdd]+ _b[L3.hdd] + _b[L4.hdd] + _b[L5.hdd] + _b[L6.hdd]) post
estimates store hdd6
}

estadd scalar cumu2=r(estimate)
estadd scalar se2=r(se)

gen precip2 = precip*precip
ivreghdfe diff_depth L(0/3).hdd L(0/3).gdd L(0/3).precip* (L(0/3).ag_deliveries_acre= L(0/3).ag_allocation_acre)  [weight=w] if year<2021, abs(wellid year) cluster(DAUCO)
estimates store iv_lag7
estadd local weights "Crop Acres/# wells"
estadd local time "\checkmark"
estadd local individual "\checkmark"

capture lincom hdd+L.hdd+L2.hdd+L3.hdd+L4.hdd+L5.hdd+L6.hdd+L7.hdd
capture estadd scalar cumu1=r(estimate)
capture estadd scalar se1=r(se)
capture lincom ag_deliveries_acre+L.ag_deliveries_acre+L2.ag_deliveries_acre+L3.ag_deliveries_acre+L4.ag_deliveries_acre+L5.ag_deliveries_acre+L6.ag_deliveries_acre+L7.ag_deliveries_acre
capture estadd scalar cumu2=r(estimate)
capture estadd scalar se2=r(se)


ivreghdfe diff_depth L(0/8).hdd L(0/8).gdd L(0/8).precip (L(0/8).ag_deliveries_acre= L(0/8).ag_allocation_acre) [weight=w] if year<2021, abs(wellid year) cluster(DAUCO)
estimates store iv_lag8
estadd local weights "Crop Acres/# wells"
estadd local time "\checkmark"
estadd local individual "\checkmark"

lincom hdd+L.hdd+L2.hdd+L3.hdd+L4.hdd+L5.hdd+L6.hdd+L7.hdd+L8.hdd
estadd scalar cumu1=r(estimate)
estadd scalar se1=r(se)
lincom ag_deliveries_acre+L.ag_deliveries_acre+L2.ag_deliveries_acre+L3.ag_deliveries_acre+L4.ag_deliveries_acre+L5.ag_deliveries_acre+L6.ag_deliveries_acre+L7.ag_deliveries_acre+L8.ag_deliveries_acre
estadd scalar cumu2=r(estimate)
estadd scalar se2=r(se)

matrix input zero=(0 \ 0 \ 0)



 coefplot ( mat(zero), ci((2  3)) \ sw0 \ sw1 \ sw2 \ sw3 ), aseq noeqlabels swapnames vertical xlab( 1 "0" 2 "1" 3 "2" 4 "3" 5 "4") recast(line) lwidth(1.5) ciopts(recast(rarea) color(*0.2%80 ) ) ytitle("{&Delta}DTW (ft)" "Cumulative Impuse Response" ) ylab(0(-2)-12) yline(0) scheme(s1mono) xtitle("Years since shock")


 graph export "$FIGURES/cumulative_sw_lag4.png", replace

  coefplot (mat(zero), ci((2  3))\ hdd0 \ hdd1 \ hdd2 \ hdd3 ), aseq noeqlabels swapnames vertical xlab(1 "0" 2 "1" 3 "2" 4 "3" 5 "4") recast(line) lwidth(1.5) ciopts(recast(rarea) color(*0.2%80 ) ) mcolor("black") msize(2) ytitle("Harmful Degree Days" "Cumulative Effect" ) yline(0) scheme(s1mono)


 graph export "$FIGURES/cumulative_hdd_lag4.png", replace



esttab iv_lag0 iv_lag1 iv_lag2 iv_lag3 using "$TABLES/gwdepth_lag.tex", keep(ag_deliveries_acre L.ag_deliveries_acre L2.ag_deliveries_acre L3.ag_deliveries_acre hdd L.hdd L2.hdd L3.hdd ) order(ag_deliveries_acre L.ag_deliveries_acre L2.ag_deliveries_acre L3.ag_deliveries_acre hdd L.hdd L2.hdd L3.hdd) label se scalar("N_clust N Cluster"  "cumu1 $\beta_{hdd$}" "p1 $p_{hdd}$" "cumu2 $\sum \beta_{deliveries}" "p2 $p_{deliveries}$" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE" )  replace title("New Agricultural Well Constructed per DAUCO") note("Note: Dependent variable is the change in the depth to the groundwater from the surface (ft) from 1994-2020 at the monitoring well level. All regressions are weighted by the DAUCO crop acres and include year and DAUCO fixed effects. Standard errors are clustered at the DAUCO level and are reported in parentheses.")



***********************************OLD ANALYSIS*********************************
*********************************May keep for Appendix**************************

**** All Balanced Wells *********

preserve

*drop if abs(diff_depth)>50
keep if year>=1994
keep if year<=2021

bysort wellid: gen nyear=[_N]
keep if nyear==28


*collapse (mean) diff_depth l_ag_allocation_acre ag_allocation_acre (first) crop_acres, by(DAUCO year)

*sum diff_depth

*xtset DAUCO year

xtreg diff_depth l_ag_allocation_acre i.year hdd dday8 precip [weight=crop_acres], fe vce(cluster DAUCO)
estadd local weights "Crop Acres"
estadd local balanced "X"
estadd local time "X"
estadd local individual "X"
estadd local years "94-21"
estimates store all_balanced


restore


*****2003-2021******
preserve

*drop if abs(diff_depth)>50
keep if year>=2003
keep if year<=2021

bysort wellid: gen nyear=[_N]
keep if nyear==18


*collapse (mean) diff_depth l_ag_allocation_acre ag_allocation_acre (first) crop_acres, by(DAUCO year)

*sum diff_depth

*xtset DAUCO year

xtreg F.diff_depth l_ag_allocation_acre hdd gdd precip i.year [weight=crop_acres], fe vce(cluster DAUCO)
estadd local weights "Crop Acres"
estadd local balanced "X"
estadd local time "X"
estadd local individual "X"
estadd local years "03-21"
estimates store nw_balanced


restore


*****2003-2021: Drop Extreme Values******

preserve

*keep if year>=2003
*keep if year<=2021

*DAUCO: egen pct90 = pctile(abs(diff_depth)), p(90)
drop if abs(diff_depth)>2*pct90

collapse (mean) diff_depth l_ag_allocation_acre ag_allocation_acre  l_ag_deliv_acre hdd  gdd dday8 precip (first) crop_acres, by(DAUCO year)

sum diff_depth

xtset DAUCO year

xtreg diff_depth l_ag_deliv_acre hdd gdd precip i.year [weight=crop_acres], fe vce(cluster DAUCO)
xtivreg diff_depth hdd gdd precip i.year (l_ag_deliv_acre=l_ag_allocation_acre), fe vce(cluster DAUCO)
estadd local weights "Crop Acres"
estadd local balanced "X"
estadd local time "X"
estadd local individual "X"
estadd local years "03-21"
estimates store nw_balanced_drop


restore


***Aggregated*****

preserve

drop if abs(diff_depth)>50
keep if year>=2003
keep if year<=2021

bysort wellid: gen nyear=[_N]
keep if nyear==18


collapse (mean) diff_depth l_ag_allocation_acre ag_allocation_acre (first) crop_acres, by(DAUCO year)

sum diff_depth

xtset DAUCO year

xtreg diff_depth l_ag_allocation_acre L.l_ag_allocation_acre i.year [weight=crop_acres], fe vce(cluster DAUCO)
estadd local weights "Crop Acres"
estadd local balanced "X"
estadd local time "X"
estadd local individual "X"
estadd local years "03-21"
estimates store nw_balanced_drop_aggr


restore


****Levels****
preserve

drop if abs(diff_depth)>50
keep if year>=2003
keep if year<=2021

bysort wellid: gen nyear=[_N]
keep if nyear==18


collapse (mean) diff_depth l_ag_allocation_acre ag_allocation_acre (first) crop_acres, by(DAUCO year)

*sum diff_depth

xtset DAUCO year

xtreg diff_depth ag_allocation_acre L.ag_allocation_acre i.year [weight=crop_acres], fe vce(cluster DAUCO)
estadd local weights "Crop Acres"
estadd local balanced "X"
estadd local time "X"
estadd local individual "X"
estadd local years "03-21"
estimates store nw_balanced_drop_levels


restore


esttab all* nw* using "$TABLES/wells.tex", keep(l_ag_allocation_acre L.l_ag_allocation_acre ag_allocation_acre L.ag_allocation_acre) order(diff_depth hdd dday8 precip) label se mtitles("All" "All Balanced" "New Balanced" "No Outliers" "Aggregated" "Aggregated Levels") scalar("N_g N Groups" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE" "years Years") replace title("Changes in GW Depth")
