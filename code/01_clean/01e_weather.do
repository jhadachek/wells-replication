********************************************************************************
// 01e_weather.do
// Purpose: Process Schlenker weather data into degree-day and long-term climate
//          averages used in the analysis panels.
//          Consolidates:
//            calculate_degreedays.do  — Step 1: compute degree days from raw daily data
//            prepare_weather1.do      — Step 2: compute long-term climate averages
//            prepare_weather2.do      — Step 3: output final quarterly/yearly weather files
//
// Inputs:  $RAW/weather_schlenker/raw/06_{year}.dta  (Schlenker daily weather grid,
//                                                      1950–2017; request from author)
//          $RAW/weather_schlenker/cropArea.dta        (grid metadata)
//          $RAW/farmgrid/cafarmgrid_table.dta         (farm-grid crosswalk; from N. Hagerty)
//
// Outputs: $DERIVED/temp/dd_06_{year}.dta            (intermediate: monthly degree days)
//          $DERIVED/temp/gridInfo.dta                 (intermediate: grid lat/lon)
//          $DERIVED/farmgrid_weather_crosswalk.dta
//          $DERIVED/weather_ltavg_1950-1979.dta
//          $DERIVED/weather_ltavg_1980-2017.dta
//          $DERIVED/weather_prepped_lt5079.dta
//          $DERIVED/weather_prepped_lt8017.dta
//          $DERIVED/weather_prepped_yearly.dta
//
// Notes:   - Schlenker weather data is not publicly available; request from
//            Wolfram Schlenker (Columbia).
//          - Farm-grid crosswalk is not publicly available; request from Nick Hagerty.
//          - Step 1 loops over 1950–2017. The original script had a test loop over
//            2016–2017 only; restored to full production range here.
//          - $RAW_WEATHER → $RAW/weather_schlenker
//          - $RAW_FARMGRID → $RAW/farmgrid
//          - $DATA_COVARS  → $DERIVED
//
// Date:    2026-03-03
********************************************************************************

// Globals set by code/config.do via 00_run_all.do
// $RAW, $DERIVED already defined

// Create temp subdirectory for intermediate year files
capture mkdir "$DERIVED/temp"


********************************************************************************
// STEP 1: Calculate degree days from raw Schlenker daily data
// Source: calculate_degreedays.do
********************************************************************************

clear all
set more off

// Temperature bin lower bounds
local boundList 0 5 8 10 12 15 20 25 29 30 31 32 33 34

