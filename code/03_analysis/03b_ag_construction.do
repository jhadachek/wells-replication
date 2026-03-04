********************************************************************************
// 03b_ag_construction.do
// Purpose: Estimate effect of surface water allocations on agricultural well
//          construction (first stage, OLS, PPML, IV distributed lag).
//          Produces the first stage and main construction tables.
// Source:  dauco_tables_2024.do
//
// Inputs:  $DERIVED/final.dta  (DAUCO-year panel)
//          code/03_analysis/03f_bootstrap.do  (bootstrap utility)
//
// Outputs: $TABLES/fs_weather.tex      (first stage)
//          $TABLES/regs1.tex           (OLS + PPML construction)
//          $TABLES/cf_boot.tex         (2SLS + control function bootstrap)
//          $TABLES/construct_lag.tex   (distributed lag, if present)
//
// Paper element: First Stage table, Main Agricultural Construction table
//
// Authors: [Author names]
// Date:    2026-03-03
********************************************************************************

clear all

// Paths set via code/config.do (run from replication/ directory)

use "$DERIVED/final.dta", clear


drop if DAUCO==.

 xtset DAUCO year

//gen crop_acres=dauco_area*247.105*dauco_pctcrop
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


gen hist_construction=construction
replace hist_construction=50 if hist_construction>50
label var hist_construction "New Ag Wells per DAUCO"


histogram hist_construction, width(1) percent
********************************************************************************
**************1. First Stage: SW Allocation on Ag Deliveries********************
********************************************************************************

