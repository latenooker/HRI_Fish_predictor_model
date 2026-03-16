# HRI Fish Predictor Model

Data processing pipeline for coral reef response variables (benthic cover, commercial fish biomass, herbivorous fish biomass) from HRI/AGRRA surveys in Belize. Outputs site-level summaries for use in coral reef abundance prediction models.

## Quick Start

```r
# 1. Clone the repo and open the .Rproj in RStudio
# 2. Install required packages
install.packages(c("tidyverse", "readxl", "here", "gtsummary",
                    "corrplot", "car", "MASS"))

# 3. Run the full pipeline
source("code/run_all.R")
```

## Project Structure

```
HRI_Fish_predictor_model/
├── README.md
├── HRI_AGRRA_BELIZE.Rproj          # RStudio project (anchors here::here())
├── code/
│   ├── 00_functions.R               # Shared helpers (load_belize_data, theme_hri, etc.)
│   ├── 01_ingest_benthic.R          # Benthic cover processing
│   ├── 02_ingest_commercial_fish.R  # Commercial fish biomass
│   ├── 03_ingest_herbivorous_fish.R # Herbivorous fish biomass
│   ├── 04_merge_response_variables.R# Merge + export final CSVs
│   ├── 05_eda_correlation.qmd       # EDA: predictor correlation analysis
│   └── run_all.R                    # Sources 00-04 in order
├── data/
│   ├── raw/                         # Immutable source Excel files
│   ├── external/                    # External dependencies (see data/external/README.md)
│   └── processed/                   # Intermediate cleaned CSVs
├── results/
│   ├── figures/                     # Plots (PNG)
│   └── tables/                      # Final output CSVs
├── docs/
│   ├── data_dictionary.md           # Full variable definitions
│   ├── methods.md                   # AGRRA methodology details
│   └── session_logs/
└── R_workspaces/                    # Gitignored
```

## Pipeline

```
data/raw/*.xlsx
       │
       ├─ 01_ingest_benthic.R ──────────► data/processed/benthic_cover.csv
       ├─ 02_ingest_commercial_fish.R ──► data/processed/commercial_fish_biomass.csv
       ├─ 03_ingest_herbivorous_fish.R ─► data/processed/herbivorous_fish_biomass.csv
       │
       └─ 04_merge_response_variables.R
              │
              ├─► results/tables/ResponseVariables_full.csv   (all sites × years)
              └─► results/tables/ResponseVariables_input.csv  (site-level averages)
```

## Data Sources

- **BenthicCover_2023.xlsx** — HRI 2023 benthic point cover survey results
- **BenthicPointCoverBySite_2011_2021.xlsx** — AGRRA benthic data 2011-2021
- **FishBiomass_2023.xlsx** — HRI 2023 fish biomass survey results
- **FishBiomassBySite_2011_2021.xlsx** — AGRRA fish biomass data 2011-2021
- **HRI_all_variables.csv** (external) — Oceanographic/bathymetric predictors from ArcGIS at 10m resolution. See `data/external/README.md`.

## Output Summary

| File | Rows | Columns | Description |
|------|------|---------|-------------|
| `ResponseVariables_full.csv` | ~870 | 25 | All sites × years with family-level biomass |
| `ResponseVariables_input.csv` | ~291 | 8 | Site-level means across years |

See `docs/data_dictionary.md` for column definitions.

## AGRRA Methodology

See `docs/methods.md` for full details on AGRRA survey protocols, species lists, and biomass calculations.

Reference: [HRI AGRRA Dashboard](https://oref.maps.arcgis.com/apps/dashboards/bdb35a48e40b49a6b12267e38633fd67)
