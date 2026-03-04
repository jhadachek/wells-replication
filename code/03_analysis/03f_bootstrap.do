********************************************************************************
// 03f_bootstrap.do
// Purpose: Define Stata program stubs used for bootstrapping standard errors on
//          agricultural well construction PPML-IV estimates. This utility script
//          is called by 03b_ag_construction.do; data must already be loaded by
//          the calling script.
// Source:  wells_boot.do
//
// Inputs:  (none — data loaded by calling script 03b_ag_construction.do)
// Outputs: Bootstrap confidence interval results returned to calling script via
//          r() scalars
//
// Paper element: Bootstrap utility called by 03b_ag_construction.do
//
// Authors: [Author names]
// Date:    2026-03-03
********************************************************************************

// Paths set via code/config.do (run from replication/ directory)

********************************************************************************
// Setup panel identifier expected by all program stubs below
********************************************************************************

gen newid=DAUCO
xtset newid year

********************************************************************************
// Program: wells_boot
// Log-linear specification, unweighted
********************************************************************************

program wells_boot, rclass


*First Stage
xtreg l_ag_deliveries_acre l_ag_allocation_acre hdd gdd precip i.year, fe  cluster(newid)
predict deliv_hat, resid
* Second Stage
ppmlhdfe construction l_ag_deliveries_acre deliv_hat hdd gdd precip, a(newid year) cluster(newid)


return scalar bl_ag_deliv_acre= _b[l_ag_deliveries_acre]
return scalar b_deliv_hat = _b[deliv_hat]
return scalar b_hdd=_b[hdd]
return scalar b_gdd=_b[gdd]
return scalar b_precip=_b[precip]


drop deliv_hat
end


********************************************************************************
// Program: wells_boot_lvl
// Levels specification, unweighted
********************************************************************************

program wells_boot_lvl, rclass


*First Stage
xtreg ag_deliveries_acre ag_allocation_acre  hdd gdd precip i.year, fe  cluster(newid)
predict deliv_hat, resid
* Second Stage
ppmlhdfe construction ag_deliveries_acre deliv_hat hdd gdd precip, a(newid year) cluster(newid)


return scalar b_ag_deliv_acre= _b[ag_deliveries_acre]
return scalar b_deliv_hat = _b[deliv_hat]
return scalar b_hdd=_b[hdd]
return scalar b_gdd=_b[gdd]
return scalar b_precip=_b[precip]


drop deliv_hat
end




********************************************************************************
// Program: wells_boot_weight
// Log-linear specification, crop-acre weighted
********************************************************************************

program wells_boot_weight, rclass


*First Stage
xtreg l_ag_deliveries_acre l_ag_allocation_acre  hdd gdd precip  i.year [weight=crop_acres], fe  cluster(newid)
predict deliv_hat, resid
* Second Stage
ppmlhdfe construction l_ag_deliveries_acre deliv_hat hdd gdd precip [weight=crop_acres], a(newid year) cluster(newid)


return scalar bl_ag_deliv_acre= _b[l_ag_deliveries_acre]
return scalar b_deliv_hat = _b[deliv_hat]
return scalar b_hdd=_b[hdd]
return scalar b_gdd=_b[gdd]
return scalar b_precip=_b[precip]


drop deliv_hat
end

*bootstrap r(bl_ag_deliv_acre) r(b_deliv_hat) r(b_hdd) r(b_gdd), reps(500) seed(1234) cluster(DAUCO) idcluster(newid): wells_boot


********************************************************************************
// Program: wells_boot_lvl_weight_noctrl
// Levels specification, crop-acre weighted, no weather controls
********************************************************************************

program wells_boot_lvl_weight_noctrl, rclass


*First Stage
xtreg ag_deliveries_acre ag_allocation_acre i.year [weight=crop_acres], fe  cluster(newid)
predict deliv_hat, resid
* Second Stage
ppmlhdfe construction ag_deliveries_acre deliv_hat [weight=crop_acres], a(newid year) cluster(newid)


return scalar b_ag_deliv_acre= _b[ag_deliveries_acre]
return scalar b_deliv_hat = _b[deliv_hat]

drop deliv_hat
end

********************************************************************************
// Program: wells_boot_lvl_weight
// Levels specification, crop-acre weighted, with weather controls
********************************************************************************

program wells_boot_lvl_weight, rclass


*First Stage
xtreg ag_deliveries_acre ag_allocation_acre hdd gdd precip i.year [weight=crop_acres], fe  cluster(newid)
predict deliv_hat, resid
* Second Stage
ppmlhdfe construction ag_deliveries_acre deliv_hat hdd gdd precip [weight=crop_acres], a(newid year) cluster(newid)


