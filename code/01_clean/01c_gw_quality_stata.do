********************************************************************************
// 01c_gw_quality_stata.do
// Purpose: Clean and process raw groundwater quality (chemistry) data.
//          Merges GAMA and CNRA chemistry measurements, prepares CSV exports
//          for GIS interpolation (Stage 2, not reproducible), then converts
//          GIS ASCII grid outputs to Stata panels.
// Source:  prepare_chem1.do + prepare_chem2.do + prepare_chem3.do
//
// Inputs:  $RAW_GAMA/ (GAMA chemistry files)
//          $RAW_CNRA/ (CNRA chemistry files)
//          $GIS_GWQUAL/asc_years_balanced/*.asc  (provided; see Stage 2 note)
//
// Outputs: $DERIVED/gwquality_combined.dta
//          $DERIVED/farmgrid_gwquality_wide.dta
//
// Authors: [Author names]
// Date:    2026-03-03
********************************************************************************

// Globals defined by code/config.do (sourced by 00_run_all.do):
// $RAW_GAMA = data/raw/swrcb_groundwater
// $RAW_CNRA = data/raw/cnra
// $GIS_GWQUAL = data/derived/gis/groundwater_quality
// $DERIVED = data/derived

// Paths set via code/config.do

clear all
pause on
set more off

********************************************************************************
// SECTION 1: prepare_chem1.do
// Process raw GAMA and CNRA chemistry files; save one obs per well x year x chemical
********************************************************************************

*----------------------------------
* Process raw GAMA data
*----------------------------------

// Files to merge
local gama_files "gama_usgsnew_statewide gama_llnl_statewide gama_dpr_statewide gama_dwr_statewide gama_gama_statewide gama_usgs_statewide gama_ddw_statewide"

// Relevant variables
local keeplist "wellid approximatelatitude approximatelongitude chemical qualifier result units date"

foreach filename in `gama_files' {
	// Process raw gama_files
	import delimited using "$RAW_GAMA/`filename'.txt", clear
	cap rename qualifer qualifier

	// Remove unnecessary variables
	keep `keeplist'

	// Format dates. Intermediary variables
	gen int fdate = date(date, "MDY")
	gen int month = month(fdate)
	gen int year = year(fdate)

	// drop observations (before 1981) or (June 1 - Dec 31)
	drop if (year < 1981) | (6 <= month & month <= 12)
	drop if missing(date)

	// for each well: for each year, calculate days from March 15 of that year
	gen int march15_date = mdy(3, 15, year)
	gen time_diff = abs(fdate - march15_date)
	drop fdate march15_date month

	// for each well: for each year, keep the measurements closest to March 15
	sort wellid year chemical time_diff
	by wellid year chemical: keep if _n == 1

	// Verify that wellid X year X chemical is unique key
	tostring wellid, replace
	isid wellid year chemical

	tempfile chem_`filename'
	save `chem_`filename''
}

clear
foreach filename in `gama_files' {
	append using `chem_`filename''
}
duplicates report wellid year chemical
duplicates drop wellid year chemical, force
isid wellid year chemical
save "$DERIVED/gwquality_gama.dta", replace


*----------------------------------
* Process raw CNRA data
*----------------------------------

// Load data and keep only groundwater measurements
import delimited using "$RAW_CNRA/water_quality/lab-results.csv", clear
keep station_id station_name full_station_name station_number station_type latitude longitude sample_date parameter result units
keep if station_type== "Groundwater"

// Keep one observation on level of station X chemical X year,
// using the date from Jan - May closest to Mar 15
gen date = dofc(clock(sample_date, "MDY hm"))
gen month = month(date)
gen year = year(date)
drop if (year < 1981) | (6 <= month & month <= 12)
gen mar15 = mdy(3, 15, year)
gen time_diff = abs(date - mar15)
sort station_id year parameter time_diff
by station_id year parameter: keep if _n == 1
drop date month mar15

// Save
isid station_id year parameter
sort station_id year parameter
compress
save "$DERIVED/gwquality_cnra.dta", replace


********************************************************************************
// SECTION 2: prepare_chem2.do
// Merge GAMA and CNRA chemistry; harmonize chemical names and units
********************************************************************************

clear all
pause on
set more off

*----------------------------------
* Process GAMA dataset
*----------------------------------

use "$DERIVED/gwquality_gama.dta", clear

// drop qualifiers and keep years 2006-2018
drop qualifier
drop if (year < 2006) | (year > 2018) | missing(year)

// rename var names to be consistent with cnra
rename approximatelatitude 	latitude
rename approximatelongitude longitude
rename wellid 				station_number
keep station_number latitude longitude chemical result units year

// keep list of 24 chemicals
keep if inlist(chemical, "NO3N","SC","TDS","NA","CL","ALKB") | ///
		inlist(chemical, "ALKCACO3","CA","MG","SO4","K") | ///
		inlist(chemical, "AS","MN","FE","F","AL","CR","CD","SE") | ///
		inlist(chemical, "NI","BE","CU","ZN","PB")

// no measurements should be negative since we're dealing with concentration
drop if missing(result) | result < 0

// set aside
tempfile gama
save `gama'