forvalues year = 2017(-1)1950 {

	// Load data
	disp "Processing year `year', at $S_TIME $S_DATE"
	disp "     Loading..."
	quietly {
		use "$RAW/weather_schlenker/raw/06_`year'", clear
		rename prec precip
		label var precip "Precipitation (mm)"
		label var tMin "Minimum temperature (degrees C)"
		label var tMax "Maximum temperature (degrees C)"

		// Extract month
		gen int month = mofd(dateNum)
		format month %tm
		label var month "Month and year"

		// Calculate average temperature
		gen tAvg = (tMin + tMax)/2
		label var tAvg "Mean temperature (mean of minimum and maximum) (degrees C)"

		// Calculate vapor pressure deficit
		gen vpd = 0.6107 * (exp(17.269*tMax/(237.3+tMax)) - exp(17.269*tMin/(237.3+tMin)))
		label var vpd "Vapor pressure deficit (kPa)"
	}

	// Calculate degree days (dday) and time above bound (bday)
	disp "     Calculating..."
	quietly {
		foreach b of local boundList {

			// Make bin label
			if `b'<0 {
				local bLabel Minus`=abs(`b')'
			}
			else {
				local bLabel `b'
			}

			* case 1: bound >= tMax
			gen float dday`bLabel' = 0
			gen float bday`bLabel' = 0

			* case 2: bound <= tMin
			replace dday`bLabel' = tAvg-`b' if `b'<=tMin
			replace bday`bLabel' = 1        if `b'<=tMin

			* case 3: tMin < bound < tMax
			gen HalfTauAboveBound = acos( (2*`b'-tMax-tMin)/(tMax-tMin) )
			replace dday`bLabel' = ( (tAvg-`b')*HalfTauAboveBound                ///
					       + (tMax-tMin)*sin(HalfTauAboveBound)/2 )/_pi   ///
				if ( (tMin < `b') & (`b' < tMax) )
			replace bday`bLabel' = HalfTauAboveBound/_pi                          ///
				if ( (tMin < `b') & (`b' < tMax) )
			drop HalfTauAboveBound

			* label variables
			label var dday`bLabel' "Degree days above `b' degrees C"
			label var bday`bLabel' "Days above `b' degrees C"

		}
	}

	// Collapse by month
	disp "     Collapsing..."
	quietly {
		foreach v of varlist * {
			local l_`v': variable label `v'
		}
		sort gridNumber month
		foreach var of varlist tMin tMax tAvg vpd {
			by gridNumber month: egen float `var'_mean = mean(`var')
			drop `var'
			rename `var'_mean `var'
		}
		foreach var of varlist precip dday* bday* {
			by gridNumber month: gen float `var'_sum = sum(`var')
			drop `var'
			rename `var'_sum `var'
		}
		by gridNumber month: keep if _n==_N
		order bday*, last
		drop dateNum
		foreach v of varlist * {
			label var `v' "`l_`v''"
		}
	}

	// Save
	disp "     Saving..."
	quietly save "$DERIVED/temp/dd_06_`year'.dta", replace

}


********************************************************************************
// STEP 2: Compute long-term climate averages
// Source: prepare_weather1.do
********************************************************************************

// Attach lat/lon to grid information
use "$RAW/weather_schlenker/cropArea.dta", clear
gen longitude = -125 + mod(gridNumber-1,1405)/24
gen latitude  = 49.9375+1/48 - ceil(gridNumber/1405)/24
label var longitude "Longitude of grid centroid (decimal degrees)"
label var latitude  "Latitude of grid centroid (decimal degrees)"
compress
sort gridNumber
save "$DERIVED/temp/gridInfo.dta", replace


// Merge PRISM grid to farm-grid table
use "$RAW/farmgrid/cafarmgrid_table.dta"
drop acres
gen longitude = round(centroid_x*24,1)/24
gen latitude  = round(centroid_y*24,1)/24
merge m:1 longitude latitude using "$DERIVED/temp/gridInfo.dta"
	drop if _merge==2
	assert _merge==3
	drop _merge
keep objectid gridNumber
save "$DERIVED/farmgrid_weather_crosswalk.dta", replace


// Long-term averages, 1950–1979
clear
forvalues year=1950/1979 {
	disp "Year `year'"
	append using "$DERIVED/temp/dd_06_`year'.dta"
}
quietly {
	gen int year = year(dofm(month))
	gen byte mm = month(dofm(month))
	drop month
	rename mm month
	order year month, after(gridNumber)
	foreach v of varlist * {
		local l_`v': variable label `v'
	}
	sort gridNumber month
}
foreach var of varlist tMin tMax tAvg vpd precip dday* bday* {
	disp "Calculating `var'"
	qui by gridNumber month: egen float `var'_mean = mean(`var')
	qui drop `var'
	qui rename `var'_mean `var'
}
quietly {
	foreach v of varlist * {
		label var `v' "`l_`v''"
	}
}
by gridNumber month: keep if _n==_N
drop year
save "$DERIVED/weather_ltavg_1950-1979.dta", replace


// Long-term averages, 1980–2017
clear
forvalues year=1980/2017 {
	disp "Year `year'"
	append using "$DERIVED/temp/dd_06_`year'.dta"
}
quietly {
	gen int year = year(dofm(month))
	gen byte mm = month(dofm(month))
	drop month
	rename mm month
	order year month, after(gridNumber)
	foreach v of varlist * {
		local l_`v': variable label `v'
	}
	sort gridNumber month
}
foreach var of varlist tMin tMax tAvg vpd precip dday* bday* {
	disp "Calculating `var'"
	qui by gridNumber month: egen float `var'_mean = mean(`var')
	qui drop `var'
	qui rename `var'_mean `var'
}
quietly {
	foreach v of varlist * {
		label var `v' "`l_`v''"
	}
}
by gridNumber month: keep if _n==_N
drop year
save "$DERIVED/weather_ltavg_1980-2017.dta", replace


********************************************************************************
// STEP 3: Output final quarterly and yearly weather files
// Source: prepare_weather2.do
********************************************************************************

// Long-term data, 1950–1979 (quarterly × gridNumber)
use "$DERIVED/weather_ltavg_1950-1979.dta", clear
* simplify temperature categories
keep gridNumber-precip ?day0 ?day8 ?day29 ?day32 ?day34
* collapse to quarter
gen quarter = ceil(month/3)
collapse (mean) tMin-vpd (sum) precip-bday34, by(gridNumber quarter)
* reshape to gridNumber
foreach v of varlist tMin-bday34 {
	rename `v' lt5079_`v'_q
}
reshape wide lt5079*, i(gridNumber) j(quarter)
* save
recast float *_q?, force
sort gridNumber
isid gridNumber
save "$DERIVED/weather_prepped_lt5079.dta", replace


// Long-term data, 1980–2017 (quarterly × gridNumber)
use "$DERIVED/weather_ltavg_1980-2017.dta", clear
* simplify temperature categories
keep gridNumber-precip ?day0 ?day8 ?day29 ?day32 ?day34
* collapse to quarter
gen quarter = ceil(month/3)
collapse (mean) tMin-vpd (sum) precip-bday34, by(gridNumber quarter)
* reshape to gridNumber
foreach v of varlist tMin-bday34 {
	rename `v' lt8015_`v'_q
}
reshape wide lt8015*, i(gridNumber) j(quarter)
* save
recast float *_q?, force
sort gridNumber
isid gridNumber
save "$DERIVED/weather_prepped_lt8017.dta", replace


// Yearly data, 1980–2017 (quarterly × gridNumber × year)
forvalues year=1980/2017 {

	* load data
	use "$DERIVED/temp/dd_06_`year'.dta", clear

	* simplify temperature categories
	keep gridNumber-precip ?day0 ?day8 ?day29 ?day32 ?day34

	* format new time variables
	gen year = year(dofm(month))
	gen quarter = quarter(dofm(month))
	order year quarter, before(month)
	drop month

	* collapse to quarter
	collapse (mean) tMin-vpd (sum) precip-bday34, by(gridNumber year quarter)

	* reshape to gridNumber
	foreach v of varlist tMin-bday34 {
		rename `v' `v'_q
	}
	reshape wide *_q, i(gridNumber year) j(quarter)

	* set aside
	tempfile w`year'
	save `w`year''
}

// Append together
clear
forvalues year=1980/2017 {
	append using `w`year''
}

// Save
sort gridNumber year
isid gridNumber year
compress
save "$DERIVED/weather_prepped_yearly.dta", replace
