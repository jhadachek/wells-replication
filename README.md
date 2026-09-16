# Replication Package: Hadachek et al. — Externalities of Climate Adaptation in Common-Pool Groundwater Resources

**Paper:** Externalities of climate adaptation in common-pool groundwater resources
**Authors:** Jeffrey Hadachek, Ellen M. Bruno, Nick Hagerty, Katrina Jessoe
**Journal:** Journal of Public Economics
**DOI:** https://doi.org/10.1016/j.jpubeco.2026.105602
**Replication package version:** 1.0 (2026-03-03)

---

## Overview

This package replicates all tables and figures in Hadachek et al. (2026, JPubE).
The paper studies the externalities of climate adaptation in California's Central
Valley: as heat and drought intensify, farmers extract more groundwater, lowering
the water table and reducing drinking-water access for domestic well users.

**Main findings:**
- Surface water scarcity (0.7 AF/acre, 2021 drought level) causes groundwater to
  fall 2 ft more over 3 years — a 19% larger decline than baseline.
- Heat (23 HDD, 2021 level) causes an additional 0.7 ft groundwater decline.
- Well failure probability rises 3.9 pp (surface water shock) and 4.4 pp (heat),
  with effects concentrated in low-income and Latino communities.
- The 2021 drought curtailments induced 321 additional agricultural wells (+32%).
- 25% of the surface water effect on groundwater operates through new well construction.
- Potential damages: $30.4M (surface water) and $34.3M (heat) at $10,000/well
  replacement cost.

---

## Section 1: Data Availability and Provenance

### 1.1 Summary of Data Availability

