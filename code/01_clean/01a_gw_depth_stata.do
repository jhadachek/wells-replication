********************************************************************************
// 01a_gw_depth_stata.do
// Purpose: Clean raw groundwater depth (DTW) observations.
//          Merges GAMA and CNRA periodic level measurements; keeps one
//          observation per well × year (closest to March 15, Jan–May window).
// Source:  prepare_dtw1.do
//
// Inputs:  $RAW_GAMA/gama_all_dtw_elev.txt
//          $RAW_CNRA/periodic_levels/measurements.csv
//          $RAW_CNRA/periodic_levels/stations.csv
//
// Outputs: $DERIVED/gwdepth_raw_obs.dta
//            wellid, latitude, longitude, dtw, year (1981+)
//
// Authors: [Author names]
// Date:    2026-03-03
********************************************************************************

// Globals defined by code/config.do (sourced by 00_run_all.do):
// $RAW_GAMA = data/raw/swrcb_groundwater
// $RAW_CNRA = data/raw/cnra
// $DERIVED = data/derived

// Paths set via code/config.do

clear all
pause on
set more off

********************************************************************************
// Merge GAMA + CNRA periodic depth measurements
********************************************************************************

*----------------------------------
* Process GAMA
*	- Keep years 1981+
*	- For each well and year: keep one observation from
*		the months Jan - May, with date closest to Mar 15
*----------------------------------

import delimited using "$RAW_GAMA/gama_all_dtw_elev.txt"
rename depthtowater dtw

// Format dates
gen int date = date(measurementdate, "MDY")
gen int month = month(date)
gen int year = year(date)

// Filter observations by date
keep if year >= 1981
keep if (month >= 1) & (month <= 5)

// drop unreasonable observations (either negative or very large)
drop if (dtw < 0) | missing(dtw) | (dtw > 3000)

// For each well and year: calculate days between Mar 15 and the date observation was taken
gen int march15_date = mdy(3, 15, year)
gen time_diff = abs(date - march15_date)
drop date march15_date

// for each well and each year: keep the measurements closest to March 15
sort wellnumber year time_diff
by wellnumber year: keep if _n == 1

isid wellnumber year
keep wellnumber longitude latitude dtw year time_diff

save "$DERIVED/gwdepth_gama.dta", replace


*----------------------------------
* Process CNRA
*	- Keep years 1981+
*	- For each well and year: keep one observation from
*		the months Jan - May, with date closest to Mar 15
*----------------------------------

// Prepare stations
import delimited using "$RAW_CNRA/periodic_levels/stations.csv", clear
keep stn_id site_code swn latitude longitude
rename swn wellnumber
tempfile stations
save `stations'

// Prepare measurements
import delimited using "$RAW_CNRA/periodic_levels/measurements.csv", clear
keep stn_id gse_wse msmt_date
rename gse_wse dtw
destring stn_id, replace

// Intermediary variables for dates
gen dailydate = substr(msmt_date, 1, 10)
gen int date = date(dailydate, "YMD")
gen int month = month(date)
gen int year = year(date)

drop msmt_date dailydate

// Filter on date
keep if (year >= 1981) & !missing(year)
keep if (month >= 1) & (month <= 5)

// drop questionable observations
drop if (dtw < 0) | missing(dtw) | (dtw > 3000)

// for each well: for each year, calculate days from March 15 of that year
gen int march15_date = mdy(3, 15, year)
gen time_diff = abs(date - march15_date)
drop date march15_date month

// keep one observation per well and year, as per above
sort stn_id year time_diff
by stn_id year: keep if _n == 1

// merge station names to CNRA dataset
merge m:1 stn_id using `stations'
	drop if _merge==2
	assert _merge==3
	drop _merge

// save
save "$DERIVED/gwdepth_cnra.dta", replace


*---------------------------------------
* Merge GAMA and CNRA datasets
*---------------------------------------

// Match well numbers from CNRA to GAMA measurements
import delimited using "$RAW_CNRA/periodic_levels/stations.csv", clear
keep stn_id site_code swn latitude longitude
rename swn wellnumber
drop if missing(wellnumber)
merge 1:m wellnumber using "$DERIVED/gwdepth_gama.dta"
	drop if _merge==1
	drop _merge

// Append CNRA measurements
append using "$DERIVED/gwdepth_cnra.dta"
drop if missing(dtw)

// Not every observation has both a stn_id and (state) wellnumber,
// so generate unique identifier for each well
sort stn_id wellnumber
egen wellid = group(stn_id wellnumber), missing

// reprocess, keeping one observation per well X year
sort wellid year time_diff
by wellid year: keep if _n == 1

// Save
keep wellid latitude longitude dtw year // stn_id wellnumber time_diff
sort wellid year
isid wellid year
compress
save "$DERIVED/gwdepth_raw_obs.dta", replace

di "01a_gw_depth_stata.do complete. Wrote gwdepth_raw_obs.dta to $DERIVED"
