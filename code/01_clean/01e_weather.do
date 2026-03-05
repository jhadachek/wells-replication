********************************************************************************
// 01e_weather.do
// Purpose: Calculate degree days from Schlenker California daily weather data
//          and attach geographic coordinates (lat/lon) to each weather grid.
//          Loops over years 1993–2019; produces one file per year containing
//          monthly degree days and grid centroids, ready for spatial merging.
//
// Source:  calculate_degreedays_JH.do + grid_to_geo.do (merged)
//          Lat/lon formula: longitude = -125 + mod(gridNumber-1,1405)/24
//                           latitude  = 49.9375+1/48 - ceil(gridNumber/1405)/24
//
// Inputs:  $RAW_SCHLENKER_CA/california{year}.dta
//            Schlenker daily weather grids for California, 1993–2019.
//            Not publicly available; request from Wolfram Schlenker (Columbia).
//
// Outputs: $DERIVED/temp/dd_california_{year}.dta  (one per year, 1993–2019)
//            Variables: gridNumber, longitude, latitude, month,
//                       tMin tMax tAvg vpd precip, dday0–dday34, bday0–bday34
//
// Authors: [Author names]
// Date:    2026-03-05
********************************************************************************

// Globals set by code/config.do via 00_run_all.do:
// $RAW_SCHLENKER_CA   — path to raw California Schlenker daily files
// $DERIVED            — data/derived

clear all
pause on
set more off

// Create temp subdirectory for intermediate year files
capture mkdir "$DERIVED/temp"

// Temperature bin lower bounds
local boundList 0 5 8 10 12 15 20 25 29 30 31 32 33 34

// Loop over years (descending, as in original)
forvalues year = 2019(-1)1993 {

	// Load raw daily data
	disp "Processing year `year', at $S_TIME $S_DATE"
	disp "     Loading..."
	quietly {
		use "$RAW_SCHLENKER_CA/california`year'", clear
		rename prec precip
		label var precip "Precipitation (mm)"
		label var tMin   "Minimum temperature (degrees C)"
		label var tMax   "Maximum temperature (degrees C)"

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

	// Collapse to monthly totals/means by gridNumber
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

	// Attach grid centroid coordinates (source: grid_to_geo.do)
	disp "     Adding grid coordinates..."
	quietly {
		gen longitude = -125 + mod(gridNumber-1,1405)/24
		gen latitude  = 49.9375+1/48 - ceil(gridNumber/1405)/24
		label var longitude "Longitude of grid centroid (decimal degrees)"
		label var latitude  "Latitude of grid centroid (decimal degrees)"
		order gridNumber longitude latitude
		sort gridNumber month
	}

	// Save
	disp "     Saving..."
	compress
	quietly save "$DERIVED/temp/dd_california_`year'.dta", replace

}

di "01e_weather.do complete. Wrote dd_california_1993.dta through dd_california_2019.dta to $DERIVED/temp/"
