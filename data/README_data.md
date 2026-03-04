# Data Dictionary and Provenance

This file describes the main analytical datasets used in Hadachek et al. (2026, JPubE).
All datasets are located in `data/derived/` (gitignored; ~11GB total).

---

## 1. `final.dta` — DAUCO-Year Panel (Agricultural Wells)

**Canonical version:** `final.dta` (confirmed in Phase 1 audit)
**Produced by:** `code/02_merge/02_merge_panels.R` (Stage 3)
**Unit of observation:** DAU-County (DAUCO) × year
**Used by:** `03a_summary_stats.do`, `03b_ag_construction.do`, `03e_long_diff.do`

| Variable | Type | Description |
|----------|------|-------------|
| `DAUCO` | str | DAU-County unit identifier |
| `year` | int | Year |
| `construction` | int | New agricultural well permits |
| `ag_allocation_acre` | float | Surface water allocation per crop acre (IV) |
| `ag_deliveries_acre` | float | Surface water deliveries per crop acre |
| `vol_maximum_ag` | float | Maximum water allocation volume |
| `vol_deliv_cy_ag` | float | Delivered water volume, current year |
| `crop_acres` | float | Cultivated crop acres |
| `hdd` | float | Harmful degree days (heat stress threshold) |
| `gdd` | float | Growing degree days |
| `precip` | float | Annual precipitation (inches) |
| `cum_construction` | float | Cumulative well construction (lagged) |
| `pct_white` | float | % white population (census tract) |
| `pct_pov` | float | % below poverty line (census tract) |
| [additional variables TBD] | | |

---

## 2. `failures_11_23.dta` — Domestic Well Failure Panel

**Canonical version:** `failures_11_23.dta` (dated Nov 2023)
**Produced by:** Upstream cleaning pipeline (not available in full; derived file provided directly)
**Unit of observation:** Well × year
**Used by:** `03c_domestic_failures.do`, `04b_failure_maps.R`, `04c_env_justice.R`

| Variable | Type | Description |
|----------|------|-------------|
| `wellid` | str | Well identifier |
| `year` | int | Year |
| `treat` | int | Well failure indicator (1 = failed) |
| `id` | str | Coordinate-based geographic ID |
| `dist` | float | Distance to nearest WCR well |
| `DateDestruct` | date | Date of well destruction/failure |
| `pump` | int | Pump failure indicator |
| `ag_allocation_acre` | float | Surface water allocation per crop acre (IV) |
| `ag_deliv_acre` | float | Surface water deliveries per crop acre |
| `DAUCO` | str | DAU-County identifier |
| [demographic variables TBD] | | Census tract demographics |
| [depth variables TBD] | | Groundwater depth variables |

---

## 3. `all_wells2.dta` — Monitoring Well Panel (GW Depth)

**Canonical version:** `all_wells2.dta`
**Produced by:** [merge pipeline — Phase 2]
**Unit of observation:** Monitoring well × year
**Used by:** `03d_gw_depth.do`

| Variable | Type | Description |
|----------|------|-------------|
| `wellid` | str | Well identifier |
| `year` | int | Year |
| `dtw` | float | Depth to water (feet below surface) |
| `diff_depth` | float | Change in depth to water (ft/year) |
| `DAUCO` | str | DAU-County identifier |
| `ag_allocation_acre` | float | Surface water allocation per crop acre (IV) |
| `ag_deliv_acre` | float | Surface water deliveries per crop acre |
| `w` | float | Weight = crop acres / number of monitoring wells |
| [additional variables TBD] | | |

---

## Data Versions (versioning history)

| File | Status | Notes |
|------|--------|-------|
| `final.dta` | POSSIBLY CANONICAL | Used by `dauco_tables_2024.do` |
| `final2.dta` | Intermediate | Purpose unclear |
| `final3.dta` | POSSIBLY CANONICAL | Used by `dauco_tables.do` (UC Davis version) |
| `all_wells2.dta` | CANONICAL | Used by all gwdepth scripts |
| `all_wells3.dta` | Intermediate | Likely an earlier merge iteration |
| `all_wells4.dta` | Intermediate | Likely an earlier merge iteration |
| `all_wells5.dta` | OUTPUT of merge | Produced by `add_lagged_weather.R` |
| `failures_11_23.dta` | CANONICAL | Nov 2023 version; used by `domestic_table_25.do` |
| `failure_full_6_8.dta` | Superseded | June 8 version; used by older `domestic_table.do` |
| `failures_full_6_9.dta` | Superseded | June 9 version |
| `failures_SB535.dta` | Special use | SB535 subsample analysis |

**Canonical version confirmed (Phase 1 audit):** `final.dta` is canonical.
`final3.dta` was used by the older UC Davis version of `dauco_tables.do` and is superseded.
`final2.dta` was an intermediate version used in some exploratory scripts; superseded.
