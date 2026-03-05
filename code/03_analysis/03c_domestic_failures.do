********************************************************************************
// 03c_domestic_failures.do
// Purpose: Estimate effect of groundwater depth on domestic well failures
//          (reduced form and IV). Includes heterogeneity by race and income,
//          SJV subsample, distributed lag, and demographic balance table.
// Source:  domestic_table_25.do
//
// Inputs:  $DERIVED/failures_11_23.dta      (domestic well failure panel)
//          $RAW/SB535DACresultsdatadictionary_F_2022.xlsx
//          $RAW/nhgis0006_ds249_20205_tract.csv
//
// Outputs: $TABLES/failures.tex             (main RF + IV)
//          $TABLES/failures_sjv.tex         (SJV subsample)
//          $TABLES/failure_lag.tex          (distributed lag)
//          $TABLES/hdd_nonwhite.tex         (race heterogeneity)
//          $TABLES/hdd_lowincome.tex        (income heterogeneity)
//          $TABLES/demo_table.tex           (demographic balance)
//
// Paper element: Domestic Well Failures tables (main + appendix)
//
// Authors: [Author names]
// Date:    2026-03-03
********************************************************************************
clear all
// Paths set via code/config.do (run from replication/ directory)

use "$DERIVED/failures_11_23.dta", clear
*dist: Distance from well failure coordinates to nearest neighbor well completion report coordinates
*Replaces missing values for domestic wells that never failure_full_3_26
replace dist=999 if dist==.

*Identifies unique domestic well from both well failure coordinates and well completion reports
egen wellid=group(id dist)


gen crop_acres=dauco_area*247.105*dauco_pctcrop
gen total_acres = dauco_area*247.105
gen pct_cropacres=crop_acres/total_acres
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
label var ag_deliv_acre "Ag SW Deliveries (AF/acre)"
label var treat "Well Failure Reported"

label var hdd "Harmful Degree Days"
label var gdd "Growing Degree Days"
label var precip "Precipitation (mm)"


*bysort wellid: egen min_destroy_date=min(DateDestruct)
*replace DateDestruct=min_destroy_date

*Keep only the earliest reported well failure for multiple reports of the same well failure
bysort wellid: egen min_date=min(date)
keep if date==min_date | date==.
bysort wellid year: gen count=_N
tab treat count

*Keep only the first observation of duplicate entries
bysort wellid year: gen count2=_n
keep if count2==1
tab treat count

*Final is a balanced panel of all domestic wells, with unique failure reported.
 xtset wellid year



********************************************************************************
**************1. SW Allocation and Deliveries on Well Failures***********************
********************************************************************************


