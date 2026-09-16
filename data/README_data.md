# Data Dictionary and Provenance

This file describes the main analytical datasets used in Hadachek et al. (2026, JPubE).
All datasets are located in `data/derived/` (gitignored; see
[uwmadison.box.com/v/wells-replication-data](https://uwmadison.box.com/v/wells-replication-data)
for download).

**Note on file size:** `dauco_construction_panel.dta`, `domestic_failures_panel.dta`,
`gwdepth_well_panel.dta`, `gwdepth_well_panel_lagged.dta`, and `failures_SB535.dta`
were originally produced with dozens of extra columns carried through from the
`allocations_aggregate_dauco` merge (state/federal/local water-project delivery
detail, administrative geography labels, etc.) that no script in `code/` actually
reads. These files were trimmed to only the columns referenced by the analysis —
cutting total size by roughly 80% — after a full manual audit of every consuming
script. The variable tables below reflect the current, trimmed columns.

---

## 1. `dauco_construction_panel.dta` — DAUCO-Year Panel (Agricultural Wells)

**Produced by:** `code/02_merge/02a_dauco_panel.R` (Stage 3)
**Unit of observation:** DAU-County (DAUCO) × year
**Used by:** `03a_summary_stats.do`, `03b_ag_construction.do`, `04e_allocation_figures.R`

| Variable | Type | Description |
|----------|------|-------------|
| `DAUCO` | str | DAU-County unit identifier |
| `year` | int | Year |
| `construction` | int | New agricultural well permits |
| `d_construction` | float | New agricultural well permits (destructions-adjusted variant) |
| `pct_allocation_ag` | float | Agricultural surface water allocation percentage |
| `pct_allocation_mi` | float | Municipal/industrial surface water allocation percentage |
| `vol_maximum_ag` | float | Maximum contracted water allocation volume, agricultural |
| `vol_maximum_mi` | float | Maximum contracted water allocation volume, municipal/industrial |
| `vol_deliv_cy_ag` | float | Delivered water volume, current year, agricultural |
| `swp_pctallo_ag` | float | State Water Project allocation percentage, agricultural |
| `dauco_area` | float | DAUCO land area |
| `dauco_pctcrop` | float | % of DAUCO area under cultivation |
| `total_acres` | float | Total DAUCO acreage (`dauco_area * 247.105`) |
| `crop_acres` | float | Cultivated acreage within the DAUCO |
| `ag_allocation_acre` | float | Ag surface water allocation per crop acre (AF) |
| `hdd` | float | Harmful degree days (heat stress threshold) |
| `dday8` | float | Degree days above 8°C (used to derive `gdd`) |
| `precip` | float | Annual precipitation (inches) |

Note: `l_ag_allocation_acre`, `ag_deliveries_acre`, `l_ag_deliveries_acre`, and `gdd`
are not stored — they are computed on the fly in `03a_summary_stats.do` /
`03b_ag_construction.do` from the variables above.

---

## 2. `domestic_failures_panel.dta` — Domestic Well Failure Panel

**Produced by:** `code/02_merge/02b_failures_panel.R` (Nov 2023 data freeze; Stage 3)
**Unit of observation:** Well × year
**Used by:** `03a_summary_stats.do`, `03c_domestic_failures.do`, `04c_env_justice.R`,
`04d_descriptive.R`

| Variable | Type | Description |
|----------|------|-------------|
| `id` | str | Coordinate-based geographic ID |
| `dist` | float | Distance to nearest WCR well (999 = never failed) |
| `treat` | int | Well failure indicator (1 = failed) |
| `DAUCO` | str | DAU-County identifier |
| `dau_code`, `psa_code` | str | Administrative water-region identifiers (used in DAUCO-level collapse in `03c`) |
| `county_name`, `county_code` | str/float | County identifiers (used for the SJV subsample filter in `03c`) |
| `year` | int | Year |
| `date` | date | Well failure report date |
| `pump` | float | Pump failure indicator |
| `TotalCompletedDepth3` | float | Well completed depth |
| `DateWorkEnded` | date | Well construction completion date |
| `DateDestruct` | date | Well destruction date |
| `pct_allocation_ag` | float | Agricultural surface water allocation percentage |
| `vol_maximum_ag` | float | Maximum contracted water allocation volume |
| `vol_deliv_cy_ag` | float | Delivered water volume, current year |
| `dauco_area` | float | DAUCO land area |
| `dauco_pctcrop` | float | % of DAUCO area under cultivation |
| `dday8` | float | Degree days above 8°C (used to derive `gdd`) |
| `hdd` | float | Harmful degree days (heat stress threshold) |
| `POP2010` | float | Census tract population (2010) |
| `WhitePop` | int | Census tract white population |
| `pct_white` | float | % white population (census tract) |
| `pct_pov` | float | % below poverty line (census tract) |

Note: `wellid` is generated on the fly in `03c_domestic_failures.do` via
`egen wellid=group(id dist)`; `ag_allocation_acre`, `ag_deliv_acre`, `crop_acres`,
and `gdd` are likewise computed on the fly, not stored in the file.

**Known issue:** `03a_summary_stats.do` and `03c_domestic_failures.do` reference a
column named `failure`, but the file's actual column is `treat` (only
`04c_env_justice.R` renames it via `rename(failure = treat)`). This predates the
column trim and is a pre-existing gap in the pipeline, not something introduced
by removing unused columns — flagging it here since it will surface if 03a/03c
are run against this file as-is.

---