return scalar b_ag_deliv_acre= _b[ag_deliveries_acre]
return scalar b_deliv_hat = _b[deliv_hat]
return scalar b_hdd=_b[hdd]
return scalar b_gdd=_b[gdd]
return scalar b_precip=_b[precip]


drop deliv_hat
end

********************************************************************************
// Program: wells_boot_lvl_lag1
// Levels specification, crop-acre weighted, one lag of deliveries and allocation
********************************************************************************

program wells_boot_lvl_lag1, rclass


*First Stage
xtreg ag_deliveries_acre ag_allocation_acre  L.ag_allocation_acre hdd L.hdd gdd precip i.year [weight=crop_acres], fe  cluster(newid)
predict double deliv_hat, e
xtreg L.ag_deliveries_acre ag_allocation_acre L.ag_allocation_acre hdd L.hdd gdd precip i.year [weight=crop_acres], fe  cluster(newid)
predict double deliv_hat1, e

* Second Stage
ppmlhdfe construction ag_deliveries_acre L.ag_deliveries_acre deliv_hat deliv_hat1 hdd L.hdd gdd precip [weight=crop_acres], a(newid year) cluster(newid)


return scalar b_ag_deliv_acre= _b[ag_deliveries_acre]
return scalar b_ag_deliv_acre1=_b[L.ag_deliveries_acre]
return scalar b_deliv_hat = _b[deliv_hat]
return scalar b_deliv_hat1=_b[deliv_hat1]
return scalar b_hdd=_b[hdd]
return scalar b_hdd1=_b[L.hdd]
return scalar b_gdd=_b[gdd]
return scalar b_precip=_b[precip]


drop deliv_hat deliv_hat1
end


********************************************************************************
// Program: wells_boot_lvl_lag2
// Levels specification, crop-acre weighted, two lags of deliveries and allocation
********************************************************************************

program wells_boot_lvl_lag2, rclass


*First Stage
xtreg ag_deliveries_acre ag_allocation_acre  L.ag_allocation_acre L2.ag_allocation_acre hdd L.hdd L2.hdd gdd precip i.year [weight=crop_acres], fe  cluster(newid)
predict double deliv_hat, e
xtreg L.ag_deliveries_acre ag_allocation_acre L.ag_allocation_acre L2.ag_allocation_acre hdd L.hdd L2.hdd gdd precip i.year [weight=crop_acres], fe  cluster(newid)
predict double deliv_hat1, e
xtreg L2.ag_deliveries_acre ag_allocation_acre L.ag_allocation_acre L2.ag_allocation_acre hdd L.hdd L2.hdd gdd precip i.year [weight=crop_acres], fe  cluster(newid)
predict double deliv_hat2, e

* Second Stage
ppmlhdfe construction ag_deliveries_acre L.ag_deliveries_acre L2.ag_deliveries_acre deliv_hat deliv_hat1 deliv_hat2 hdd L.hdd L2.hdd gdd precip [weight=crop_acres], a(newid year) cluster(newid)


return scalar b_ag_deliv_acre= _b[ag_deliveries_acre]
return scalar b_ag_deliv_acre1=_b[L.ag_deliveries_acre]
return scalar b_ag_deliv_acre2=_b[L2.ag_deliveries_acre]
return scalar b_deliv_hat = _b[deliv_hat]
return scalar b_deliv_hat1=_b[deliv_hat1]
return scalar b_deliv_hat2=_b[deliv_hat2]
return scalar b_hdd=_b[hdd]
return scalar b_hdd1=_b[L.hdd]
return scalar b_hdd2=_b[L2.hdd]
return scalar b_gdd=_b[gdd]
return scalar b_precip=_b[precip]


drop deliv_hat deliv_hat1 deliv_hat2
end


********************************************************************************
// Program: wells_boot_lvl_weight_dday29
// Levels specification, crop-acre weighted, using dday29 heat measure
********************************************************************************

program wells_boot_lvl_weight_dday29, rclass


*First Stage
xtreg ag_deliveries_acre ag_allocation_acre dday29 gdd precip i.year [weight=crop_acres], fe  cluster(newid)
predict deliv_hat, resid
* Second Stage
ppmlhdfe construction ag_deliveries_acre deliv_hat dday29 gdd precip [weight=crop_acres], a(newid year) cluster(newid)


return scalar b_ag_deliv_acre= _b[ag_deliveries_acre]
return scalar b_deliv_hat = _b[deliv_hat]
return scalar b_dday29=_b[dday29]
return scalar b_gdd=_b[gdd]
return scalar b_precip=_b[precip]


drop deliv_hat
end