| Dataset | Source | Availability | In Package? |
|---------|--------|-------------|-------------|
| CA Well Completion Reports | CA DWR (public) | Free download | No — 370MB |
| GAMA Groundwater Data | SWRCB (public) | Free download | No |
| CNRA Periodic Water Levels | CNRA (public) | Free download | No |
| Schlenker Weather Data | Wolfram Schlenker | Request from author | No |
| Surface Water Allocations | Nick Hagerty | Request from authors | No |
| SB535 DAC Tracts | OEHHA (public) | Free download | No |
| NHGIS Census Data | NHGIS (registration required) | Free w/ registration | No |
| Farmgrid Crosswalk | Nick Hagerty | Request from authors | No |
| CA DWR Water Balance | CA DWR (public) | Free download | No |
| **Derived analysis datasets** | Produced by this code | [Download](https://uwmadison.box.com/v/wells-replication-data) | `data/derived/` |

See `data/raw/README_raw.md` for detailed access instructions for each raw dataset.

### 1.2 Statement on Data Rights

- CA DWR, SWRCB, CNRA data: public domain / open data license
- NHGIS data: free for research use under IPUMS terms of service
- Schlenker weather data: academic use; obtain directly from Wolfram Schlenker
  (Columbia University)
- Surface water allocations and farmgrid crosswalk: available from authors upon request

---

## Section 2: Computational Requirements

### Software

| Software | Version | Purpose |
|----------|---------|---------|
| Stata | 18.0 (tested) | Cleaning, merging, estimation, tables |
| R | 4.3+ | Figures, some cleaning/merging |

### Stata Packages

Install via `do code/install_packages.do` (or uncomment in `00_run_all.do`):

| Package | Purpose |
|---------|---------|
| `reghdfe` | High-dimensional FE estimation |
| `ivreghdfe` | IV with high-dimensional FEs |
| `ivreg2` | IV estimation |
| `ranktest` | Weak instrument tests |
| `ppmlhdfe` | Poisson pseudo-ML with FEs |
| `ftools` | Fast Stata utilities (required by reghdfe) |
| `xtivreg2` | Panel IV (used in some specifications) |
| `estout` | Table export to LaTeX |

### R Packages

Install via `Rscript code/install_packages.R`:

| Package | Purpose |
|---------|---------|
| `haven` | Read/write Stata .dta files |
| `dplyr`, `tidyr`, `readr` | Data manipulation |
| `ggplot2`, `ggpubr` | Figures |
| `sf`, `tigris`, `tmap` | Spatial data and maps |
| `fixest` | Estimation (R equivalent of reghdfe) |
| `here` | Relative path management |
| `readxl` | Read Excel files |
| `nngeo` | Nearest-neighbor spatial joins |
| `pacman` | Package management |
| `lubridate` | Date handling |
| `latex2exp` | LaTeX expressions in plots |
| `hrbrthemes` | Plot themes |

### Hardware and Runtime

| Stage | Approx. runtime | RAM required |
|-------|----------------|-------------|
| Stage 1: Clean (Stata) | Several hours | 8+ GB |
| Stage 2: Merge (R) | < 30 minutes | 4 GB |
| **Stage 3: Analysis (Stata)** | **< 1 hour** | **4 GB** |
| Stage 4: Figures (R) | < 30 minutes | 4 GB |

---

## Section 3: Description of Programs

```
code/
├── config.do              Set all Stata path globals (uses c(pwd) — no hardcoding)
├── config.R               Set all R path variables (uses here::here())
├── install_packages.do    Install required Stata packages (run once)
├── install_packages.R     Install required R packages (run once)
├── 00_run_all.do          Master runner: sources config.do, runs all stages
│
├── 01_clean/              Stage 1: Raw data cleaning
│   ├── 01a_gw_depth_stata.do    GW depth: merge GAMA + CNRA periodic level measurements
│   ├── 01e_weather.do           Weather: degree days + long-term climate
│   └── 01f_well_completions.R   WCR: permit-to-construction timing figure
│
├── 02_merge/              Stage 2: Panel construction
│   └── 02_merge_panels.R        Build main analysis panels
│
├── 03_analysis/           Stage 3: Estimation + tables
│   ├── 03a_summary_stats.do     → output/tables/summarystats.tex
│   ├── 03b_ag_construction.do   → output/tables/fs.tex, regs1.tex, regs1a.tex,
│   │                                           construct_lag.tex
│   ├── 03c_domestic_failures.do → output/tables/failures.tex, failures_sjv.tex,
│   │                                           failure_lag.tex, hdd_nonwhite.tex,
│   │                                           hdd_lowincome.tex
│   ├── 03d_gw_depth.do          → output/tables/wells_adjweight2.tex, wells.tex,
│   │                                           gwdepth_lag.tex
│   ├── 03e_long_diff.do         → output/tables/long_diff1.tex
│   └── 03f_bootstrap.do         Bootstrap utility (called by 03b)
│
└── 04_figures/            Stage 4: Figures
    ├── 04a_maps.R               → output/figures/ag_sw_cross.png,
    │                                           ag_wells_cross2.png
    ├── 04b_failure_maps.R       → output/figures/fresno_pws.png, sjv_density.png,
    │                                           cal_hisp.png, cal_pov.png,
    │                                           cal_failures.png
    ├── 04c_env_justice.R        → data/derived/failures_SB535.dta
    │                              (intermediate dataset; no figure output)
    └── 04d_descriptive.R        → output/figures/domestic_map.png, dtw_map.png,
                                               raw_dtw_measurements.png,
                                               nn_hist.png, buffer_hist.png,
                                               ttest_failure_prob.png,
                                               ttest_well_depth.png,
                                               diff_trends_raw.png,
                                               diff_trends_diff.png,
                                               diff_trends_fe.png
```

---

## Section 4: Instructions to Replicators

### Standard replication (Stages 3–4) — for all replicators

Derived intermediate datasets are provided in `data/derived/` (see Section 1),
so all replicators can start at Stage 3.

1. Download the derived data from
   [uwmadison.box.com/v/wells-replication-data](https://uwmadison.box.com/v/wells-replication-data)
   and place the contents in `data/derived/`
2. Install Stata packages (first run only):
   ```stata
   do code/install_packages.do
   ```
3. Install R packages (first run only):
   ```bash
   Rscript code/install_packages.R
   ```
4. Run the replication from the `replication/` directory:
   ```bash
   cd /path/to/replication
   stata -b do code/00_run_all.do
   Rscript code/04_figures/04a_maps.R
   Rscript code/04_figures/04b_failure_maps.R
   Rscript code/04_figures/04d_descriptive.R
   ```
   Stages 1–2 are commented out by default; Stages 3–4 run automatically.

### Optional: Re-run data cleaning (Stages 1–2)

If you wish to re-run the Stata cleaning scripts (Stage 1) or the R merge
pipeline (Stage 2) from raw data, obtain the raw data per `data/raw/README_raw.md`,
then uncomment the relevant blocks in `00_run_all.do`.

### Expected output

After running Stages 3–4, the following files should appear:

**Tables** (`output/tables/`):
- `summarystats.tex`
- `fs.tex`, `regs1.tex`, `regs1a.tex`, `construct_lag.tex`
- `failures.tex`, `failures_sjv.tex`, `failure_lag.tex`
- `hdd_nonwhite.tex`, `hdd_lowincome.tex`
- `wells.tex`, `wells_adjweight2.tex`, `gwdepth_lag.tex`
- `long_diff1.tex`

**Figures** (`output/figures/`):
- `ag_sw_cross.png`
- `ag_wells_cross2.png`
- `fresno_pws.png`, `sjv_density.png`
- `cal_hisp.png`, `cal_pov.png`, `cal_failures.png`
- `domestic_map.png`, `dtw_map.png`
- `raw_dtw_measurements.png`
- `nn_hist.png`, `buffer_hist.png`
- `ttest_failure_prob.png`, `ttest_well_depth.png`
- `diff_trends_raw.png`, `diff_trends_diff.png`, `diff_trends_fe.png`
- `permit_to_construction.png` (from `01f_well_completions.R`)

---

## Section 5: Table and Figure Correspondence

### Main-Body Tables

| Paper element | Script | Output file |
|---------------|--------|-------------|
| Table 1: Summary Statistics | `03a_summary_stats.do` | `output/tables/summarystats.tex` |
| Table 2: Changes in Depth to the Groundwater | `03d_gw_depth.do` | `output/tables/wells_adjweight2.tex` |
| Table 3: Linear Probability of Reported Well Failure | `03c_domestic_failures.do` | `output/tables/failures.tex` |
| Table 4: Construction of New Agricultural Wells: IV and CF | `03b_ag_construction.do` | `output/tables/regs1a.tex` |

### Appendix Tables

| Paper element | Script | Output file |
|---------------|--------|-------------|
| Table A1: Calculating the Margins of Response | [Analytical; see paper] | [Calculated in paper text] |
| Table A2: Agricultural SW Deliveries: First-Stage Results | `03b_ag_construction.do` | `output/tables/fs.tex` |
| Table A3: New Constructed Well Depth | `03b_ag_construction.do` | `output/tables/regs1.tex` |
| Table A4: Destruction of Agricultural Wells: Reduced-Form | `03b_ag_construction.do` | `output/tables/regs1.tex` |
| Table A5: Construction of New Agricultural Wells: Reduced-Form | `03b_ag_construction.do` | `output/tables/regs1.tex` |
| Table A6: Changes in Depth to the Groundwater: Distributed Lag | `03d_gw_depth.do` | `output/tables/gwdepth_lag.tex` |
| Table A7: Construction of New Agricultural Wells: Distributed Lag | `03b_ag_construction.do` | `output/tables/construct_lag.tex` |
| Table A8: Parameter Values for Decomposition Exercise | [Analytical; see paper] | [Calculated in paper text] |
| Table A9: Domestic Well Drilling: Long Differences | `03e_long_diff.do` | `output/tables/long_diff1.tex` |
| Appendix: Failure Distributed Lag | `03c_domestic_failures.do` | `output/tables/failure_lag.tex` |
| Appendix: Demographic Heterogeneity (Non-White) | `03c_domestic_failures.do` | `output/tables/hdd_nonwhite.tex` |
| Appendix: Demographic Heterogeneity (Low-Income) | `03c_domestic_failures.do` | `output/tables/hdd_lowincome.tex` |
| Appendix: SJV Subsample Failures | `03c_domestic_failures.do` | `output/tables/failures_sjv.tex` |
| Appendix: GW Depth (Unadjusted Weights) | `03d_gw_depth.do` | `output/tables/wells.tex` |

### Main-Body Figures

| Paper element | Script | Output file |
|---------------|--------|-------------|
| Figure 1: Domestic Well Depth and Failure Probability by Local Demographics | `04d_descriptive.R` | `ttest_failure_prob.png`, `ttest_well_depth.png` |
| Figure 2: Agricultural Surface Water Allocation Percentages | `04a_maps.R` | `ag_sw_cross.png` |
| Figure 3: Annual Changes in Depth to the Water Table | `04d_descriptive.R` | `dtw_map.png` |
| Figure 4: New Agricultural Well Construction | `04a_maps.R` | `ag_wells_cross2.png` |
| Figure 5: Cumulative IRF — Surface Water Shocks on ΔDTW | `03d_gw_depth.do` | [see script for graph output] |
| Figure 6: Decomposing ATE by Local Demographics | `03c_domestic_failures.do` | [see script for graph output] |
| Figure 7: Cumulative IRF — Surface Water Shocks on Well Construction | `03b_ag_construction.do` | [see script for graph output] |

### Appendix Figures

| Paper element | Script | Output file |
|---------------|--------|-------------|
| Figure A1: Location of Domestic Wells | `04d_descriptive.R` | `domestic_map.png` |
| Figure A2: Population Demographics in California | `04b_failure_maps.R` | `cal_hisp.png`, `cal_pov.png` |
| Figure A3: Maximum Contracted Surface Water Volumes by DAUCO | `04a_maps.R` | [see script] |
| Figure A4: Temporal Variation in Allocation Percentages by Water Project Divisions | `04a_maps.R` | [see script] |
| Figure A5: Location of Monitoring Wells in CA Groundwater Basins | `04b_failure_maps.R` | [not saved to file — interactive] |
| Figure A6: Locations of Reported Well Failures, 2014–2020 | `04b_failure_maps.R` | `cal_failures.png` |
| Figure A7: Histogram of Annual Ag Well Construction per DAUCO | `04a_maps.R` | [see script] |
| Figure A8: Depth of Drilled Wells Over Time | `01f_well_completions.R` | `permit_to_construction.png` |
| Figure A9: Cumulative IRF — HDD Shocks on ΔDTW | `03d_gw_depth.do` | [see script for graph output] |
| Figure A10: Cumulative IRF — HDD Shocks on Well Construction | `03b_ag_construction.do` | [see script for graph output] |
| Appendix: Parallel Trends Simulation | `04d_descriptive.R` | `diff_trends_raw.png`, `diff_trends_diff.png`, `diff_trends_fe.png` |
| Appendix: Measurement Timing Histogram | `04d_descriptive.R` | `raw_dtw_measurements.png` |
| Appendix: Distance to Agricultural Wells | `04d_descriptive.R` | `nn_hist.png`, `buffer_hist.png` |
| Appendix: Fresno Area PWS vs Well Failures | `04b_failure_maps.R` | `fresno_pws.png` |
| Appendix: SJV Population Density and Demographics | `04b_failure_maps.R` | `sjv_density.png` |

---

## Contact

Jeffrey Hadachek
Department of Agricultural and Applied Economics, UW-Madison
jhadachek@wisc.edu
