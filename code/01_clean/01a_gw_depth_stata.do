********************************************************************************
// 01a_gw_depth_stata.do
// Purpose: Clean and process raw groundwater depth (DTW) data.
//          Merges GAMA and CNRA periodic level measurements, prepares
//          CSV exports for GIS interpolation (Stage 2, not reproducible),
//          then converts GIS ASCII grid outputs to Stata panels.
// Source:  prepare_dtw1.do + prepare_dtw2.do + prepare_dtw3.do
//
// Inputs:  $RAW_GAMA/gama_all_dtw_elev.txt
//          $RAW_CNRA/measurements.csv, stations.csv
//          $GIS_GWDEPTH/asc_years_balanced/*.asc  (provided; see Stage 2 note)
//
// Outputs: $DERIVED/gwdepth_raw_obs.dta
//          $DERIVED/farmgrid_gwdepth_wide.dta
//          $DERIVED/farmgrid_gwdepth_long.dta
//          $DERIVED/farmgrid_gwdepth_means_unbalanced.dta
//
// Authors: [Author names]
// Date:    2026-03-03
********************************************************************************

// Globals defined by code/config.do (sourced by 00_run_all.do):
// $RAW_GAMA = data/raw/swrcb_groundwater
// $RAW_CNRA = data/raw/cnra
// $GIS_GWDEPTH = data/derived/gis/groundwater_depth
// $DERIVED = data/derived

// Paths set via code/config.do

clear all
pause on
set more off

********************************************************************************
// SECTION 1: prepare_dtw1.do
// Merge GAMA + CNRA periodic depth measurements; export CSV for GIS
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

// Export all data for each year
preserve
levelsof year, local(years)
foreach yr of local years {
	keep if year == `yr'
	count
	export delimited using "$DERIVED/gwdepth`yr'.csv", replace
	restore, preserve
}

