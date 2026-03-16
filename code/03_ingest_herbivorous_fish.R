# =============================================================================
# 03_ingest_herbivorous_fish.R
# Process herbivorous fish biomass from AGRRA surveys
#
# Herbivorous families: Acanthuridae/ACAN (surgeonfish), Scaridae/SCAR (parrotfish)
# Biomass units: grams per 100m2
#
# BUG FIXES from original Data_base_construction.R:
#   1. Rename mapping corrected: PARR (parrotfish) -> tSCAR, SURG (surgeonfish) -> tACAN
#      Original had these swapped, mislabeling all pre-2023 data.
#   2. tHerbiBiomass formula: now uses tACANavg + tSCARavg (was tACANavg + tSCARstd)
#
# Input:  data/raw/FishBiomass_2023.xlsx
#         data/raw/FishBiomassBySite_2011_2021.xlsx
# Output: data/processed/herbivorous_fish_biomass.csv
# =============================================================================

source(here::here("code", "00_functions.R"))

ensure_dirs(c(
  here("data", "processed"),
  here("results", "figures")
))

# --- 2023 herbivorous fish data -----------------------------------------------
Biomass_fish_2023 <- read_excel(
  here("data", "raw", "FishBiomass_2023.xlsx"),
  sheet = "Overall"
)

Herbi_fish_2023 <- Biomass_fish_2023 %>%
  select(
    Code, Name, Latitude, Longitude, "Reef Type",
    tACANavg, tACANstd,   # surgeonfish (Acanthuridae)
    tSCARavg, tSCARstd    # parrotfish (Scaridae)
  ) %>%
  mutate(
    YEAR = 2023,
    # FIX: was tACANavg + tSCARstd (mixing mean and SD)
    tHerbiBiomass = tACANavg + tSCARavg
  )

# --- 2011-2021 herbivorous fish data -----------------------------------------
# FIX: Rename mapping corrected.
#   PARR = Parrotfish = Scaridae -> tSCAR (original incorrectly mapped to tACAN)
#   SURG = Surgeonfish = Acanthuridae -> tACAN (original incorrectly mapped to tSCAR)
Herbi_fish_2018_2021_BZ <- load_belize_data(
  path  = here("data", "raw", "FishBiomassBySite_2011_2021.xlsx"),
  sheet = "Data",
  cols  = c("Batch", "Code", "Site", "Date", "Latitude", "Longitude",
            "Depth", "PARRavg", "PARRstd", "SURGavg", "SURGstd"),
  years = c(2018, 2021)
) %>%
  rename(
    Name     = Site,
    tSCARavg = PARRavg, tSCARstd = PARRstd,   # parrotfish -> Scaridae
    tACANavg = SURGavg, tACANstd = SURGstd     # surgeonfish -> Acanthuridae
  ) %>%
  # FIX: was tACANavg + tSCARstd
  mutate(tHerbiBiomass = tACANavg + tSCARavg)

# --- Merge 2023 + 2018/2021 --------------------------------------------------
Herbivorous_fish_Biomass <- merge(
  Herbi_fish_2023, Herbi_fish_2018_2021_BZ,
  by = c("Code", "Name", "Latitude", "Longitude",
         "tACANavg", "tACANstd", "tSCARavg", "tSCARstd",
         "YEAR", "tHerbiBiomass"),
  all = TRUE
)

# --- Exploratory plot: herbivorous biomass trend ------------------------------
avg_herbi_biomass <- Herbivorous_fish_Biomass %>%
  group_by(YEAR) %>%
  summarise(avg_biomass = mean(tHerbiBiomass), n = n())

p_herbi <- ggplot(avg_herbi_biomass, aes(x = YEAR, y = avg_biomass, group = 1)) +
  geom_line(color = "#2C3E50", linewidth = 1.2) +
  geom_point(color = "#2C3E50", size = 3, shape = 21, fill = "white", stroke = 1.2) +
  labs(
    title = "Trend of Herbivorous Fish Biomass Over Time",
    subtitle = "Measured in 100m2 sampling areas",
    x = "Year", y = "Average Biomass (g/100m2)"
  ) +
  theme_hri()

ggsave(here("results", "figures", "herbivorous_fish_trend.png"), p_herbi,
       width = 8, height = 6, dpi = 300)

# --- Combined commercial + herbivorous trend plot ----------------------------
# Load commercial averages for comparison (requires script 02 to have run)
comm_csv <- here("data", "processed", "commercial_fish_biomass.csv")
if (file.exists(comm_csv)) {
  Commercial_fish_Biomass <- read.csv(comm_csv)

  avg_Commercial_biomass <- Commercial_fish_Biomass %>%
    group_by(YEAR) %>%
    summarise(avg_biomass = mean(tCommBiomass), n = n()) %>%
    mutate(category = "Target Species")

  combined_data <- rbind(
    avg_Commercial_biomass,
    avg_herbi_biomass %>% mutate(category = "Herbivorous Fish")
  )

  # FIX: original used avg_cover (nonexistent column); correct column is avg_biomass
  p_combined <- ggplot(combined_data,
                       aes(x = YEAR, y = avg_biomass, group = category, color = category)) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 3, shape = 21, fill = "white", stroke = 1.2) +
    scale_color_manual(values = c("Target Species" = "#2C3E50",
                                  "Herbivorous Fish" = "#E74C3C")) +
    labs(
      title = "Trends in Biomass Over Time",
      subtitle = "Measured in 100m2 sampling areas",
      x = "Year", y = "Average Biomass (g/100m2)", color = "Fish Type"
    ) +
    theme_hri()

  ggsave(here("results", "figures", "fish_biomass_combined.png"), p_combined,
         width = 8, height = 6, dpi = 300)
}

# --- Save processed output ----------------------------------------------------
write.csv(
  Herbivorous_fish_Biomass,
  here("data", "processed", "herbivorous_fish_biomass.csv"),
  row.names = FALSE
)

message("03_ingest_herbivorous_fish.R complete: data/processed/herbivorous_fish_biomass.csv")