*Column 1
reghdfe ag_deliveries_acre ag_allocation_acre [aweight=crop_acres] if year<2021 & hdd!=., abs(year DAUCO) vce(cluster DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store fs1

*Column 2
reghdfe ag_deliveries_acre ag_allocation_acre hdd gdd precip  [aweight=crop_acres] if year<2021, abs(year DAUCO) vce(cluster DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store fs2

reghdfe ag_deliveries_acre hdd gdd precip  [aweight=crop_acres] if year<2021,abs(year DAUCO) vce(cluster DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store fs3

reghdfe ag_allocation_acre hdd gdd precip [aweight=crop_acres] if year<2021,abs(year DAUCO) vce(cluster DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store fs4

esttab fs* using "$TABLES/fs_weather.tex", keep(ag_allocation_acre hdd gdd precip )  order(ag_allocation_acre hdd gdd precip) label se scalar("N_clust N Cluster" "F F Stat" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE")  replace mtitles("Ag SW Deliveries" "Ag SW Deliveries"  "Ag SW Deliveries" "Ag SW Allocations") title("Agricultural SW Deliveries: First Stage Results") note("Note: Dependant variable is Ag SW deliveries per crop acre in levels from 1993-2021. All regressions are weighted by the DAUCO crop acres and include year and DAUCO fixed effects. Standard errors are clustered at the DAUCO level and are reported in parentheses.") nostar

********************************************************************************
**************1. SW Allocation on Ag Well Construction**************************
********************************************************************************

*Column 1
xtreg construction ag_allocation_acre i.year [weight=crop_acres] if year<2021, fe  vce(robust)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store construct_5

*Column 2
xtreg construction ag_allocation_acre hdd gdd precip i.year [weight=crop_acres] if year<2021, fe vce(robust)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store construct_6

*Column 3
ppmlhdfe construction ag_allocation_acre [weight=crop_acres] if year<2021, a(DAUCO year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store construct_7

*Column 4
ppmlhdfe construction ag_allocation_acre hdd gdd precip [weight=crop_acres] if year<2021, a(DAUCO year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store construct_8

esttab construct* using "$TABLES/regs1.tex", keep(ag_allocation_acre hdd gdd precip ) order(ag_allocation_acre hdd gdd precip ) label se scalar("N_clust N Cluster" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE") replace title("New Agricultural Well Constructed per DAUCO")  mgroups("OLS" "PPML", pattern(1 0 1 0)) note("Note: Dependant variable is the count of new agricultural wells per DAUCO from 1993-2020. Columns (1) and (2) report the coefficients for the OLS model. Columns (3) and (4) report coefficients from a psuedo-poisson maximum likelihood model. All regressions are weighted by the DAUCO crop acres and include year and DAUCO fixed effects. Standard errors are clustered at the DAUCO level and are reported in parentheses.")


********************************************************************************
**************1. SW Allocation on Ag Well Construction**************************
********************************************************************************

xi: xtivreg2 construction (ag_deliveries_acre = ag_allocation_acre) i.year [weight=crop_acres] if year<2021, fe cluster(DAUCO)
estimates store iv_construct_lvl
estadd local time "X"
estadd local individual "X"
estadd local weights "Crop Acres"


xi: xtivreg2 construction hdd gdd precip (ag_deliveries_acre = ag_allocation_acre) i.year [weight=crop_acres] if year<2021, fe cluster(DAUCO)
estimates store iv_construct_lvl_cntrl
estadd local time "X"
estadd local individual "X"
estadd local weights "Crop Acres"

*Loads bootstrap functions for control functions
do "code/03_analysis/03f_bootstrap.do"

bootstrap ag_deliveries_acre=r(b_ag_deliv_acre) deliv_hat=r(b_deliv_hat) if year<2021, reps(10) seed(1234) cluster(DAUCO) idcluster(newid):  wells_boot_lvl_weight_noctrl
estimates store boot_lvl_noctrl
estadd local time "X"
estadd local individual "X"
estadd local weights "Crop Acres"


bootstrap ag_deliveries_acre=r(b_ag_deliv_acre) deliv_hat=r(b_deliv_hat) hdd=r(b_hdd) gdd=r(b_gdd) precip=r(b_precip) if year<2021, reps(500) seed(1234) cluster(DAUCO) idcluster(newid): wells_boot_lvl_weight
estimates store boot_lvl_control
estadd local time "X"
estadd local individual "X"
estadd local weights "Crop Acres"

program drop wells_boot wells_boot_lvl wells_boot_weight wells_boot_lvl_weight_noctrl  wells_boot_lvl_weight wells_boot_lvl_lag1 wells_boot_lvl_lag2 wells_boot_lvl_weight_dday29
drop newid

esttab iv* boot* using "$TABLES/cf_boot.tex", replace keep(ag_deliveries_acre hdd gdd precip deliv_hat) order(ag_deliveries_acre hdd gdd precip deliv_hat) label se scalar("N_clust N Groups" "weights Weights" "rkf KP F Stat" "clustvar Cluster" "time Time FE" "individual Unit FE") coeflabels(deliv_hat "$\hat{\mu}$") nomtitles   title("New Agricultural Well Constructed per DAUCO: SW Deliveries")  mgroups("2SLS" "CF/Poisson", pattern(1 0 1 0)) note("Note: Dependant variable is the count of new agricultural wells per DAUCO from 1993-2021. All regressions are weighted by the DAUCO crop acres and include year and DAUCO fixed effects. Standard errors are clustered at the DAUCO level and are reported in parentheses. Columns (3) and (4) standard errors are calculated using 500 bootstrap simulations, clustered at the DAUCO level.")



********************************************************************************
**************Appendix: Domestic Wells, Destructions, Placebo Tests**************************
********************************************************************************
drop d_construction_acre
gen d_construction_acre=d_construction/crop_acre

xtreg d_construction ag_allocation_acre i.year [weight=crop_acres], fe  vce(robust)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store dconstruct_1

xtreg d_construction ag_allocation_acre hdd gdd precip i.year[weight=crop_acres], fe  vce(robust)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store dconstruct_2


ppmlhdfe d_construction ag_allocation_acre  [weight=crop_acres], a(DAUCO year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store dconstruct_3

ppmlhdfe d_construction ag_allocation_acre hdd dday8 precip [weight=crop_acres], a(DAUCO year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store dconstruct_4

esttab dconstruct* using "$TABLES/domestic.tex", keep(ag_allocation_acre hdd gdd precip )  order(ag_allocation_acre hdd gdd precip ) label se scalar("N_clust N Cluster" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE") replace title("New Agricultural Well Constructed per DAUCO") mtitle("OLS" "OLS" "PPML" "PPML")



gen allocation_mi=vol_maximum_mi*pct_allocation_mi
gen l_allocation_mi=log(allocation_mi)
gen mi_allocation_acre=allocation_mi/total_acres

xtreg construction mi_allocation_acre i.year [weight=crop_acres], fe  vce(robust)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store construct_5


xtreg construction mi_allocation_acre hdd gdd precip L.precip i.year [weight=crop_acres], fe vce(robust)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store construct_6

ppmlhdfe construction mi_allocation_acre [weight=crop_acres], a(DAUCO year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store construct_7

ppmlhdfe construction mi_allocation_acre hdd gdd precip L.precip [weight=crop_acres], a(DAUCO year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store construct_8



*Distributed Lags
do "code/03_analysis/03f_bootstrap.do"


bootstrap ag_deliveries_acre=r(b_ag_deliv_acre) ag_deliveries_acre1=r(b_ag_deliv_acre1) deliv_hat=r(b_deliv_hat) deliv_hat1=r(b_deliv_hat1) hdd=r(b_hdd) hdd1=r(b_hdd1) gdd=r(b_gdd) precip=r(b_precip) if year<2021, reps(10) seed(1234) cluster(DAUCO) idcluster(newid):  wells_boot_lvl_lag1
estimates store boot_lvl_lag1
estadd local time "X"
estadd local individual "X"
estadd local weights "Crop Acres"


test hdd+hdd1=0
estadd scalar cum1=_b[hdd]+_b[hdd]
estadd scalar p1=r(p)
test ag_deliveries_acre+ag_deliveries_acre1=0
estadd scalar cum2=_b[ag_deliveries_acre]+_b[ag_deliveries_acre1]
estadd scalar p2=r(p)



bootstrap ag_deliveries_acre=r(b_ag_deliv_acre) ag_deliveries_acre1=r(b_ag_deliv_acre1) ag_deliveries_acre2 = r(b_ag_deliv_acre2) deliv_hat=r(b_deliv_hat) deliv_hat1=r(b_deliv_hat1) deliv_hat2=r(b_deliv_hat2) hdd=r(b_hdd) hdd1=r(b_hdd1) hdd2=r(b_hdd2) gdd=r(b_gdd) precip=r(b_precip) if year<2021, reps(10) seed(1234) cluster(DAUCO) idcluster(newid):  wells_boot_lvl_lag2
estimates store boot_lvl_lag2
estadd local time "X"
estadd local individual "X"
estadd local weights "Crop Acres"


test hdd+hdd1+hdd2=0
estadd scalar cum1=_b[hdd]+_b[hdd1]+_b[hdd2]
estadd scalar p1=r(p)
test ag_deliveries_acre+ag_deliveries_acre1+ag_deliveries_acre2=0
estadd scalar cum2=_b[ag_deliveries_acre]+_b[ag_deliveries_acre1]+_b[ag_deliveries_acre2]
estadd scalar p2=r(p)




xi: xtivreg2 construction L(0/3).hdd gdd precip (L(0/3).ag_deliveries_acre = L(0/3).ag_allocation_acre) i.year [weight=crop_acres] if year<2021, fe cluster(DAUCO)
estimates store iv_lag0
estadd local time "X"
estadd local individual "X"
estadd local weights "Crop Acres"

test _b[L.ag_deliveries_acre] + _b[L2.ag_deliveries_acre]+ _b[L3.ag_deliveries_acre]=0
test L.hdd  L2.hdd L3.hdd

lincom L.hdd+L2.hdd+L3.hdd
lincom L.ag_deliveries_acre+L2.ag_deliveries_acre+L3.ag_deliveries_acre
test L.ag_deliveries_acre L2.ag_deliveries_acre L3.ag_deliveries_acre


estimates restore iv_lag0
margins, expression(_b[ag_deliveries_acre] ) post
estimates store sw

estimates restore iv_lag0
margins, expression(_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre] ) post
estimates store sw1

estimates restore iv_lag0
margins, expression(_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre] + _b[L2.ag_deliveries_acre] ) post
estimates store sw2

estimates restore iv_lag0
margins, expression(_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre] + _b[L2.ag_deliveries_acre]+ _b[L3.ag_deliveries_acre]) post
estimates store sw3

estimates restore iv_lag0
margins, expression(_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre] + _b[L2.ag_deliveries_acre]+ _b[L3.ag_deliveries_acre] + _b[L4.ag_deliveries_acre] ) post
estimates store sw4

estimates restore iv_lag0
margins, expression(_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre] + _b[L2.ag_deliveries_acre]+ _b[L3.ag_deliveries_acre] + _b[L4.ag_deliveries_acre] + _b[L5.ag_deliveries_acre]) post
estimates store sw5

estimates restore iv_lag0


margins, expression(_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre] + _b[L2.ag_deliveries_acre]+ _b[L3.ag_deliveries_acre] + _b[L4.ag_deliveries_acre] + _b[L5.ag_deliveries_acre] + _b[L6.ag_deliveries_acre]) post
estimates store sw6

matrix input zero=(0 \ 0 \ 0)
coefplot ( mat(zero), ci((2  3)) \ sw \ sw1 \ sw2 \ sw3), aseq  yline(0) noeqlabels swapnames vertical xlab( 1 "0" 2 "1" 3 "2" 4 "3" 5 "4") recast(line) lwidth(1.5) ciopts(recast(rarea) color(*0.2%80) ) ytitle("New Wells" "Cumulative Impuse Response" ) ylab(0(-5)-30) scheme(s1mono) xtitle("Years since shock")

 graph export "$FIGURES/cumulative_wells_sw_lag3.png", replace

 estimates restore iv_lag0
 margins, expression(_b[hdd]) post
estimates store hdd0
estimates restore iv_lag0
margins, expression(_b[hdd]+_b[L.hdd]) post
estimates store hdd1
estimates restore iv_lag0
margins, expression(_b[hdd]+_b[L.hdd] + _b[L2.hdd]) post
estimates store hdd2
estimates restore iv_lag0
margins, expression(_b[hdd]+_b[L.hdd] + _b[L2.hdd]+ _b[L3.hdd]) post
estimates store hdd3
estimates restore iv_lag0
margins, expression(_b[hdd]+_b[L.hdd] + _b[L2.hdd]+ _b[L3.hdd] + _b[L4.hdd]) post
estimates store hdd4
estimates restore iv_lag0
margins, expression(_b[hdd]+_b[L.hdd] + _b[L2.hdd]+ _b[L3.hdd] + _b[L4.hdd] + _b[L5.hdd]) post
estimates store hdd5
estimates restore iv_lag0
margins, expression(_b[hdd]+_b[L.hdd] + _b[L2.hdd]+ _b[L3.hdd] + _b[L4.hdd] + _b[L5.hdd] + _b[L6.hdd]) post
estimates store hdd6

coefplot ( mat(zero), ci((2  3)) \ hdd0 \ hdd1 \ hdd2 \ hdd3 ), aseq  yline(0) noeqlabels swapnames vertical xlab( 1 "0" 2 "1" 3 "2" 4 "3" 5 "4") recast(line) lwidth(1.5) ciopts(recast(rarea) color(*0.2%80) ) ytitle("New Wells" "Cumulative Impuse Response" ) ylab(0(0.05)0.4) scheme(s1mono) xtitle("Years since shock")

 graph export "$FIGURES/cumulative_wells_hdd_lag3.png", replace


test hdd=0
estadd scalar cum1=_b[hdd]
estadd scalar p1=r(p)
test ag_deliveries_acre=0
estadd scalar cum2=_b[ag_deliveries_acre]
estadd scalar p2=r(p)



xi: xtivreg2 construction hdd L.hdd gdd precip (ag_deliveries_acre L.ag_deliveries_acre= ag_allocation_acre L.ag_allocation_acre) i.year [weight=crop_acres] if year<2021, fe cluster(DAUCO)
estimates store iv_lag1
estadd local time "X"
estadd local individual "X"
estadd local weights "Crop Acres"

test hdd+L.hdd=0
estadd scalar cum1=_b[hdd]+_b[L.hdd]
estadd scalar p1=r(p)
test ag_deliveries_acre+L.ag_deliveries_acre=0
estadd scalar cum2=_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre]
estadd scalar p2=r(p)

test L.hdd
test L.ag_deliveries_acre

xi: xtivreg2 construction hdd L.hdd L2.hdd gdd precip (ag_deliveries_acre L.ag_deliveries_acre L2.ag_deliveries_acre= ag_allocation_acre L.ag_allocation_acre L2.ag_allocation_acre) i.year [weight=crop_acres] if year<2021, fe cluster(DAUCO)
estimates store iv_lag2
estadd local time "X"
estadd local individual "X"
estadd local weights "Crop Acres"

test hdd+L.hdd+L2.hdd=0
estadd scalar cum1=_b[hdd]+_b[L.hdd]+_b[L2.hdd]
estadd scalar p1=r(p)
test ag_deliveries_acre+L.ag_deliveries_acre+L2.ag_deliveries_acre=0
estadd scalar cum2=_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre]+_b[L2.ag_deliveries_acre]
estadd scalar p2=r(p)

test L.hdd L2.hdd

test L.ag_deliveries_acre L2.ag_deliveries_acre


xi: xtivreg2 construction hdd L.hdd L2.hdd L3.hdd gdd precip (ag_deliveries_acre L.ag_deliveries_acre L2.ag_deliveries_acre L3.ag_deliveries_acre= ag_allocation_acre L.ag_allocation_acre L2.ag_allocation_acre L3.ag_allocation_acre) i.year [weight=crop_acres] if year<2021, fe cluster(DAUCO)
estimates store iv_lag3
estadd local time "X"
estadd local individual "X"
estadd local weights "Crop Acres"

test hdd+L.hdd+L2.hdd+L3.hdd=0
estadd scalar cum1=_b[hdd]+_b[L.hdd]+_b[L2.hdd]+_b[L3.hdd]
estadd scalar p1=r(p)
test ag_deliveries_acre+L.ag_deliveries_acre+L2.ag_deliveries_acre+L3.ag_deliveries_acre=0
estadd scalar cum2=_b[ag_deliveries_acre]+_b[L.ag_deliveries_acre]+_b[L2.ag_deliveries_acre]+_b[L3.ag_deliveries_acre]
estadd scalar p2=r(p)


test L.hdd L2.hdd L3.hdd

test L.ag_deliveries_acre L2.ag_deliveries_acre L3.ag_deliveries_acre

esttab iv_lag0 iv_lag1 iv_lag2 iv_lag3 using "$TABLES/construct_lag.tex", keep(ag_deliveries_acre L.ag_deliveries_acre L2.ag_deliveries_acre L3.ag_deliveries_acre hdd L.hdd L2.hdd L3.hdd ) order(ag_deliveries_acre L.ag_deliveries_acre L2.ag_deliveries_acre L3.ag_deliveries_acre hdd L.hdd L2.hdd L3.hdd) label se scalar("N_clust N Cluster"  "cum1 \sum \beta_hdd" "p1 p-value_hdd" "cum2 \sum \beta_{delieveries}" "p2 p-value_deliveries" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE" )  replace title("New Agricultural Well Constructed per DAUCO") width(75%) note("Note: Dependant variable is the count of new agricultural wells per DAUCO from 1993-2020. All regressions are weighted by the DAUCO crop acres and include year and DAUCO fixed effects. Standard errors are clustered at the DAUCO level and are reported in parentheses.")




ppmlhdfe construction ag_allocation_acre hdd gdd precip [weight=crop_acres] if year<2021, a(DAUCO year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store rf_lag0

test hdd=0
estadd scalar cum1=_b[hdd]
estadd scalar p1=r(p)
test ag_allocation_acre=0
estadd scalar cum2=_b[ag_allocation_acre]
estadd scalar p2=r(p)

ppmlhdfe construction L(0/1)ag_allocation_acre L(0/1)hdd gdd precip [weight=crop_acres] if year<2021, a(DAUCO year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store rf_lag1

test hdd+L.hdd=0
estadd scalar cum1=_b[hdd]+_b[L.hdd]
estadd scalar p1=r(p)
test ag_allocation_acre+L.ag_allocation_acre=0
estadd scalar cum2=_b[ag_allocation_acre]+_b[L.ag_allocation_acre]
estadd scalar p2=r(p)


ppmlhdfe construction L(0/2)ag_allocation_acre L(0/2)hdd gdd precip [weight=crop_acres] if year<2021, a(DAUCO year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store rf_lag2

test hdd+L.hdd+L2.hdd=0
estadd scalar cum1=_b[hdd]+_b[L.hdd]+_b[L2.hdd]
estadd scalar p1=r(p)
test ag_allocation_acre+L.ag_allocation_acre+L2.ag_allocation_acre=0
estadd scalar cum2=_b[ag_allocation_acre]+_b[L.ag_allocation_acre]+_b[L2.ag_allocation_acre]
estadd scalar p2=r(p)

ppmlhdfe construction L(0/3)ag_allocation_acre L(0/3)hdd gdd precip [weight=crop_acres] if year<2021, a(DAUCO year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store rf_lag3

test hdd+L.hdd+L2.hdd+L3.hdd=0
estadd scalar cum1=_b[hdd]+_b[L.hdd]+_b[L2.hdd]+_b[L3.hdd]
estadd scalar p1=r(p)
test ag_allocation_acre+L.ag_allocation_acre+L2.ag_allocation_acre+L3.ag_allocation_acre=0
estadd scalar cum2=_b[ag_allocation_acre]+_b[L.ag_allocation_acre]+_b[L2.ag_allocation_acre]+_b[L3.ag_allocation_acre]
estadd scalar p2=r(p)

esttab rf_lag0 rf_lag1 rf_lag2 rf_lag3 using "$TABLES/construct_lag2.tex", keep(ag_allocation_acre L.ag_allocation_acre L2.ag_allocation_acre L3.ag_allocation_acre hdd L.hdd L2.hdd L3.hdd) order(ag_allocation_acre L.ag_allocation_acre L2.ag_allocation_acre L3.ag_allocation_acre hdd L.hdd L2.hdd L3.hdd) label se scalar("N_clust N Cluster"  "cum1 \sum \beta_hdd" "p1 p-value_hdd" "cum2 \sum \beta_{delieveries}" "p2 p-value_deliveries" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE" )  replace title("New Agricultural Well Constructed per DAUCO") width(75%) note("Note: Dependant variable is the count of new agricultural wells per DAUCO from 1993-2020. All regressions are weighted by the DAUCO crop acres and include year and DAUCO fixed effects. Standard errors are clustered at the DAUCO level and are reported in parentheses.")



********************************************************************************
************** SW Allocation on Ag Well Destructions**************************
********************************************************************************

*Column 1
xtreg destruction ag_allocation_acre L(0/3).ag_allocation_acre i.year [weight=crop_acres] if year<2021, fe  vce(robust)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store destruct_1

*Column 2
xtreg destruction ag_allocation_acre hdd gdd precip i.year [weight=crop_acres] if year<2021, fe vce(robust)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store destruct_2

*Column 3
ppmlhdfe destruction ag_allocation_acre [weight=crop_acres] if year<2021, a(DAUCO year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store destruct_3

*Column 4
ppmlhdfe destruction ag_allocation_acre hdd gdd precip [weight=crop_acres] if year<2021, a(DAUCO year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store destruct_4

esttab destruct* using "$TABLES/destruct_regs.tex", keep(ag_allocation_acre hdd gdd precip ) order(ag_allocation_acre hdd gdd precip ) label se scalar("N_clust N Cluster" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE") replace title("Destroyed Agricultural Well Constructed per DAUCO")  mgroups("OLS" "PPML", pattern(1 0 1 0)) note("Note: Dependent variable is the count of destroyed agricultural wells per DAUCO from 1993-2020. Columns (1) and (2) report the coefficients for the OLS model. Columns (3) and (4) report coefficients from a psuedo-poisson maximum likelihood model. All regressions are weighted by the DAUCO crop acres and include year and DAUCO fixed effects. Standard errors are clustered at the DAUCO level and are reported in parentheses.")

***net construction
gen net_construct=construction - destruction

*Column 1
xtreg net_construct ag_allocation_acre  i.year [weight=crop_acres] if year<2021, fe  vce(robust)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store net1

*Column 2
xtreg net_construct ag_allocation_acre hdd gdd precip i.year [weight=crop_acres] if year<2021, fe vce(robust)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store net2

*Column 3
xi: xtivreg2 net_construct (ag_deliveries_acre = ag_allocation_acre) i.year [weight=crop_acres] if year<2021, fe cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store net3

*Column 4
xi: xtivreg2 net_construct hdd gdd precip i.year (ag_deliveries_acre = ag_allocation_acre)  [weight=crop_acres] if year<2021, fe cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store net4

esttab net* using "$TABLES/net_regs.tex", keep(ag_allocation_acre ag_deliveries_acre hdd gdd precip ) order(ag_allocation_acre hdd gdd precip ) label se scalar("N_clust N Cluster" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE") replace title("Net New Agricultural Well Constructed per DAUCO")  mgroups("OLS" "PPML", pattern(1 0 1 0)) note("Note: Dependent variable is the count of destroyed agricultural wells per DAUCO from 1993-2020. Columns (1) and (2) report the coefficients for the OLS model. Columns (3) and (4) report coefficients from a psuedo-poisson maximum likelihood model. All regressions are weighted by the DAUCO crop acres and include year and DAUCO fixed effects. Standard errors are clustered at the DAUCO level and are reported in parentheses.")

*******************************************************************************
*********************** Construction: DDAY29 **********************************
*******************************************************************************

merge 1:1 year DAUCO using "$DERIVED/all_weather25.dta"




ivreghdfe construct (ag_deliveries_acre=ag_allocation_acre) dday29 gdd precip [aweight=crop_acres] if year<2021,abs(year DAUCO) vce(cluster DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store iv_dday29


bootstrap ag_deliveries_acre=r(b_ag_deliv_acre) deliv_hat=r(b_deliv_hat) dday29=r(b_dday29) gdd=r(b_gdd) precip=r(b_precip) if year<2021, reps(500) seed(1234) cluster(DAUCO) idcluster(newid): wells_boot_lvl_weight_dday29
estimates store boot_lvl_dday29


esttab iv_dday29 boot_lvl_dday29 using "$TABLES/construct_dday29.tex", keep(ag_allocation_acre ag_deliveries_acre dday29 gdd precip ) order(ag_allocation_acre dday29 gdd precip ) label se scalar("N_clust N Cluster" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE") replace title(" New Agricultural Well Constructed per DAUCO")  note("Note: Dependent variable is the count of new agricultural wells per DAUCO from 1993-2020.  All regressions are weighted by the DAUCO crop acres and include year and DAUCO fixed effects. Standard errors are clustered at the DAUCO level and are reported in parentheses.")
