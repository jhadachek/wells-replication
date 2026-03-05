# ==============================================================================
# 01f_well_completions.R
# Purpose: Validate CA DWR Well Completion Report (WCR) permit-to-construction
#          timing for agricultural wells. Produces an appendix figure showing
#          the distribution of lead times from permit to completed construction.
#          Adapted from permit_construction_date.R.
#
# NOTE: This script produces a DESCRIPTIVE FIGURE, not a cleaned panel dataset.
#       The derived well construction files (well_construction.csv etc.) used
#       in the analysis panels are provided in data/derived/ and were produced
#       by an earlier cleaning pipeline that is no longer available in full.
#
# Inputs:  RAW_DIR/wellcompletionreports/wellcompletionreports_2025.csv
#          (370MB; download from CA DWR:
#           https://data.cnra.ca.gov/dataset/well-completion-reports)
#
# Outputs: FIGURES/permit_to_construction.png
#
# Date:    2026-03-03
# ==============================================================================

source(here::here("code", "config.R"))

library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(ggplot2)


# Load WCR data ----------------------------------------------------------------

wellcompletionreports <- read_csv(
  file.path(RAW_DIR, "wellcompletionreports", "wellcompletionreports_2025.csv")
)


# Filter to new agricultural wells --------------------------------------------

ag_wells_construct <- wellcompletionreports %>%
  drop_na(DECIMALLONGITUDE, DECIMALLATITUDE) %>%
  filter(RECORDTYPE == "New") %>%
  filter(str_detect(PLANNEDUSEFORMERUSE, "Agri"))


# Compute permit-to-construction lead time ------------------------------------

ag_wells_dates <- ag_wells_construct %>%
  mutate(
    permit_date    = as.Date(PERMITDATE,    format = "%m/%d/%Y"),
    date           = as.Date(DATEWORKENDED, format = "%m/%d/%Y"),
    construct_time = as.numeric(date - permit_date)
  ) %>%
  filter(between(year(permit_date), 2015, 2025)) %>%
  filter(between(year(date),        2015, 2024)) %>%
  dplyr::select(WCRNUMBER, permit_date, construct_time) %>%
  filter(!is.na(permit_date)) %>%
  within(construct_time[construct_time <  -50] <-  -50) %>%
  within(construct_time[construct_time > 365]  <- 365)

# Share with short lead time (<= 93 days ~ 3 months)
ag_wells_dates$less_month <- ag_wells_dates$construct_time <= 93
print(table(ag_wells_dates$less_month))


# Figure: density of permit-to-construction time ------------------------------

density_plot <- ggplot(ag_wells_dates) +
  geom_density(aes(construct_time / 30), fill = "darkgray") +
  scale_x_continuous(
    "Permit to Construction (months)",
    breaks = seq(-1, 12, by = 1),
    limits = c(-1, 12)
  ) +
  ylab("Density") +
  ylim(c(0, 0.6)) +
  theme_minimal()

ggsave(
  density_plot,
  filename = file.path(FIGURES, "permit_to_construction.png"),
  width  = 4,
  height = 3
)
