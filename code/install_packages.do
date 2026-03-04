********************************************************************************
// install_packages.do
// Purpose: Install all required Stata packages.
//          Run once on a new machine before executing 00_run_all.do.
//          Called from 00_run_all.do (uncomment that line on first run).
//
// Date: 2026-03-03
********************************************************************************

// Estimation
cap ssc install reghdfe, replace
cap ssc install ivreghdfe, replace
cap ssc install ivreg2, replace
cap ssc install ranktest, replace
cap ssc install ppmlhdfe, replace
cap ssc install ftools, replace

// Two-way FE IV (legacy — used in some specifications)
cap ssc install xtivreg2, replace

// Table output
cap ssc install estout, replace

// Conley standard errors
// NOTE: conley_se requires manual installation.
// Download from: https://www.trfetzer.com/conley-spatial-hac-errors-revisited/
// Place ado file in your personal ado directory.

di "All packages installed."