reghdfe treat ag_allocation_acre [aweight=crop_acres] if year>2014 & year<2021 & pump!=1 & DateDestruct==., a(wellid year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store rf_lvl1

reghdfe treat ag_allocation_acre hdd gdd precip if year>2014 & year<2021 & pump!=1 & DateDestruct==. [aweight=crop_acres], a(wellid year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store rf_lvl3


ivreghdfe treat (ag_deliv_acre=ag_allocation_acre)  if year<2021 & year>2014 & pump!=1 & DateDestruct==. [aweight=crop_acres], a(wellid year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store iv_lvl1



ivreghdfe treat (ag_deliv_acre=ag_allocation_acre) hdd gdd precip i.year if year<2021 & year>2014 & pump!=1 & DateDestruct==. [weight=crop_acres], abs(wellid year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store iv_lvl3

gen beta_sw=_b[ag_deliv_acre]
gen beta_hdd=_b[hdd]

esttab rf* iv* using "$TABLES/failures.tex", keep(ag_allocation_acre  ag_deliv_acre  hdd gdd precip ) order(ag_allocation_acre  ag_deliv_acre  hdd gdd precip ) label se mgroups("Reduced Form" "IV", pattern(1 0 0 1 0 0)) scalar("N_full Observations" "df_a_nested N Groups" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE")  replace title("Probability of Domestic Well Failure") nomtitles

********************************************************************************
**************2. SW Allocation and Deliveries on Well Failures: SJV***********************
********************************************************************************

gen sjv = inlist(county_name, "Stanislaus", "Fresno", "Kern", "Kings", "Madera", "Mariposa", "Merced", "Tulare", "San Joaquin", "Los Angeles")
egen sjv_year=group(sjv year)

ivreghdfe treat (ag_deliv_acre=ag_allocation_acre) hdd gdd precip if year<2021 & year>2014 & pump!=1 & DateDestruct==. & sjv==1 [weight=crop_acres], a(wellid sjv_year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store iv_lvl5

esttab rf* iv_lvl1 iv_lvl3 iv_lvl5 using "$TABLES/failures_sjv.tex", keep(ag_allocation_acre  ag_deliv_acre  hdd gdd) order(ag_allocation_acre  ag_deliv_acre hdd gdd) label se mgroups("Reduced Form" "IV", pattern(1 0 0 1 0 0 0)) scalar("N_full Observations" "df_a_nested N Groups" "rkf KP F" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE")  replace title("Probability of Domestic Well Failure") nomtitles b(3) nostar


*******Distributed Lags*******
rename ag_deliv_acre ag_deliveries_acre

xi: xtivreg2 treat hdd gdd precip (ag_deliveries_acre = ag_allocation_acre) i.year [weight=crop_acres] if year<2021 & year>2014, fe cluster(DAUCO)
estimates store iv_lag0
estadd local time "X"
estadd local individual "X"
estadd local weights "Crop Acres"

test hdd=0
estadd scalar cum1=_b[hdd]
estadd scalar p1=r(p)
test ag_deliveries_acre=0
estadd scalar cum2=_b[ag_deliveries_acre]
estadd scalar p2=r(p)



xi: xtivreg2 treat hdd L.hdd gdd precip (ag_deliveries_acre L.ag_deliveries_acre= ag_allocation_acre L.ag_allocation_acre) i.year [weight=crop_acres] if year<2021& year>2014, fe cluster(DAUCO)
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


xi: xtivreg2 treat hdd L.hdd L2.hdd gdd precip (ag_deliveries_acre L.ag_deliveries_acre L2.ag_deliveries_acre= ag_allocation_acre L.ag_allocation_acre L2.ag_allocation_acre) i.year [weight=crop_acres] if year<2021 & year>2014, fe cluster(DAUCO)
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



xi: xtivreg2 treat hdd L.hdd L2.hdd L3.hdd gdd precip (ag_deliveries_acre L.ag_deliveries_acre L2.ag_deliveries_acre L3.ag_deliveries_acre= ag_allocation_acre L.ag_allocation_acre L2.ag_allocation_acre L3.ag_allocation_acre) i.year [weight=crop_acres] if year<2021 & year>2014, fe cluster(DAUCO)
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


esttab iv_lag0 iv_lag1 iv_lag2 iv_lag3 using "$TABLES/failure_lag.tex", keep(ag_deliveries_acre L.ag_deliveries_acre L2.ag_deliveries_acre L3.ag_deliveries_acre hdd L.hdd L2.hdd L3.hdd ) order(ag_deliveries_acre L.ag_deliveries_acre L2.ag_deliveries_acre L3.ag_deliveries_acre hdd L.hdd L2.hdd L3.hdd) label se scalar("N_clust N Cluster"  "cum1 $\sum \beta_{hdd}$" "p1 $p_{hdd}$" "cum2 $\sum \beta_{deliveries}$" "p2 $p_{deliveries}$" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE" )  replace title("New Agricultural Well Constructed per DAUCO") note("Note: Dependant variable is the count of new agricultural wells per DAUCO from 1993-2020. Columns (1) and (2) report the coefficients for the OLS model. Columns (3) and (4) report coefficients from a psuedo-poisson maximum likelihood model. All regressions are weighted by the DAUCO crop acres and include year and DAUCO fixed effects. Standard errors are clustered at the DAUCO level and are reported in parentheses.")

gen pctnonwhite=100-pct_white

egen median_nonwhite=median(pctnonwhite)
xtile qtile_nonwhite=pctnonwhite, nquantiles(4)
egen median_cropacres=median(crop_acres)
egen median_lowincome=median(pct_pov)
xtile qtile_lowincome=pct_pov, nquantiles(4)
egen median_population=median(POP2010)
egen median_density = median(density)

gen nonwhite=0
replace nonwhite=1 if pctnonwhite>median_nonwhite


gen crop=0
replace crop=1 if crop_acres>median_cropacres

gen lowincome2=0
replace lowincome2=1 if pct_pov>median_lowincome

gen pop=0
replace pop=1 if POP2010>median_population



gen treat_lowincome=treat*lowincome2
gen treat_highincome=treat*(1-lowincome2)

gen treat_nonwhite=treat*nonwhite
gen treat_white=treat*(1-nonwhite)

gen treat1=0
replace treat1=treat if qtile_nonwhite==1

gen treat2=0
replace treat2=treat if qtile_nonwhite==2

gen treat3=0
replace treat3=treat if qtile_nonwhite==3

gen treat4=0
replace treat4=treat if qtile_nonwhite==4

gen treat_l1=0
replace treat_l1=treat if qtile_lowincome==1

gen treat_l2=0
replace treat_l2=treat if qtile_lowincome==2

gen treat_l3=0
replace treat_l3=treat if qtile_lowincome==3

gen treat_l4=0
replace treat_l4=treat if qtile_lowincome==4

ivreghdfe treat1 (ag_deliv_acre=ag_allocation_acre) hdd gdd precip if year<2021 & year>2014 & pump!=1 & DateDestruct==. [weight=crop_acres], a(wellid year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store iv_1

gen beta_sw_nonwhite=.
gen beta_hdd_nonwhite=.
replace beta_sw_nonwhite=_b[ag_deliv_acre] if qtile_nonwhite==1
replace beta_hdd_nonwhite=_b[hdd] if qtile_nonwhite==1


ivreghdfe treat2 (ag_deliv_acre=ag_allocation_acre) hdd gdd precip if year<2021 & year>2014 & pump!=1 & DateDestruct==. [weight=crop_acres], a(year wellid) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store iv_2

replace beta_sw_nonwhite=_b[ag_deliv_acre] if qtile_nonwhite==2
replace beta_hdd_nonwhite=_b[hdd] if qtile_nonwhite==2

ivreghdfe treat3 (ag_deliv_acre=ag_allocation_acre) hdd gdd precip  if year<2021 & year>2014 & pump!=1 & DateDestruct==. [weight=crop_acres], a(year wellid) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store iv_3

replace beta_sw_nonwhite=_b[ag_deliv_acre] if qtile_nonwhite==3
replace beta_hdd_nonwhite=_b[hdd] if qtile_nonwhite==3

ivreghdfe treat4 (ag_deliv_acre=ag_allocation_acre) hdd gdd precip if year<2021 & year>2014 & pump!=1 & DateDestruct==. [weight=crop_acres], a(wellid year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store iv_4
replace beta_sw_nonwhite=_b[ag_deliv_acre] if qtile_nonwhite==4
replace beta_hdd_nonwhite=_b[hdd] if qtile_nonwhite==4

ivreghdfe treat (c.ag_deliv_acre#qtile_nonwhite=c.ag_allocation_acre#qtile_nonwhite) c.hdd#qtile_nonwhite gdd c.precip if year<2021 & year>2014 & pump!=1 & DateDestruct==. [w=crop_acres],a(wellid year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store iv_6

gen cond_effect_sw_nonwhite=.
replace cond_effect_sw_nonwhite=_b[1b.qtile_nonwhite#ag_deliv_acre] if qtile_nonwhite==1
replace cond_effect_sw_nonwhite=_b[2.qtile_nonwhite#ag_deliv_acre] if qtile_nonwhite==2
replace cond_effect_sw_nonwhite=_b[3.qtile_nonwhite#ag_deliv_acre] if qtile_nonwhite==3
replace cond_effect_sw_nonwhite=_b[4.qtile_nonwhite#ag_deliv_acre] if qtile_nonwhite==4

gen cond_effect_hdd_nonwhite=.
replace cond_effect_hdd_nonwhite=_b[1b.qtile_nonwhite#hdd] if qtile_nonwhite==1
replace cond_effect_hdd_nonwhite=_b[2.qtile_nonwhite#hdd] if qtile_nonwhite==2
replace cond_effect_hdd_nonwhite=_b[3.qtile_nonwhite#hdd] if qtile_nonwhite==3
replace cond_effect_hdd_nonwhite=_b[4.qtile_nonwhite#hdd] if qtile_nonwhite==4

coefplot (iv_6,  msize(2) color("black")), keep(*ag_deliv_acre) baselevels coeflabels(iv_5="1" iv_5="2" iv_5="3" iv_5="4") vertical yline(0) legend(off) ciopts(lcolor("black") lwidth(thick)) ylabel(,labsize(6)) xlabel("1" "1" "2" "2" "3" "3" "4" "4",labsize(6))  xtitle( "% Non-White Quartile", size(6)) ytitle("Conditional Effects", size(6)) swapnames noeqlabel

graph export "$FIGURES/sw_nonwhite_heterogeneity.png", replace

coefplot (iv_6,  msize(2) color("black")), keep(*hdd) baselevels coeflabels(iv_5="1" iv_5="2" iv_5="3" iv_5="4") vertical yline(0) legend(off) ciopts(lcolor("black") lwidth(thick)) ylabel(,labsize(6)) xlabel("1" "1" "2" "2" "3" "3" "4" "4",labsize(6))  xtitle( "% Non-White Quartile", size(6)) ytitle("Conditional ATE", size(6)) swapnames noeqlabels

graph export "$FIGURES/hdd_nonwhite_heterogeneity.png", replace


coefplot (iv_1 \ iv_2 \ iv_3 \ iv_4,  msize(2) color("black")), aseq keep(hdd) vertical coeflabels(iv_1 ="1" iv_2="2" iv_3="3"  iv_4="4") yline(0)  legend(off) ciopts(lcolor("black") lwidth(thick)) ylabel(,labsize(6)) xlabel(,labsize(6))  xtitle( "% Non-White Quartile", size(6)) ytitle("ATE Decomposition", size(6)) swapnames


graph export "$FIGURES/hdd_nonwhite.png", replace


coefplot (iv_1 \ iv_2 \ iv_3 \ iv_4,  msize(2) color("black")), aseq keep(ag_deliv_acre) vertical coeflabels(iv_1 ="1" iv_2="2" iv_3="3"  iv_4="4") yline(0)  legend(off) ciopts(lcolor("black") lwidth(thick)) ylabel(,labsize(6)) xlabel(,labsize(6))  xtitle( "% Non-White Quartile", size(6)) ytitle("ATE Decomposition", size(6)) swapnames

graph export "$FIGURES/sw_nonwhite.png", replace


ivreghdfe treat_l1 (ag_deliv_acre=ag_allocation_acre) hdd gdd precip  if year<2021 & year>2014 & pump!=1 & DateDestruct==. [weight=crop_acres], a(wellid year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store iv_l1

gen beta_sw_lowincome=.
gen beta_hdd_lowincome=.
replace beta_sw_lowincome=_b[ag_deliv_acre] if qtile_lowincome==1
replace beta_hdd_lowincome=_b[hdd] if qtile_lowincome==1



ivreghdfe treat_l2 (ag_deliv_acre=ag_allocation_acre) hdd gdd precip if year<2021 & year>2014 & pump!=1 & DateDestruct==. [weight=crop_acres], a(wellid year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store iv_l2

replace beta_sw_lowincome=_b[ag_deliv_acre] if qtile_lowincome==2
replace beta_hdd_lowincome=_b[hdd] if qtile_lowincome==2


ivreghdfe treat_l3 (ag_deliv_acre=ag_allocation_acre) hdd gdd precip  if year<2021 & year>2014 & pump!=1 & DateDestruct==. [weight=crop_acres], a(wellid year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store iv_l3

replace beta_sw_lowincome=_b[ag_deliv_acre] if qtile_lowincome==3
replace beta_hdd_lowincome=_b[hdd] if qtile_lowincome==3


ivreghdfe treat_l4 (ag_deliv_acre=ag_allocation_acre) hdd gdd precip  if year<2021 & year>2014 & pump!=1 & DateDestruct==. [weight=crop_acres], a(wellid year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store iv_l4
replace beta_sw_lowincome=_b[ag_deliv_acre] if qtile_lowincome==4
replace beta_hdd_lowincome=_b[hdd] if qtile_lowincome==4


ivreghdfe treat (c.ag_deliv_acre#qtile_lowincome=c.ag_allocation_acre#qtile_lowincome) c.hdd#qtile_lowincome gdd c.precip if year<2021 & year>2014 & pump!=1 & DateDestruct==. [w=crop_acres],a(wellid year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store iv_5

gen cond_effect_sw_lowincome=.
replace cond_effect_sw_lowincome=_b[1b.qtile_lowincome#ag_deliv_acre] if qtile_lowincome==1
replace cond_effect_sw_lowincome=_b[2.qtile_lowincome#ag_deliv_acre] if qtile_lowincome==2
replace cond_effect_sw_lowincome=_b[3.qtile_lowincome#ag_deliv_acre] if qtile_lowincome==3
replace cond_effect_sw_lowincome=_b[4.qtile_lowincome#ag_deliv_acre] if qtile_lowincome==4

gen cond_effect_hdd_lowincome=.
replace cond_effect_hdd_lowincome=_b[1b.qtile_lowincome#hdd] if qtile_lowincome==1
replace cond_effect_hdd_lowincome=_b[2.qtile_lowincome#hdd] if qtile_lowincome==2
replace cond_effect_hdd_lowincome=_b[3.qtile_lowincome#hdd] if qtile_lowincome==3
replace cond_effect_hdd_lowincome=_b[4.qtile_lowincome#hdd] if qtile_lowincome==4


coefplot (iv_5,  msize(2) color("black")), keep(*ag_deliv_acre) baselevels coeflabels(iv_5="1" iv_5="2" iv_5="3" iv_5="4") vertical yline(0) legend(off) ciopts(lcolor("black") lwidth(thick)) ylabel(,labsize(6)) xlabel("1" "1" "2" "2" "3" "3" "4" "4",labsize(6))  xtitle( "% Low Income Quartile", size(6)) ytitle("Conditional ATE", size(6)) swapnames noeqlabels

graph export "$FIGURES/sw_lowincome_heterogeneity.png", replace

coefplot (iv_5,  msize(2) color("black")), keep(*hdd) baselevels coeflabels(iv_5="1" iv_5="2" iv_5="3" iv_5="4") vertical yline(0) legend(off) ciopts(lcolor("black") lwidth(thick)) ylabel(,labsize(6)) xlabel("1" "1" "2" "2" "3" "3" "4" "4",labsize(6))  xtitle( "% Low Income Quartile", size(6)) ytitle("Conditional ATE", size(6)) swapnames noeqlabels

graph export "$FIGURES/hdd_lowincome_heterogeneity.png", replace



coefplot (iv_l1 \ iv_l2 \ iv_l3 \ iv_l4,  msize(2) color("black")), aseq keep(hdd) vertical coeflabels(iv_l1 ="1" iv_l2="2" iv_l3="3"  iv_l4="4") yline(0)  legend(off) ciopts(lcolor("black") lwidth(thick)) ylabel(,labsize(6)) xlabel(,labsize(6))  xtitle( "% Low Income Quartile", size(6)) ytitle("ATE Decomposition", size(6)) swapnames

graph export "$FIGURES/hdd_lowi.png", replace



coefplot (iv_l1 \ iv_l2 \ iv_l3 \ iv_l4,  msize(2) color("black")), aseq keep(ag_deliv_acre) vertical coeflabels(iv_l1 ="1" iv_l2="2" iv_l3="3"  iv_l4="4") yline(0)  legend(off) ciopts(lcolor("black") lwidth(thick)) ylabel(,labsize(6)) xlabel(,labsize(6))  xtitle( "% Low Income Quartile", size(6)) ytitle("ATE Decomposition", size(6)) swapnames

graph export "$FIGURES/sw_lowi.png", replace


capture noisily esttab iv_lvl3 iv_low iv_high iv_nonwhite iv_white using "$TABLES/failures_demo2.tex", keep(ag_deliv_acre  hdd ) order(ag_deliv_acre  hdd gdd precip ) label se mgroups("Pooled" "Income" "Race", pattern(1 0 1 0)) mtitles("" "Low" "High" "Nonwhite" "White") scalar("N_g N Groups" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE")  replace title("Probability of Domestic Well Failure")


gen treat_SB5351=0
replace treat_SB5351=treat if SB535==1

gen treat_SB5350=0
replace treat_SB5350=treat if SB535==0

xi: xtivreg2 treat_SB5351 (ag_deliv_acre=ag_allocation_acre) hdd gdd precip i.year if year<2021 & year>2014 & pump!=1 & DateDestruct==. [weight=crop_acres], fe cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store SB5351


xi: xtivreg2 treat_SB5350 (ag_deliv_acre=ag_allocation_acre) hdd gdd precip i.year if year<2021 & year>2014 & pump!=1 & DateDestruct==. [weight=crop_acres], fe cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store SB5350

ivreghdfe treat (c.ag_deliv_acre#SB535=c.ag_allocation_acre#SB535) c.hdd#SB535 gdd precip if year<2021 & year>2014 & pump!=1 & DateDestruct==. [weight=crop_acres], a(wellid year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store SB535_het

coefplot (SB535_het,  msize(2) color("black")), keep(*ag_deliv_acre) baselevels coeflabels(iv_5="0" iv_5="1") vertical yline(0) legend(off) ciopts(lcolor("black") lwidth(thick)) ylabel(,labsize(6)) xlabel("1" "0" "2" "1",labsize(6))  xtitle( "SB535 Tract", size(6)) ytitle("Conditional ATE", size(6)) swapnames noeqlabels

graph export "$FIGURES/sw_SB535_heterogeneity.png", replace

coefplot (SB535_het,  msize(2) color("black")), keep(*hdd) baselevels coeflabels(iv_5="0" iv_5="1") vertical yline(0) legend(off) ciopts(lcolor("black") lwidth(thick)) ylabel(,labsize(6)) xlabel("1" "0" "2" "1",labsize(6))  xtitle( "SB535 Tract", size(6)) ytitle("Conditional ATE", size(6)) swapnames noeqlabels

graph export "$FIGURES/hdd_SB535_heterogeneity.png", replace


coefplot (SB5350 \ SB5351,  msize(2) color("black")), aseq keep(ag_deliv_acre) vertical coeflabels(SB5350 ="0" SB5351="1") yline(0)  legend(off) ciopts(lcolor("black") lwidth(thick)) ylabel(,labsize(6)) xlabel(,labsize(6))  xtitle( "SB 535 Census Tracts", size(6)) ytitle("ATE Decomposition", size(6)) swapnames

graph export "$FIGURES/sw_SB535.png", replace


coefplot (SB5350 \ SB5351,  msize(2) color("black")), aseq keep(hdd) vertical coeflabels(SB5350 ="0" SB5351="1") yline(0)  legend(off) ciopts(lcolor("black") lwidth(thick)) ylabel(,labsize(6)) xlabel(,labsize(6))  xtitle( "SB 535 Census Tracts", size(6)) ytitle("ATE Decomposition", size(6)) swapnames

graph export "$FIGURES/hdd_SB535.png", replace

********************************************************************************
xtile depth_qtile=TotalCompletedDepth3, nquantiles(4)

ivreghdfe treat (c.ag_deliv_acre#depth_qtile=c.ag_allocation_acre#depth_qtile) c.hdd#depth_qtile gdd precip if year<2021 & year>2014 & pump!=1 & DateDestruct==. [weight=crop_acres], a(wellid year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store depth_het

coefplot (depth_het,  msize(2) color("black")), keep(*hdd) baselevels coeflabels(iv_5="0" iv_5="1") vertical yline(0) legend(off) ciopts(lcolor("black") lwidth(thick)) ylabel(,labsize(6)) xlabel("1" "1" "2" "2" "3" "3" "4" "4",labsize(6))  xtitle( "Well Depth Quartile", size(6)) ytitle("Conditional ATE", size(6)) swapnames noeqlabels

graph export "$FIGURES/hdd_depth_het.png", replace


coefplot (depth_het,  msize(2) color("black")), keep(*ag_deliv_acre) baselevels coeflabels(iv_5="0" iv_5="1") vertical yline(0) legend(off) ciopts(lcolor("black") lwidth(thick)) ylabel(,labsize(6)) xlabel("1" "1" "2" "2" "3" "3" "4" "4",labsize(6))  xtitle( "Well Depth Quartile", size(6)) ytitle("Conditional ATE", size(6)) swapnames noeqlabels

graph export "$FIGURES/sw_depth_het.png", replace



// NOTE: dday29 block requires licensed Schlenker extreme-heat data (not in replication package).
// Wrapped in capture noisily so 03c runs cleanly without the external dataset.
capture noisily {

merge m:1 year DAUCO using "$DERIVED/all_weather25.dta"

ivreghdfe treat (ag_deliv_acre=ag_allocation_acre) dday29 gdd precip i.year if year<2021 & year>2014 & pump!=1 & DateDestruct==. [weight=crop_acres], abs(wellid year) cluster(DAUCO)
estadd local weights "Crop Acres"
estadd local time "X"
estadd local individual "X"
estimates store iv_dday29

esttab iv_dday29 using "$TABLES/failures_dday29.tex", keep(ag_allocation_acre  ag_deliv_acre  dday29 gdd precip ) order(ag_allocation_acre  ag_deliv_acre  dday29 gdd precip ) label se  scalar("N_g N Groups" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE")  replace title("Probability of Domestic Well Failure") nomtitles

} // end capture: dday29 requires licensed Schlenker data




*******************************************************************************
*keep wellid DAUCO qtile* crop_acres iqr*

//Gen mean crop acres for weights
egen mean_crop_acres=mean(crop_acres)


//Calculate IQR Shock for each well
bysort wellid: egen iqr_allocation_ag=iqr(ag_allocation_acre)
bysort wellid: egen iqr_hdd=iqr(hdd)




//Generate predicted well failure probabiliyt based on place-specific shock and treatment effect

//Statewide failures from SW shock
preserve
keep if year==2021
gen domestic_count=1
drop if qtile_lowincome==.
collapse (sum) domestic_count (mean) crop_acres iqr_allocation_ag beta_sw mean_crop_acres
gen iqr_allocation_ag_round=-round(iqr_allocation_ag, 0.01)
gen crop_acres_round=round(crop_acres)
gen beta_sw_round=round(beta_sw, 0.001)
gen fail_2021_sw=iqr_allocation_ag_round*beta_sw_round*domestic_count
gen failures_round=round(fail_2021_sw)

gen total=1
sum fail_2021_sw
listtex  total domestic_count beta_sw_round crop_acres_round iqr_allocation_ag_round   using "$TABLES/sw_total.tex", replace
restore

//Statewide failures from HDD shock
preserve
keep if year==2021
gen domestic_count=1
drop if qtile_lowincome==.
collapse (sum) domestic_count (mean) crop_acres iqr_hdd beta_hdd mean_crop_acres
gen iqr_hdd_round=round(iqr_hdd, 0.01)
gen crop_acres_round=round(crop_acres)
gen beta_hdd_round=round(beta_hdd, 0.0001)
gen fail_2021_hdd=iqr_hdd_round*beta_hdd_round*crop_acres/mean_crop_acres*domestic_count
gen failures_round=round(fail_2021_hdd)
gen total=1
listtex  total domestic_count beta_hdd_round crop_acres_round iqr_hdd_round  using "$TABLES/hdd_total.tex", replace
restore


//SW shock by Low Income Quartile
preserve
keep if year==2021
gen domestic_count=1
drop if qtile_lowincome==.
collapse (sum) domestic_count  (mean) beta_sw crop_acres iqr_allocation_ag mean_crop_acres cond_effect_sw_lowincome beta_sw_lowincome, by(qtile_lowincome)
gen iqr_allocation_ag_round=-round(iqr_allocation_ag, 0.01)
gen crop_acres_round=round(crop_acres)
gen beta_sw_round=round(cond_effect_sw_lowincome, 0.001)
gen beta_sw_decomp=round(beta_sw_lowincome, 0.001)
gen beta_sw_pct=round(beta_sw_lowincome/beta_sw*100)
gen fail_2021_sw=iqr_allocation_ag_round*beta_sw_round*domestic_count*crop_acres/mean_crop_acres
gen failures_round=round(fail_2021_sw)
listtex qtile_lowincome domestic_count  beta_sw_round crop_acres_round iqr_allocation_ag_round  beta_sw_decomp beta_sw_pct  using "$TABLES/sw_lowincome.tex", replace
twoway bar fail_2021_sw qtile_lowincome, ytitle("Predicted Well Failures") xtitle("% Low Income Quartile")
restore

//HDD shock by Low Income Quartile
preserve
keep if year==2021
gen domestic_count=1
drop if qtile_lowincome==.
collapse (sum) domestic_count (mean) beta_hdd crop_acres iqr_hdd mean_crop_acres cond_effect_hdd_lowincome beta_hdd_lowincome, by(qtile_lowincome)
gen iqr_hdd_round=round(iqr_hdd, 0.01)
gen beta_hdd_round=round(cond_effect_hdd_lowincome, 0.0001)
gen beta_hdd_decomp=round(beta_hdd_lowincome, 0.0001)
gen beta_hdd_pct=round(beta_hdd_lowincome/beta_hdd*100)
gen crop_acres_round=round(crop_acres)
gen fail_2021_hdd=iqr_hdd_round*beta_hdd_round*domestic_count*crop_acres/mean_crop_acres
gen failures_round=round(fail_2021_hdd)
listtex  qtile_lowincome domestic_count beta_hdd_round crop_acres_round iqr_hdd_round beta_hdd_decomp beta_hdd_pct  using "$TABLES/hdd_lowincome.tex", replace
twoway bar fail_2021_hdd qtile_lowincome, ytitle("Well Failures") xtitle("% Low Income Quartile")
restore

//SW shock by Nonwhite Quartile
preserve
keep if year==2021
gen domestic_count=1
drop if qtile_lowincome==.
collapse (sum) domestic_count (mean) beta_sw crop_acres iqr_allocation_ag cond_effect_sw_nonwhite mean_crop_acres beta_sw_nonwhite, by(qtile_nonwhite)
bysort qtile_nonwhite: sum crop_acres mean_crop_acres
gen iqr_allocation_ag_round=-round(iqr_allocation_ag, 0.01)
gen crop_acres_round=round(crop_acres)
gen beta_sw_round=round(cond_effect_sw_nonwhite, 0.001)
gen beta_sw_decomp=round(beta_sw_nonwhite, 0.001)
gen beta_sw_pct=round(beta_sw_nonwhite/beta_sw*100)
gen fail_2021_sw=iqr_allocation_ag_round*beta_sw_round*domestic_count*crop_acres/mean_crop_acres
gen failures_round=round(fail_2021_sw)
listtex qtile_nonwhite domestic_count beta_sw_round crop_acres_round iqr_allocation_ag_round beta_sw_decomp  beta_sw_pct  using "$TABLES/sw_nonwhite.tex", replace
twoway bar fail_2021_sw qtile_nonwhite, ytitle("Well Failures") xtitle("% Non White Quartile")
restore

//HDD shock by Nonwhite Quartile
preserve
keep if year==2021
gen domestic_count=1
drop if qtile_nonwhite==.
collapse (sum) domestic_count (mean) beta_hdd crop_acres iqr_hdd cond_effect_hdd_nonwhite mean_crop_acres beta_hdd_nonwhite, by(qtile_nonwhite)

gen iqr_hdd_round=round(iqr_hdd, 0.01)
gen crop_acres_round=round(crop_acres)
gen beta_hdd_round=round(cond_effect_hdd_nonwhite, 0.0001)
gen beta_hdd_pct=round(beta_hdd_nonwhite/beta_hdd*100)
gen beta_hdd_decomp=round(beta_hdd_nonwhite, 0.0001)
gen fail_2021_hdd=iqr_hdd_round*beta_hdd_round*domestic_count*crop_acres/mean_crop_acres
gen failures_round=round(fail_2021_hdd)
listtex  qtile_nonwhite domestic_count beta_hdd_round crop_acres_round iqr_hdd_round beta_hdd_decomp beta_hdd_pct using "$TABLES/hdd_nonwhite.tex", replace
twoway bar fail_2021_hdd qtile_nonwhite, ytitle("Well Failures") xtitle("% Non White Quartile")
restore

*************************************************************************************
***********************DAUCO level regs**********************************************

preserve
collapse (sum) treat count2 (mean) pct_cropacres crop_acres ag_allocation_acre ag_deliv_acre hdd gdd precip, by(DAUCO dau_code psa_code county_code year)
gen weights=count2*crop_acres
gen fr=treat/count2
sum fr treat


ivreghdfe treat ag_allocation_acre [pw=weights] if year>2014 & year<2021, a(DAUCO year) cluster(DAUCO)
est store rf_fr1

ivreghdfe treat ag_allocation_acre hdd gdd precip [aw=weights] if year>2014 & year<2021, a(DAUCO year) cluster(DAUCO)
est store rf_fr2

ivreghdfe treat (ag_deliv_acre=ag_allocation_acre) [pw=weights] if year>2014 & year<2021, a(DAUCO year) cluster(DAUCO)
est store iv_fr1

ivreghdfe treat (ag_deliv_acre=ag_allocation_acre) hdd gdd precip [aw=weights] if year>2014 & year<2021, a(DAUCO year) cluster(DAUCO)
est store iv_fr2




esttab rf_fr* iv_fr* using "$TABLES/failures_dauco.tex", keep(ag_allocation_acre  ag_deliv_acre  hdd gdd) order(ag_allocation_acre  ag_deliv_acre hdd gdd) label se mgroups("Reduced Form" "IV/2SLS", pattern(1 0 0 1 0 0 0)) scalar("N_full Observations" "num_singletons N Excluded" "df_a_nested N Groups" "rkf KP F" "weights Weights" "clustvar Cluster" "time Time FE" "individual Unit FE")  replace title("Probability of Domestic Well Failure") nomtitles b(3) nostar

//esttab ppml_dau* ppml_co ppml_psa ppml_no using "$TABLES/failures_dauco_fe.tex", keep(ag_allocation_acre  hdd gdd) order(ag_allocation_acre  hdd gdd) label se scalar("N_full Full Observations" "num_singletons N Excluded" "individual Unit FE")  replace title("Probability of Domestic Well Failure") nomtitles b(3) nostar

 restore
