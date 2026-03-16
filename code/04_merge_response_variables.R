# =============================================================================
# 04_merge_response_variables.R
# Merge benthic cover + commercial fish + herbivorous fish into final outputs
#
# Input:  data/processed/benthic_cover.csv
#         data/processed/commercial_fish_biomass.csv
#         data/processed/herbivorous_fish_biomass.csv
# Output: results/tables/ResponseVariables_full.csv   (all records, all years)
#         results/tables/ResponseVariables_input.csv   (site-level averages)
# =============================================================================

source(here::here("code", "00_functions.R"))

ensure_dirs(c(here("results", "tables"), here("results", "figures")))

# --- Load processed data ------------------------------------------------------
benthic    <- read.csv(here("data", "processed", "benthic_cover.csv"))
commercial <- read.csv(here("data", "processed", "commercial_fish_biomass.csv"))
herbivorous <- read.csv(here("data", "processed", "herbivorous_fish_biomass.csv"))

# --- Merge all response variables ---------------------------------------------
# First merge benthic + commercial, then add herbivorous
ResponseVariables <- merge(
  benthic, commercial,
  by = c("Code", "Name", "Latitude", "Longitude", "YEAR", "Depth", "Reef.Type"),
  all = TRUE
)

ResponseVariables_full <- merge(
  ResponseVariables, herbivorous,
  by = c("Code", "Name", "Latitude", "Longitude", "YEAR", "Depth", "Reef.Type"),
  all = TRUE
)

ResponseVariables_full$YEAR <- as.character(ResponseVariables_full$YEAR)

# Save full dataset (all sites x years, with individual family biomass values)
write.csv(
  ResponseVariables_full,
  here("results", "tables", "ResponseVariables_full.csv"),
  row.names = FALSE
)

# --- Site-level averages across years -----------------------------------------
# Collapse across years to get one row per site with mean response values
ResponseVariables_avg <- ResponseVariables_full %>%
  group_by(Name, Latitude, Longitude, Reef.Type) %>%
  summarize(
    tCommBiomass_avg   = mean(tCommBiomass, na.rm = TRUE),
    tHerbiBiomass_avg  = mean(tHerbiBiomass, na.rm = TRUE),
    tCORALavg_avg      = mean(tCORALavg, na.rm = TRUE),
    tFMAavg_avg        = mean(tFMAavg, na.rm = TRUE),
    .groups = "drop"
  )

write.csv(
  ResponseVariables_avg,
  here("results", "tables", "ResponseVariables_input.csv"),
  row.names = FALSE
)

# --- Quick dispersion plots ---------------------------------------------------
ResponseVariables_input <- read.csv(
  here("results", "tables", "ResponseVariables_input.csv")
)

p1 <- ggplot(ResponseVariables_input, aes(x = tCommBiomass_avg, y = tCORALavg_avg)) +
  geom_point() +
  labs(x = "Commercial fish abundance", y = "Coral cover") +
  theme_hri()

p2 <- ggplot(ResponseVariables_input, aes(x = tHerbiBiomass_avg, y = tFMAavg_avg)) +
  geom_point() +
  labs(x = "Herbivorous fish abundance", y = "Fleshy Algae cover") +
  theme_hri()

ggsave(here("results", "figures", "scatter_comm_coral.png"), p1,
       width = 6, height = 5, dpi = 300)
ggsave(here("results", "figures", "scatter_herbi_algae.png"), p2,
       width = 6, height = 5, dpi = 300)

message("04_merge_response_variables.R complete")
message("  -> results/tables/ResponseVariables_full.csv")
message("  -> results/tables/ResponseVariables_input.csv")
