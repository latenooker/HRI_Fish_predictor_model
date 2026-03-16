# =============================================================================
# run_all.R
# Master script — sources the full data processing pipeline in order
#
# Required packages:
#   tidyverse, readxl, here, gtsummary, corrplot, car, MASS
#
# Usage:
#   source("code/run_all.R")
#   — or —
#   Rscript code/run_all.R     (from project root)
# =============================================================================

library(here)

message("=== HRI AGRRA Belize Data Pipeline ===")
message("Working directory: ", here())

source(here("code", "00_functions.R"))
source(here("code", "01_ingest_benthic.R"))
source(here("code", "02_ingest_commercial_fish.R"))
source(here("code", "03_ingest_herbivorous_fish.R"))
source(here("code", "04_merge_response_variables.R"))

message("=== Pipeline complete ===")
message("Outputs:")
message("  data/processed/benthic_cover.csv")
message("  data/processed/commercial_fish_biomass.csv")
message("  data/processed/herbivorous_fish_biomass.csv")
message("  results/tables/ResponseVariables_full.csv")
message("  results/tables/ResponseVariables_input.csv")
