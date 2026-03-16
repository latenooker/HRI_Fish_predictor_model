# External Data

## HRI_all_variables.csv

Oceanographic and bathymetric predictor variables extracted from ArcGIS raster layers using the TNC Bathymetry 10m resolution product for Belize.

This file is **not tracked in git** because it is generated externally. You must obtain or regenerate it before running `code/05_eda_correlation.qmd`.

### How to obtain

Original source file: `HRI_var_10m.csv`

Location: `G:/Shared drives/NSF CoPE internal/GIS_CoPE/GIS_Belize/2_model_inputs_belize/coral_reef_modeling/01_input_csv/HRI_var_10m.csv`

Copy the file to this directory and rename to `HRI_all_variables.csv`.

### Expected schema

- ~267 rows (one per survey site)
- ~20 columns including:
  - `Latitude`, `Longitude` — site coordinates
  - `Coral_cove`, `Algae_cove` — response variables (coral/algae cover)
  - `Commercial`, `Herbivorou` — response variables (fish biomass)
  - `bz_bathy` — bathymetry
  - `slopeslop`, `sloslo_240` — slope metrics
  - `aspect_s_c` — aspect/standard curvature
  - `curv_pro`, `curv_plan` — profile and plan curvature
  - Additional terrain/oceanographic predictors