## 3. `gwdepth_well_panel.dta` — Monitoring Well Panel (GW Depth)

**Canonical version.** Produced by `code/02_merge/02c_depth_panel.R` (Stage 3)
**Unit of observation:** Monitoring well × year
**Used by:** `03a_summary_stats.do`, `03d_gw_depth.do`, `04a_maps.R`, `04d_descriptive.R`

| Variable | Type | Description |
|----------|------|-------------|
| `dtw` | float | Depth to water (feet below surface) |
| `year` | int | Year |
| `wellid` | str | Well identifier |
| `DAUCO` | str | DAU-County identifier |
| `pct_allocation_ag` | float | Agricultural surface water allocation percentage |
| `vol_maximum_ag` | float | Maximum contracted water allocation volume |
| `vol_deliv_cy_ag` | float | Delivered water volume, current year |
| `dauco_area` | float | DAUCO land area |
| `dauco_pctcrop` | float | % of DAUCO area under cultivation |
| `hdd` | float | Harmful degree days (heat stress threshold) |
| `precip` | float | Annual precipitation (inches) |
| `dday8` | float | Degree days above 8°C (used to derive `gdd`) |

Note: `diff_depth` (change in depth to water) is computed on the fly in
`03a_summary_stats.do` / `03d_gw_depth.do` from leads/lags of `dtw`, not stored
in the file. Column order matters here: `04d_descriptive.R` selects
`gwdepth_well_panel[, 1:6]` by position (relying on `dtw`, `year`, `wellid`,
`DAUCO` being among the first columns) — do not reorder columns in this file.

### 3a. `gwdepth_well_panel_lagged.dta` — GW Depth Panel with Lagged Weather

**Produced by:** `code/02_merge/02_merge_panels.R` (a newer/expanded version of #3,
adding lagged weather and pre-computed regression weights)
**Unit of observation:** Monitoring well × year
**Used by:** `03d_gw_depth.do` (distributed-lag specifications only)

| Variable | Type | Description |
|----------|------|-------------|
| `wellid` | str | Well identifier |
| `year` | int | Year |
| `DAUCO` | str | DAU-County identifier |
| `diff_depth` | float | Change in depth to water (ft/year) — regression outcome |
| `w` | float | Regression weight (crop acres / number of monitoring wells in the DAUCO) |
| `pct_allocation_ag` | float | Agricultural surface water allocation percentage |
| `vol_maximum_ag` | float | Maximum contracted water allocation volume |
| `vol_deliv_cy_ag` | float | Delivered water volume, current year |
| `dauco_area` | float | DAUCO land area |
| `dauco_pctcrop` | float | % of DAUCO area under cultivation |
| `hdd` | float | Harmful degree days (heat stress threshold) |
| `precip` | float | Annual precipitation (inches) |
| `dday8` | float | Degree days above 8°C (used to derive `gdd`) |

---

## Additional Derived Files

| File | Produced by | Used by | Description |
|------|-------------|---------|-------------|
| `weather_dauco_annual.dta` | `02e_weather_to_dau.R` | `02a`, `02b`, `02c`, `03b`, `03c` | DAUCO × year weather aggregates |
| `gwdepth_raw_obs.dta` | `01a_gw_depth_stata.do` | `02c_depth_panel.R`, `04b_failure_maps.R` | Raw groundwater depth observations (pre-panel) |
| `well_construction.csv` | `01g_clean_wells.R` | `02a`, `04a_maps.R`, `04b_failure_maps.R`, `04d_descriptive.R` | Well completion/construction records (ag + domestic) |
| `allocations_aggregate_dauco.dta` | Provided by N. Hagerty (surface water allocations) | `02b`, `02c`, `04a_maps.R` | DAUCO-level surface water allocation history — left untrimmed since it's a shared external source file, not a derived analysis panel |

### `failures_SB535.dta` — SB535 Disadvantaged-Community Subsample

**Produced by:** `04c_env_justice.R` (spatial join of `domestic_failures_panel.dta`
to SB535 DAC census tracts)
**Used by:** `04c_env_justice.R` only (the script continues using the in-memory
object after writing this file — reload it to redo those regressions)

| Variable | Type | Description |
|----------|------|-------------|
| `id` | str | Coordinate-based geographic ID |
| `year` | int | Year |
| `failure` | float | Well failure indicator (renamed from `treat` on load, unlike `domestic_failures_panel.dta`) |
| `DAUCO` | str | DAU-County identifier |
| `pct_allocation_ag` | float | Agricultural surface water allocation percentage |
| `vol_maximum_ag` | float | Maximum contracted water allocation volume |
| `vol_deliv_cy_ag` | float | Delivered water volume, current year |
| `dauco_area` | float | DAUCO land area |
| `dauco_pctcrop` | float | % of DAUCO area under cultivation |
| `hdd` | float | Harmful degree days (heat stress threshold) |
| `precip` | float | Annual precipitation (inches) |
| `dday8` | float | Degree days above 8°C (used to derive `gdd`) |
| `GEOID` | float | Census tract identifier from the spatial join |
| `SB535_tract` | float | SB535 disadvantaged-community tract indicator (1/0) |

## Files Not Referenced by Current Code

The following files exist in `data/derived/` but are not read by any script in
`code/` as of this package version, so they were left untrimmed. They are
retained in the distribution for provenance but are not required to reproduce
any table or figure:

- `all_wells3.dta` (2.1 GB)
- `all_wells4.dta` (3.0 GB)
- `dtw_long_diff.dta` (7 MB)

