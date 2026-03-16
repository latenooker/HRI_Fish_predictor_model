# =============================================================================
# 00_functions.R
# Shared helper functions for HRI AGRRA Belize data processing pipeline
# =============================================================================

library(tidyverse)
library(readxl)
library(here)

#' Load and filter AGRRA data from a multi-year Excel file
#'
#' Reads an Excel sheet, filters to Belize for specified years, and cleans
#' the Batch/Date columns used in the 2011-2021 data files.
#'
#' @param path Character. Path to the Excel file.
#' @param sheet Character. Sheet name to read.
#' @param cols Character vector. Column names to select before filtering.
#' @param years Numeric vector. Years to keep (e.g., c(2018, 2021)).
#' @return A tibble filtered to Belize rows for the specified years,
#'   with Batch split into Country/Year and Date split into YEAR/Month/Day,
#'   then Country, Y, Month, Day columns dropped.
load_belize_data <- function(path, sheet, cols, years) {
  df <- read_excel(path, sheet = sheet) %>%
    select(all_of(cols))

  df %>%
    separate(Batch, into = c("Country", "Y"), sep = "-") %>%
    separate(Date, into = c("YEAR", "Month", "Day"), sep = "-") %>%
    filter(Country == "Belize", YEAR %in% years) %>%
    select(-c(Y, Month, Day, Country))
}

#' Ensure output directories exist
#'
#' Creates directories if they don't already exist. Silently succeeds if
#' directories are already present.
#'
#' @param dirs Character vector of directory paths to create.
#' @return Invisible NULL. Called for side effect of creating directories.
ensure_dirs <- function(dirs) {
  for (d in dirs) {
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
  }
  invisible(NULL)
}

#' Standardized ggplot theme for HRI figures
#'
#' A minimal theme with centered titles, angled x-axis labels, and
#' dashed major grid lines. Used across all pipeline plots for consistency.
#'
#' @return A ggplot2 theme object.
theme_hri <- function() {
  theme_minimal(base_size = 14) +
    theme(
      plot.title = element_text(face = "bold", hjust = 0.5, size = 16),
      plot.subtitle = element_text(hjust = 0.5, size = 12, color = "gray50"),
      axis.title.y = element_text(face = "bold"),
      axis.text.x = element_text(angle = 45, vjust = 0.5),
      panel.grid.major = element_line(color = "gray85", linetype = "dashed"),
      panel.grid.minor = element_blank(),
      legend.position = "top"
    )
}
