# ==============================================================================
# 04e_allocation_figures.R
# Purpose: Surface water allocation figures — CVP/SWP allocation time series,
#          maximum ag water volume map, and IV first-stage scatter plot.
#          Produces Figure C1 and Figure C2 in the paper appendix.
# Source:  allocations_figures.R (Code/2Clean/cleaning_code/)
#
# Inputs:  DERIVED/dauco_construction_panel.dta
#          RAW_DIR/surface_water/cvp_allocations.xlsx
#          RAW_DIR/gis/DAU_County_2018/DAU_County_2018.shp
#
# Outputs: FIGURES/fig_c1_alloc_timeseries.png   (Figure C1)
#          FIGURES/fig_c2_alloc_deliv_scatter.png (Figure C2)
#          FIGURES/alloc_max_vol_map.png          (Appendix map)
#
# Authors: Hadachek et al.
# Date:    2026-03-05
# ==============================================================================

library(here)
source(here::here("code", "config.R"))

pacman::p_load(haven, ggplot2, dplyr, sf, tmap, tidyr, readxl)


# ==============================================================================
# SECTION 1: Load data
# ==============================================================================

dauco_panel <- read_dta(file.path(DERIVED, "dauco_construction_panel.dta"))

dau <- st_read(file.path(RAW_DIR, "gis", "DAU_County_2018", "DAU_County_2018.shp")) %>%
  mutate(DAUCO = as.numeric(DAUCO))

cvp_allocations <- read_excel(
  file.path(RAW_DIR, "surface_water", "cvp_allocations.xlsx")
) %>%
  rename(Division = `...1`) %>%
  filter(!Division %in% c(
    "North of Delta Urban Contractors (M&I)",
    "American River M&I Contractors",
    "South of Delta Urban Contractors (M&I)"
  )) %>%
  pivot_longer(!Division, names_to = "year", values_to = "pct_allocation") %>%
  within(pct_allocation[pct_allocation > 100] <- 100)


# ==============================================================================
# SECTION 2: Figure C1 — CVP and SWP allocation % over time
# ==============================================================================

swp <- dauco_panel %>%
  group_by(year) %>%
  summarize(pct_allocation = mean(swp_pctallo_ag, na.rm = TRUE) * 100) %>%
  mutate(Division = "State Water Project")

alloc_data <- rbind(swp, cvp_allocations) %>%
  filter(year >= 1993)

gg_color_hue <- function(n) {
  hues <- seq(15, 375, length = n + 1)
  hcl(h = hues, l = 65, c = 100)[1:n]
}

color_lty_cross <- expand.grid(
  ltypes = c(1, 6),
  colors = gg_color_hue(6),
  stringsAsFactors = FALSE
)

fig_c1 <- ggplot(alloc_data) +
  geom_line(
    aes(x = as.numeric(year), y = pct_allocation, color = Division, lty = Division),
    linewidth = 1.1
  ) +
  ylab("% of Project Allocation") +
  xlab("") +
  scale_color_manual(values = color_lty_cross$colors[1:20]) +
  scale_linetype_manual(values = color_lty_cross$ltypes[1:20]) +
  theme_minimal() +
  theme(legend.position = "none")

ggsave(fig_c1, filename = file.path(FIGURES, "fig_c1_alloc_timeseries.png"),
       width = 10, height = 5)


# ==============================================================================
# SECTION 3: Appendix map — maximum ag water volume by DAU
# ==============================================================================

# Summarize dauco_panel to DAUCO level (time-average vol_maximum_ag and
# time-invariant area/crop share)
dauco_summary <- dauco_panel %>%
  group_by(DAUCO) %>%
  summarize(
    dauco_area     = first(dauco_area),
    dauco_pctcrop  = first(dauco_pctcrop),
    vol_maximum_ag = mean(vol_maximum_ag, na.rm = TRUE)
  )

fig_map <- dau %>%
  left_join(dauco_summary) %>%
  mutate(
    crop_acres = dauco_area * dauco_pctcrop * 247.11,
    max_afa    = vol_maximum_ag / crop_acres
  ) %>%
  within(max_afa[max_afa > 10] <- 10) %>%
  tm_shape() +
  tm_fill(
    fill       = "vol_maximum_ag",
    fill.scale = tm_scale_intervals(
      style  = "fixed",
      breaks = c(0, 250000, 500000, 750000, 1000000),
      values = "GnBu"
    ),
    fill.legend = tm_legend(title = "Maximum Volume (AF)")
  ) +
  tm_borders()

tmap_save(fig_map, filename = file.path(FIGURES, "alloc_max_vol_map.png"))


# ==============================================================================
# SECTION 4: Figure C2 — IV first-stage scatter (allocation vs deliveries)
# ==============================================================================

scatter_data <- dauco_panel %>%
  mutate(ag_deliveries_acre = vol_deliv_cy_ag / crop_acres) %>%
  within(ag_deliveries_acre[ag_deliveries_acre > 10] <- 10)

fig_c2 <- ggplot(scatter_data) +
  geom_point(aes(x = ag_allocation_acre, y = ag_deliveries_acre), alpha = 0.5) +
  geom_smooth(
    aes(x = ag_allocation_acre, y = ag_deliveries_acre),
    method = "lm", color = "blue"
  ) +
  geom_abline(intercept = 0, slope = 1, linewidth = 1, color = "red") +
  theme_minimal() +
  ylab("Ag SW Deliveries (AF/acre)") +
  xlab("Ag SW Allocations (AF/acre)")

ggsave(fig_c2, filename = file.path(FIGURES, "fig_c2_alloc_deliv_scatter.png"))