*----------------------------------
* Process CNRA dataset
*----------------------------------

// keep list of 24 chemicals, and prepare to merge with gama
use "$DERIVED/gwquality_cnra.dta", clear

assert !missing(station_number)
rename parameter chemical
rename result results
keep station_number latitude longitude chemical result units year time_diff

drop if missing(result) | result < 0

// rename cnra chemicals to be consistent with gama chemicals
// I create parallel lists gama_chem / cnra_chem
local gama_chem1 " NO3N SC TDS NA CL ALKB ALKCACO3"
local gama_chem2 " CA MG SO4 K AS MN FE F"
local gama_chem3 " AL CR CD SE NI BE CU ZN PB"

local cnra_chem1 `" "Dissolved Nitrate" "Specific Conductance" "Total Dissolved Solids" "Dissolved Sodium" "Dissolved Chloride" "Dissolved Bicarbonate (HCO3-)" "Total Alkalinity""'
local cnra_chem2 `" "Dissolved Calcium" "Dissolved Magnesium" "Dissolved Sulfate" "Dissolved Potassium" "Dissolved Arsenic" "Dissolved Manganese" "Dissolved Iron" "Dissolved Fluoride" "'
local cnra_chem3 `" "Dissolved Aluminum" "Dissolved Chromium" "Dissolved Cadmium" "Dissolved Selenium" "Dissolved Nickel" "Dissolved Beryllium" "Dissolved Copper" "Dissolved Zinc" "Dissolved Lead" "'

local gama_chem `" `gama_chem1' `gama_chem2' `gama_chem3' "'
local cnra_chem `" `cnra_chem1' `cnra_chem2' `cnra_chem3' "'

local n : word count `gama_chem'
assert `n' == `: word count `cnra_chem''

forval i = 1/`n' {
	local gama_name `: word `i' of `gama_chem''
	local cnra_name `: word `i' of `cnra_chem''
	replace chemical = "`gama_name'" if chemical == "`cnra_name'"
}

keep if inlist(chemical, "NO3N","SC","TDS","NA","CL","ALKB") | ///
		inlist(chemical, "ALKCACO3","CA","MG","SO4","K") | ///
		inlist(chemical, "AS","MN","FE","F","AL","CR","CD","SE") | ///
		inlist(chemical, "NI","BE","CU","ZN","PB")

// Append GAMA data
append using `gama'
sort station_number chemical year time_diff
by station_number chemical year: keep if _n == 1
isid station_number chemical year
drop time_diff

// Make units consistent between GAMA and CNRA data
replace units = upper(units)
replace units = "MG/L" if units == "MG/L AS CACO3"
// Specific conductivity uses two units: siemens and ohms, which are reciprocals of each other.
replace result = 1/result if units == "US/CM@25DEGC"
replace units = "UMHOS/CM" if units == "US/CM@25DEGC"

// This looks complicated, but I'm just converting units
// between MG/L and UG/L, depending on which unit is used most often for that chemical.
bysort chemical: egen mg = sum(units == "MG/L")
by chemical: egen ug = sum(units == "UG/L")
// convert MG/L to UG/L
replace result = result * 1000 if (mg != 0 & ug != 0) & (ug > mg) & units == "MG/L"
replace units = "UG/L" if (mg != 0 & ug != 0) & (ug > mg) & units == "MG/L"
// convert UG/L to MG/L
replace result = result / 1000 if (mg != 0 & ug != 0) & (ug < mg) & units == "UG/L"
replace units = "MG/L" if (mg != 0 & ug != 0) & (ug < mg) & units == "UG/L"

/* Alternatively, just convert all concentration measurements to MG/L
replace result = result * 1000 if units == "UG/L"
replace units = "MG/L" if units == "UG/L"
*/

drop mg ug
gen asinh_res = asinh(results)

compress
sort chemical year station_number
save "$DERIVED/gwquality_combined.dta", replace


// Export parameter-specific tables
local params NO3N TDS ALKB
foreach c of local params {
	forval yr = 2007/2018 {
		use "$DERIVED/gwquality_combined.dta" if (year == `yr') & (chemical == "`c'"), replace
		export delimited using "$DERIVED/gwquality_params/gwquality_`c'_`yr'.csv", replace
	}
}


********************************************************************************
// SECTION 3: prepare_chem3.do
// Convert GIS ASCII rasters (chemistry) to Stata; merge to farmgrid
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
* Interpolation raster metadata
*----------------------------------

