"""
01b_gw_depth_python.py
Purpose: GIS raster interpolation of groundwater depth (DTW) measurements.
         Consolidates dtw_csv2shp.py, dtw_interp.py, dtw_ras2asc.py.

STATUS: NOT REPRODUCIBLE
  This script requires ArcGIS Desktop + Python 2.7 with ArcPy, which are
  no longer available. The derived GIS outputs (ASCII grid files used by
  the Stata cleaning scripts) are provided in:
    data/derived/gis/groundwater_depth/asc_years_balanced/

  Replicators should use the provided derived outputs and skip this step.
  Do not attempt to run this script.

ORIGINAL REQUIREMENTS (for documentation purposes):
  - ArcGIS Desktop (version [X.X])
  - Python 2.7 with ArcPy (bundled with ArcGIS Desktop)
  - Spatial Analyst extension

Inputs:  data/derived/gis/groundwater_depth/gwdepth_[year].csv
         (produced by 01a_gw_depth_stata.do)

Outputs: data/derived/gis/groundwater_depth/shp_years_balanced/  (shapefiles)
         data/derived/gis/groundwater_depth/ras_years_balanced/   (rasters)
         data/derived/gis/groundwater_depth/asc_years_balanced/   (ASCII grids)
         (ASCII grids consumed by 01a Stage 2 / prepare_dtw2.do)

PHASE 2 TODO: Paste and fix paths from:
  - dtw_csv2shp.py: replace H:/analysis/drought/gis/ with os.path-relative paths
  - dtw_interp.py:  same path fix; note Python 2 xrange → range for Python 3
  - dtw_ras2asc.py: same
  Port from Python 2 to Python 3 if ArcGIS Pro (3.x) is available.

Date:    2026-03-03
"""

# -- PLACEHOLDER: to be filled in Phase 2 --
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
GIS_GWDEPTH = os.path.join(ROOT, 'data', 'derived', 'gis', 'groundwater_depth')

print("ROOT:", ROOT)
print("GIS output dir:", GIS_GWDEPTH)
print("NOTE: ArcPy scripts not yet ported. See Phase 2 TODO above.")
