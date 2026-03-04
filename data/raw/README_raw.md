# Raw Data: Access Instructions

This file describes how to obtain each raw data file used in Wells et al.
Place files in the locations shown before running Stage 1 (`01_clean/`).

**Note:** Most replicators can skip Stage 1 entirely and use the derived data
provided in `data/derived/`. See `README.md` Section 4 for instructions.

---

## 1. CA Well Completion Reports (WCR)

| Item | Detail |
|------|--------|
| **File** | `wellcompletionreports.csv` (~370MB) |
| **Source** | CA Department of Water Resources |
| **URL** | https://data.cnra.ca.gov/dataset/well-completion-reports |
| **Access** | Free public download |
| **License** | Open Data Commons Attribution License |
| **Notes** | Download the most recent export; paper uses data through [year]. |

---

## 2. GAMA Groundwater Data

| Item | Detail |
|------|--------|
| **Files** | `swrcb_groundwater/gama_all_dtw_elev.txt` + chemistry files |
| **Source** | CA State Water Resources Control Board — GAMA Groundwater Portal |
| **URL** | https://geotracker.waterboards.ca.gov/gama |
| **Access** | Free public download |
| **Notes** | Download "Periodic Groundwater Level Measurements" and "Water Quality Results" |

---

## 3. CNRA Periodic Water Levels

| Item | Detail |
|------|--------|
| **Files** | `cnra/measurements.csv`, `cnra/stations.csv` |
| **Source** | CA Natural Resources Agency |
| **URL** | https://data.cnra.ca.gov/dataset/periodic-groundwater-level-measurements |
| **Access** | Free public download |

---

## 4. Schlenker Weather Data

| Item | Detail |
|------|--------|
| **Files** | `weather_schlenker/` (gridded daily temperature + precipitation) |
| **Source** | Wolfram Schlenker, Columbia University |
| **Access** | Request from corresponding author or Wolfram Schlenker directly |
| **Notes** | Widely used in agricultural economics. Used for degree-day computation. |

---

## 5. Surface Water Allocations (from Nick Hagerty)

| Item | Detail |
|------|--------|
| **Files** | `surface_water/` (~30 Stata .dta files) |
| **Source** | Prepared dataset from Nicholas Hagerty (co-author) |
| **Access** | Available from corresponding author upon request |
| **License** | Research use |
| **Notes** | Includes water district allocations and deliveries at DAU-county level |

---

## 6. SB535 DAC Tracts

| Item | Detail |
|------|--------|
| **File** | `SB535DACresultsdatadictionary_F_2022.xlsx` (~1.9MB) |
| **Source** | CA Office of Environmental Health Hazard Assessment (OEHHA) |
| **URL** | https://oehha.ca.gov/calenviroscreen/sb535 |
| **Access** | Free public download |

---

## 7. NHGIS Census Data

| Item | Detail |
|------|--------|
| **File** | `nhgis0006_ds249_20205_tract.csv` |
| **Source** | NHGIS (National Historical GIS), IPUMS |
| **URL** | https://nhgis.org |
| **Access** | Requires free registration |
| **Notes** | 2020 5-year ACS tract-level data (race, income, poverty) |

---

## 8. GIS Shapefiles

| Item | Detail |
|------|--------|
| **Files** | `gis/B118/`, `gis/CA_counties/`, `gis/DAU/`, `gis/GSA/`, `gis/PWS/` |
| **Source** | CA DWR (B118 groundwater basins), CA Census (counties), CA DWR (DAU) |
| **Access** | Free public download from respective agencies |
| **Notes** | B118 — https://data.cnra.ca.gov/dataset/b118-california-groundwater-basins |

---

## 9. Farmgrid Crosswalk

| Item | Detail |
|------|--------|
| **Files** | Farmgrid-to-DAU spatial crosswalk (Stata .dta) |
| **Source** | Prepared by Nicholas Hagerty |
| **Access** | Available from corresponding author |