// Export a balanced panel for wells that appear in every year 2007-2018
local start = 2007
local end = 2018
keep if (`start' <= year) & (year <= `end')
bysort wellid: egen nyears = count(wellid)
keep if nyears == (`end' - `start' + 1)
preserve
levelsof year, local(years)
foreach yr of local years {
	keep if year == `yr'
	count
	export delimited using "$DERIVED/gwdepth_balancedpanel_`yr'.csv", replace
	restore, preserve
}


********************************************************************************
// SECTION 2: prepare_dtw2.do
// Convert GIS ASCII rasters (balanced panel) to Stata; merge to farmgrid
// NOTE: Stage 2 GIS interpolation is not reproducible; .asc files provided.
********************************************************************************

clear all
pause on
set more off
version 14
ssc install geoinpoly
net install dm0014, from(http://www.stata-journal.com/software/sj5-2)
ssc install shp2dta

*----------------------------------
* Raster grid metadata
*----------------------------------

/* Match dtw interpolation to farmgrid by closest centroid.
*	Convert xy coord of each raster pixel to lat and long of centroid,
*	using the following metadata
*
*	ncols         5145
*	nrows         4750
*	xllcorner     -124.42
*	yllcorner     32.51
*	cellsize      0.002
*	NODATA_value  -9999
*/

* Changing resolution of dtw should be as simple as changing cellsize
* here and in the Python script (assuming boundaries remain the same)
local cellsize 	= 0.001
local xleft 	= -124.42
local ytop		= 42.01

*----------------------------------
* Convert asc to dta and calculate raster pixel centroids
*----------------------------------
forval yr = 2007/2018 {
	ras2dta, files("$GIS_GWDEPTH/asc_raster_balanced/itp`yr'") genxcoord(xcoord) genycoord(ycoord) missing(2147483647) dropmiss replace clear
	rename itp`yr' dtw`yr'
	gen longitude	= `xleft' + `cellsize'/2 + (xcoord-1)*`cellsize'
	gen latitude	= `ytop'  - `cellsize'/2 - (ycoord-1)*`cellsize'
	save "$GIS_GWDEPTH/asc_raster_balanced/itp`yr'.dta", replace
	erase "$GIS_GWDEPTH/asc_raster_balanced/itp`yr'.asc"
}

*----------------------------------
* Round farmgrid coords and match to itp raster
*----------------------------------
// Round farmgrid coords to nearest centroid. Note that to match a centroid we
// must first round to multiple of cellsize and then offset by cellsize/2
use "$DERIVED/cafarmgrid_table.dta", clear
gen longitude 	= round(centroid_x - `cellsize'/2, `cellsize') + `cellsize'/2
gen latitude 	= round(centroid_y - `cellsize'/2, `cellsize') + `cellsize'/2
forval yr = 2007/2018 {
	disp "Merging year `yr'..."
	merge m:1 longitude latitude using "$GIS_GWDEPTH/asc_raster_balanced/itp`yr'.dta", gen(merge`yr')
		drop if merge`yr' == 2
		assert merge`yr' == 3
		drop xcoord ycoord
}

// Save wide dataset
drop merge*
drop longitude latitude acres centroid_*
sort objectid
compress
save "$DERIVED/farmgrid_gwdepth_wide.dta", replace

// Save mean dataset
use "$DERIVED/farmgrid_gwdepth_wide.dta", clear
gen dtw_avg = 0
local yrs 0
foreach var of varlist dtw20?? {
	replace dtw_avg = dtw_avg + `var'
	local yrs = `yrs' + 1
}
replace dtw_avg = dtw_avg / `yrs'
drop dtw20??
sort objectid
save "$DERIVED/farmgrid_gwdepth_mean_balanced.dta", replace

// Save long dataset
use "$DERIVED/farmgrid_gwdepth_wide.dta", clear
reshape long dtw, i(objectid) j(year)
sort objectid year
save "$DERIVED/farmgrid_gwdepth_long.dta", replace


********************************************************************************
// SECTION 3: prepare_dtw3.do
// Convert GIS ASCII rasters (unbalanced period means) to Stata; merge to farmgrid
// NOTE: Stage 2 GIS interpolation is not reproducible; .asc files provided.
********************************************************************************

clear all
pause on
set more off
version 14
ssc install geoinpoly
net install dm0014, from(http://www.stata-journal.com/software/sj5-2)
ssc install shp2dta

*----------------------------------
* Raster grid metadata
*----------------------------------

/* Match dtw interpolation to farmgrid by closest centroid.
*	Convert xy coord of each raster pixel to lat and long of centroid,
*	using the following metadata
*
*	ncols         5145
*	nrows         4750
*	xllcorner     -124.42
*	yllcorner     32.51
*	cellsize      0.002
*	NODATA_value  -9999
*/

* Changing resolution of dtw should be as simple as changing cellsize
* here and in the Python script (assuming boundaries remain the same)
local cellsize 	= 0.001
local xleft 	= -124.42
local ytop		= 42.01

* mean #3
ras2dta, files("$GIS_GWDEPTH/asc_raster_unbalanced/mean_2007_2018") genxcoord(xcoord) genycoord(ycoord) missing(2147483647) dropmiss replace clear
rename mean dtw_2007_2018
gen longitude	= `xleft' + `cellsize'/2 + (xcoord-1)*`cellsize'
gen latitude	= `ytop'  - `cellsize'/2 - (ycoord-1)*`cellsize'
keep dtw l*itude
save "$GIS_GWDEPTH/asc_raster_unbalanced/mean_tomerge_2007_2018.dta", replace

* mean #2
ras2dta, files("$GIS_GWDEPTH/asc_raster_unbalanced/mean_1993_2006") genxcoord(xcoord) genycoord(ycoord) missing(2147483647) dropmiss replace clear
rename mean dtw_1993_2006
gen longitude	= `xleft' + `cellsize'/2 + (xcoord-1)*`cellsize'
gen latitude	= `ytop'  - `cellsize'/2 - (ycoord-1)*`cellsize'
keep dtw l*itude
save "$GIS_GWDEPTH/asc_raster_unbalanced/mean_tomerge_1993_2006.dta", replace

* mean #1
ras2dta, files("$GIS_GWDEPTH/asc_raster_unbalanced/mean_1981_1992") genxcoord(xcoord) genycoord(ycoord) missing(2147483647) dropmiss replace clear
rename mean dtw_1981_1992
gen longitude	= `xleft' + `cellsize'/2 + (xcoord-1)*`cellsize'
gen latitude	= `ytop'  - `cellsize'/2 - (ycoord-1)*`cellsize'
keep dtw l*itude
save "$GIS_GWDEPTH/asc_raster_unbalanced/mean_tomerge_1981_1992.dta", replace


*----------------------------------
* Round farmgrid coords and match to itp raster
*----------------------------------
// Round farmgrid coords to nearest centroid. Note that to match a centroid we
// must first round to multiple of cellsize and then offset by cellsize/2
use "$DERIVED/cafarmgrid_table.dta", clear
gen longitude 	= round(centroid_x - `cellsize'/2, `cellsize') + `cellsize'/2
gen latitude 	= round(centroid_y - `cellsize'/2, `cellsize') + `cellsize'/2
fmerge m:1 longitude latitude using "$GIS_GWDEPTH/asc_raster_unbalanced/mean_tomerge_1981_1992.dta", gen(merge1)
	drop if merge1 == 2
	assert merge1 == 3
fmerge m:1 longitude latitude using "$GIS_GWDEPTH/asc_raster_unbalanced/mean_tomerge_1993_2006.dta", gen(merge2)
	drop if merge2 == 2
	assert merge2 == 3
fmerge m:1 longitude latitude using "$GIS_GWDEPTH/asc_raster_unbalanced/mean_tomerge_2007_2018.dta", gen(merge3)
	drop if merge3 == 2
	assert merge3 == 3

// Save
drop merge*
drop longitude latitude acres centroid_*
sort objectid
compress
save "$DERIVED/farmgrid_gwdepth_means_unbalanced.dta", replace