/*
* ncols         5145
* nrows         4750
* xllcorner     -124.42
* yllcorner     32.51
* cellsize      0.002
* NODATA_value  -9999
*/

local cellsize	= 0.001 // in decimal degrees
local xleft		= -124.42
local ytop		= 42.01

// Define lists of parameters
*local chem_list "al alkb alkcaco3 as be ca cd cl cr cu f fe k mg mn na ni no3n pb sc se so4 tds zn"
*local unit_list "UG/L MG/L MG/L UG/L UG/L MG/L UG/L MG/L UG/L MG/L MG/L UG/L MG/L MG/L UG/L MG/L UG/L MG/L UG/L UMHOS/CM UG/L MG/L MG/L MG/L"
*local name_list `" "Aluminum" "Bicarbonate Alkalinity" "Alkalinity as CaCO3" "Arsenic" "Beryllium" "Calcium" "Cadmium" "Chloride" "Chromium" "Copper" "Fluoride" "Iron" "Potassium" "Magnesium" "Manganese" "Sodium" "Nickel" "Nitrate as N" "Lead" "Specific Conductivity" "Selenium" "Sulfate" "Total Dissolved Solids" "Zinc" "'
*local chem_list "no3n tds alkb"
*local name_list `" "Nitrate as N" "Total Dissolved Solids" "Bicarbonate Alkalinity" "'
*local unit_list "MG/L MG/L MG/L"
local chem_list "tds"
local name_list `" "Total Dissolved Solids" "'
local unit_list "MG/L"
/*
*----------------------------------
* Convert asc to dta and calculate raster pixel centroids
*----------------------------------
local n : word count `chem_list'
assert `n' == `: word count `unit_list''
forval i = 1/`n' {
	local chem `: word `i' of `chem_list''
	local unit `: word `i' of `unit_list''
	local name `: word `i' of `name_list''
	*forval yr = 2007/2018 {
	forval yr = 2012/2014 {
		disp "Converting parameter `chem', year `yr'..."
		local fname = "`chem'" + "_" + "`yr'"
		ras2dta, files("$GIS_GWQUAL/asc_rast/`fname'") genxcoord(xcoord) genycoord(ycoord) missing(2147483647) dropmiss replace clear
		gen longitude	= `xleft' + `cellsize'/2 + (xcoord-1)*`cellsize'
		gen latitude	= `ytop'  - `cellsize'/2 - (ycoord-1)*`cellsize'
		save "$GIS_GWQUAL/asc_rast/`fname'.dta", replace
		erase "$GIS_GWQUAL/asc_rast/`fname'.asc"
	}
}
*/
*----------------------------------
* Round farmgrid coords and match to itp raster
*----------------------------------
// Round farmgrid coords to nearest centroid. Note that to match a centroid we
// must first round to multiple of cellsize and then offset by cellsize/2
*use "$DERIVED/cafarmgrid_table.dta", clear
*gen longitude 	= round(centroid_x - `cellsize'/2, `cellsize') + `cellsize'/2
*gen latitude 	= round(centroid_y - `cellsize'/2, `cellsize') + `cellsize'/2
use "$DERIVED/farmgrid_gwquality_wide.dta", clear
local n : word count `chem_list'
assert `n' == `: word count `unit_list''
forval i = 1/`n' {
	local chem `: word `i' of `chem_list''
	local unit `: word `i' of `unit_list''
	local name `: word `i' of `name_list''
	*forval yr = 2007/2018 {
	forval yr = 2012/2018 {
		disp "Merging parameter `chem', year `yr'..."
		local fname = "`chem'" + "_" + "`yr'"
		fmerge m:1 longitude latitude using "$GIS_GWQUAL/asc_rast/`fname'.dta", gen(merge_`fname')
			drop if merge_`fname' == 2
			assert merge_`fname' == 3
			drop xcoord ycoord
	}
}

// Save
drop merge*
drop longitude latitude acres centroid_*
sort objectid
compress
save "$DERIVED/farmgrid_gwquality_wide.dta", replace

// Save mean dataset
use "$DERIVED/farmgrid_gwquality_wide.dta", clear
gen tds_avg = 0
local yrs 0
foreach var of varlist tds_20?? {
	replace tds_avg = tds_avg + `var'
	local yrs = `yrs' + 1
}
replace tds_avg = tds_avg / `yrs'
drop tds_20??
sort objectid
save "$DERIVED/farmgrid_gwquality_mean.dta", replace

// Save long dataset
use "$DERIVED/farmgrid_gwquality_wide.dta", clear
reshape long tds_, i(objectid) j(year)
rename tds_ tds
sort objectid year
save "$DERIVED/farmgrid_gwquality_long.dta", replace
