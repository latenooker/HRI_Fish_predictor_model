# =============================================================================
# 02_ingest_commercial_fish.R
# Process commercial fish biomass from AGRRA surveys
#
# Commercial families: Lutjanidae (LUTJ), Serranidae (SERR), Carangidae (CARA),
#                      Sphyraenidae (SPHY), Haemulidae (HAEM)
# Biomass units: grams per 100m2
#
# Input:  data/raw/FishBiomass_2023.xlsx
#         data/raw/FishBiomassBySite_2011_2021.xlsx
# Output: data/processed/commercial_fish_biomass.csv
# =============================================================================

source(here::here("code", "00_functions.R"))

ensure_dirs(c(
  here("data", "processed"),
  here("results", "figures")
))

# --- 2023 commercial fish data ------------------------------------------------
Biomass_fish_2023 <- read_excel(
  here("data", "raw", "FishBiomass_2023.xlsx"),
  sheet = "Overall"
)

Commercial_fish_2023 <- Biomass_fish_2023 %>%
  select(
    Code, Name, Latitude, Longitude, "Reef Type",
    tLUTJavg, tLUTJstd,   # snappers
    tSERRavg, tSERRstd,   # groupers
    tCARAavg, tCARAstd,   # jacks
    tSPHYavg, tSPHYstd,   # barracuda
    tHAEMavg, tHAEMstd    # grunts
  ) %>%
  mutate(
    YEAR = 2023,
    tCommBiomass = tLUTJavg + tSERRavg + tCARAavg + tSPHYavg + tHAEMavg
  )

# --- 2011-2021 commercial fish data ------------------------------------------
# Column mapping: old names -> AGRRA family codes
Comm_fish_2018_2021_BZ <- load_belize_data(
  path  = here("data", "raw", "FishBiomassBySite_2011_2021.xlsx"),
  sheet = "Data",
  cols  = c("Batch", "Code", "Site", "Date", "Latitude", "Longitude",
            "Depth", "SNAPavg", "SNAPstd", "GROUavg", "GROUstd",
            "JACKavg", "JACKstd", "BARRavg", "BARRstd", "GRUNavg", "GRUNstd"),
  years = c(2018, 2021)
) %>%
  rename(
    Name     = Site,
    tLUTJavg = SNAPavg, tLUTJstd = SNAPstd,   # snappers
    tSERRavg = GROUavg, tSERRstd = GROUstd,   # groupers
    tCARAavg = JACKavg, tCARAstd = JACKstd,   # jacks
    tSPHYavg = BARRavg, tSPHYstd = BARRstd,   # barracuda
    tHAEMavg = GRUNavg, tHAEMstd = GRUNstd    # grunts
  ) %>%
  mutate(tCommBiomass = tLUTJavg + tSERRavg + tCARAavg + tSPHYavg + tHAEMavg)

# --- Merge 2023 + 2018/2021 --------------------------------------------------
Commercial_fish_Biomass <- merge(
  Commercial_fish_2023, Comm_fish_2018_2021_BZ,
  by = c("Code", "Name", "Latitude", "Longitude",
         "tLUTJavg", "tLUTJstd", "tSERRavg", "tSERRstd",
         "tCARAavg", "tCARAstd", "tSPHYavg", "tSPHYstd",
         "tHAEMavg", "tHAEMstd", "YEAR", "tCommBiomass"),
  all = TRUE
)

# --- Exploratory plot: commercial biomass trend -------------------------------
avg_Commercial_biomass <- Commercial_fish_Biomass %>%
  group_by(YEAR) %>%
  summarise(avg_biomass = mean(tCommBiomass), n = n())

p_comm <- ggplot(avg_Commercial_biomass, aes(x = YEAR, y = avg_biomass, group = 1)) +
  geom_line(color = "#2C3E50", linewidth = 1.2) +
  geom_point(color = "#2C3E50", size = 3, shape = 21, fill = "white", stroke = 1.2) +
  labs(
    title = "Trend of Average Biomass of Target Species Over Time",
    subtitle = "Measured in 100m2 sampling areas",
    x = "Year", y = "Average Biomass (g/100m2)"
  ) +
  theme_hri()

ggsave(here("results", "figures", "commercial_fish_trend.png"), p_comm,
       width = 8, height = 6, dpi = 300)

# --- Save processed output ----------------------------------------------------
write.csv(
  Commercial_fish_Biomass,
  here("data", "processed", "commercial_fish_biomass.csv"),
  row.names = FALSE
)

message("02_ingest_commercial_fish.R complete: data/processed/commercial_fish_biomass.csv")
