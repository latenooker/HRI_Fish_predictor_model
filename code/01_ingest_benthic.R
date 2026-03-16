# =============================================================================
# 01_ingest_benthic.R
# Process benthic cover data (coral + fleshy macroalgae) from AGRRA surveys
#
# Input:  data/raw/BenthicCover_2023.xlsx
#         data/raw/BenthicPointCoverBySite_2011_2021.xlsx
# Output: data/processed/benthic_cover.csv
# =============================================================================

source(here::here("code", "00_functions.R"))

ensure_dirs(c(
  here("data", "processed"),
  here("results", "figures")
))

# --- 2023 benthic data -------------------------------------------------------
# Load the "Overall" sheet which has site-level summaries
BenthicCover <- read_excel(
  here("data", "raw", "BenthicCover_2023.xlsx"),
  sheet = "Overall"
)

# Select relevant columns: site identifiers + coral and macroalgae cover
BenthicCover_2023 <- BenthicCover %>%
  select(
    Code,        # survey code
    Name,        # reef/site name
    Latitude,
    Longitude,
    "Reef Type", # reef morphology classification
    tCORALavg,   # coral cover mean (proportion in 2023 data)
    tCORALstd,   # coral cover SD
    tFMAavg,     # fleshy macroalgae cover mean
    tFMAstd      # fleshy macroalgae cover SD
  ) %>%
  mutate(YEAR = 2023)

# 2023 values are proportions (0-1); convert to percentages for consistency
# with 2011-2021 data which is already in percent
BenthicCover_2023 <- BenthicCover_2023 %>%
  mutate(
    tCORALavg = tCORALavg * 100,
    tCORALstd = tCORALstd * 100,
    tFMAavg   = tFMAavg * 100,
    tFMAstd   = tFMAstd * 100
  )

# --- 2011-2021 benthic data ---------------------------------------------------
# Use shared loader: select columns, filter to Belize 2018+2021
BenthicCover_filter_2018_2021 <- load_belize_data(
  path  = here("data", "raw", "BenthicPointCoverBySite_2011_2021.xlsx"),
  sheet = "Data",
  cols  = c("Batch", "Code", "Site", "Date", "Latitude", "Longitude",
            "Depth", "LCavg", "LCstd", "FMAavg", "FMAstd"),
  years = c(2018, 2021)
) %>%
  # Rename to match 2023 column names
  rename(
    Name      = Site,
    tCORALavg = LCavg,
    tCORALstd = LCstd,
    tFMAavg   = FMAavg,
    tFMAstd   = FMAstd
  )

# --- Merge 2023 + 2018/2021 --------------------------------------------------
Belize_BenthicCover_2018_2023 <- merge(
  BenthicCover_2023, BenthicCover_filter_2018_2021,
  by = c("Code", "Name", "Latitude", "Longitude",
         "tCORALavg", "tCORALstd", "tFMAavg", "tFMAstd", "YEAR"),
  all = TRUE
)

# --- Exploratory plots --------------------------------------------------------
# Box plot: coral vs macroalgae cover across years
data_long <- Belize_BenthicCover_2018_2023 %>%
  pivot_longer(
    cols = c(tCORALavg, tFMAavg),
    names_to = "variable",
    values_to = "value"
  )

p_box <- ggplot(data_long, aes(x = YEAR, y = value, fill = variable)) +
  geom_boxplot(alpha = 0.7, outlier.shape = 21,
               outlier.fill = "white", outlier.color = "black") +
  scale_fill_manual(values = c("#1b9e77", "#d95f02")) +
  labs(
    title = "Percentage Cover of Coral and Fleshy Algae",
    subtitle = "Comparison Across Years",
    x = NULL, y = "Cover (%)", fill = "Category"
  ) +
  theme_hri()

ggsave(here("results", "figures", "benthic_boxplot.png"), p_box,
       width = 8, height = 6, dpi = 300)

# Line chart: average cover trends over time
avg_CoralCover <- Belize_BenthicCover_2018_2023 %>%
  group_by(YEAR) %>%
  summarise(avg_cover = mean(tCORALavg), avg_algae = mean(tFMAavg), n = n())

p_trend <- ggplot(avg_CoralCover, aes(x = YEAR, group = 1)) +
  geom_line(aes(y = avg_cover, color = "Coral"), linewidth = 1) +
  geom_line(aes(y = avg_algae, color = "Fleshy Algae"), linewidth = 1) +
  geom_point(aes(y = avg_cover, color = "Coral")) +
  geom_point(aes(y = avg_algae, color = "Fleshy Algae")) +
  labs(x = "Year", y = "Average Cover (%)",
       title = "Average Coral and Fleshy Algae Cover Over Time") +
  scale_y_continuous(limits = c(0, 50)) +
  scale_color_manual(values = c("Coral" = "blue", "Fleshy Algae" = "green")) +
  theme_hri()

ggsave(here("results", "figures", "benthic_trends.png"), p_trend,
       width = 8, height = 6, dpi = 300)

# --- Summary table ------------------------------------------------------------
if (requireNamespace("gtsummary", quietly = TRUE)) {
  library(gtsummary)

  df_coral <- Belize_BenthicCover_2018_2023 %>%
    tbl_summary(
      by = YEAR,
      include = c(Name, "Reef Type"),
      label = list(Name ~ "Name", "Reef Type" ~ "Reef Type")
    ) %>%
    modify_header(label = "**Variable**") %>%
    bold_labels() %>%
    modify_caption("**Table 1. Summary of surveyed benthic sites by year**")

  print(df_coral)
} else {
  message("Note: gtsummary not installed, skipping summary table")
}

# --- Save processed output ----------------------------------------------------
write.csv(
  Belize_BenthicCover_2018_2023,
  here("data", "processed", "benthic_cover.csv"),
  row.names = FALSE
)

message("01_ingest_benthic.R complete: data/processed/benthic_cover.csv")
