# ==============================================================================
# 04d_descriptive.R
# Purpose: Descriptive and appendix figures — domestic well map, DTW change
#          maps, raw measurement timing, recharge coefficients, distance to
#          ag wells, well failure probability by demographics, and parallel
#          trends simulation.
#          Consolidates:
#            domestic_map.R         — domestic well locations map
#            dtw_map.R              — DAU-level DTW change maps across years
#            raw_dtw_measurements.R — histogram of measurement timing by month
#            recharge_coef.R        — recharge coefficient from CA water balance
#            well_dist.R            — nearest-neighbor & buffer: domestic vs ag wells
#            well_failure_prob.R    — failure probability by demographic subgroup
#            diff_trends_simulation — parallel trends simulation figure
#
# Inputs:  DERIVED/well_construction.csv         (domestic + ag well locations)
#          DERIVED/gwdepth_well_panel.dta         (monitoring well depth panel)
#          DERIVED/domestic_failures_panel.dta   (domestic failure panel)
#          RAW_DIR/nhgis0006_csv/nhgis0006_ds249_20205_tract.csv
#          RAW_DIR/gis/DAU_County_2018/DAU_County_2018.shp
#          RAW_DIR/water_balance/CA-DWR-WaterBalance-Level2-DP-1000-{year}-DAUCO.csv  [commented out — Section 4]
#          RAW_DIR/swrcb_groundwater/gama_all_dtw_elev.dta
#          RAW_DIR/cnra/periodic_levels/measurements.dta
#
# Outputs: FIGURES/domestic_map.png
#          FIGURES/dtw_map.png
#          FIGURES/permit_to_construction.png    (see also 01f)
#          FIGURES/nn_hist.png
#          FIGURES/buffer_hist.png
#          FIGURES/ttest_failure_prob.png
#          FIGURES/ttest_well_depth.png
#          FIGURES/diff_trends_raw.png
#          FIGURES/diff_trends_diff.png
#          FIGURES/diff_trends_fe.png
#
# Notes:   - dtw_map.R source had incomplete code fragments (see TODO below).
#          - raw_dtw_measurements.R had no ggsave() call in the original;
#            output save added here.
#          - recharge_coef.R read from final2.dta (superseded); updated to
#            dauco_construction_panel.dta (canonical).
#
# Date:    2026-03-03
# ==============================================================================

source(here::here("code", "config.R"))

library(haven)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(lubridate)
library(ggplot2)
library(ggpubr)
library(sf)
library(tigris)
library(tmap)
library(nngeo)
library(latex2exp)
library(hrbrthemes)
library(fixest)
library(MASS)


# ==============================================================================
# SECTION 1: Domestic Well Locations Map
# Source: domestic_map.R
# ==============================================================================

well_construction <- read_csv(
  file.path(DERIVED, "well_construction.csv")
)

demographics <- read_csv(
  file.path(RAW_DIR, "nhgis0006_csv", "nhgis0006_ds249_20205_tract.csv")
) %>%
  filter(STATE == "California") %>%
  dplyr::select(
    GISJOIN, STATEA, COUNTYA, TRACTA,
    AMPVE001, AMP3E012, AMR8E001, AMR5E001, AMR5E002
  ) %>%
  rename(
    Pop = AMPVE001, HispPop = AMP3E012, MedianIncom = AMR8E001,
    HH = AMR5E001, HH_pov = AMR5E002
  ) %>%
  mutate(
    pct_hisp = HispPop / Pop * 100,
    pct_pov  = HH_pov  / HH  * 100
  ) %>%
  rename(TRACTCE = TRACTA, STATEFP = STATEA, COUNTYFP = COUNTYA) %>%
  mutate(
    TRACTCE  = str_pad(TRACTCE,  6, side = "left", pad = "0"),
    STATEFP  = str_pad(STATEFP,  2, side = "left", pad = "0"),
    COUNTYFP = str_pad(COUNTYFP, 3, side = "left", pad = "0")
  )

counties <- counties(state = "CA")
tracts   <- tigris::tracts(state = "California")

tracts <- tracts %>%
  left_join(demographics) %>%
  mutate(
    ALAND  = ALAND  * 0.00000038610,
    AWATER = AWATER * 0.00000038610
  ) %>%
  mutate(density = Pop / (ALAND + AWATER))

domestic <- well_construction %>%
  filter(type == "Domestic") %>%
  distinct(DecimalLatitude, DecimalLongitude, .keep_all = TRUE) %>%
  st_as_sf(coords = c("DecimalLongitude", "DecimalLatitude")) %>%
  st_set_crs("+proj=longlat +datum=WGS84 +no_defs") %>%
  st_transform(st_crs(tracts))

domestic <- domestic %>% st_join(tracts)

domestic_tract <- domestic %>%
  group_by(STATEFP, COUNTYFP, TRACTCE) %>%
  st_drop_geometry() %>%
  summarize(count = n())

domestic_full <- tracts %>%
  left_join(domestic_tract) %>%
  within(count[is.na(count)] <- 0) %>%
  filter(Pop > 10) %>%
  mutate(count_pcapita = count / Pop) %>%
  filter(!is.infinite(count_pcapita))

domestic_map <- tm_shape(domestic) +
  tm_symbols(fill = "black", fill_alpha = 0.2, size = 0.001) +
  tm_shape(counties) +
  tm_borders(lwd = 1) +
  tm_add_legend(type = "symbols", labels = "Domestic Well", shape = 4, fill = "black")

tmap_save(domestic_map, filename = file.path(FIGURES, "domestic_map.png"))


# ==============================================================================
# SECTION 2: DTW Change Maps by Year
# Source: dtw_map.R
# TODO: Source had incomplete code (dangling pipe fragments for diff_depth_2015
#       and diff_depth_1994; final2 object not loaded). Needs author clarification.
#       Reproduced what was complete; incomplete fragments commented out below.
# ==============================================================================

gwdepth_well_panel <- read_dta(file.path(DERIVED, "gwdepth_well_panel.dta"))

dau <- st_read(
  file.path(RAW_DIR, "gis", "DAU_County_2018", "DAU_County_2018.shp")
) %>%
  mutate(DAUCO = as.numeric(DAUCO))

diff_depth_2006 <- gwdepth_well_panel[, 1:6] %>%
  filter(year >= 1993 & year <= 2020) %>%
  arrange(wellid, year) %>%
  group_by(wellid) %>%
  mutate(diff_depth = dtw - lag(dtw, 1)) %>%
  ungroup() %>%
  group_by(DAUCO) %>%
  mutate(pct90 = quantile(diff_depth, probs = 0.90, na.rm = TRUE)) %>%
  filter(diff_depth <  1.5 * pct90) %>%
  filter(diff_depth > -1.5 * pct90) %>%
  filter(year == 2007) %>%
  group_by(DAUCO) %>%
  summarize(av_diff_depth = mean(diff_depth, na.rm = TRUE))

# TODO: diff_depth_1994 and diff_depth_2015 were referenced in dtw_map.R but
#       not computed there. Reconstruct analogously to diff_depth_2006 above
#       using filter(year == 1994) and filter(year == 2015).

dau_dtw_2006 <- dau %>% left_join(diff_depth_2006)

dtw_2006 <- tm_shape(dau_dtw_2006) +
  tm_fill(
    fill         = "av_diff_depth",
    fill.scale   = tm_scale_intervals(style="fixed", breaks=c(-10,-5,0,5,10), values="-RdYlBu"),
    fill.legend  = tm_legend_hide()
  ) +
  tm_shape(dau) +
  tm_borders() +
  tm_layout(main.title = "2006")

tmap_save(dtw_2006, file.path(FIGURES, "dtw_map.png"), width = 7, height = 5)


# ==============================================================================
# SECTION 3: Raw DTW Measurement Timing by Month
# Source: raw_dtw_measurements.R
# ==============================================================================

gama_all_dtw_elev <- read_dta(
  file.path(RAW_DIR, "swrcb_groundwater", "gama_all_dtw_elev.dta")
)

measurements <- read_dta(
  file.path(RAW_DIR, "cnra", "periodic_levels", "measurements.dta")
)

msm_dates <- measurements %>%
  dplyr::select(MSMT_DATE) %>%
  mutate(date = str_sub(MSMT_DATE, 0, 10)) %>%
  dplyr::select(-MSMT_DATE) %>%
  mutate(date = as.Date(date, format = "%Y-%m-%d"))

gama_dates <- gama_all_dtw_elev %>%
  dplyr::select(measurementdate) %>%
  mutate(date = as.Date(measurementdate, format = "%m/%d/%Y")) %>%
  dplyr::select(-measurementdate)

all_dates <- rbind(gama_dates, msm_dates) %>%
  mutate(month = month(date))

by_month <- all_dates %>%
  group_by(month) %>%
  summarize(count = n()) %>%
  ungroup() %>%
  mutate(total = sum(count), pct = count / total)

measurement_timing <- ggplot(by_month) +
  geom_bar(aes(x = month, y = pct), stat = "identity", fill = "steelblue") +
  scale_x_continuous("Month", breaks = 1:12) +
  ylab("Share of Measurements") +
  theme_minimal()

ggsave(
  measurement_timing,
  filename = file.path(FIGURES, "raw_dtw_measurements.png"),
  width = 6, height = 4
)


# ==============================================================================
# SECTION 4: Recharge Coefficient from CA Water Balance
# Source: recharge_coef.R
# NOTE: Commented out — requires RAW_DIR/water_balance/CA-DWR-WaterBalance-
#       Level2-DP-1000-{year}-DAUCO.csv (years 2002–2020, excl. 2017).
#       This block produces no figure output; reactivate if data is available.
# ==============================================================================

# yearlist <- seq(2002, 2020, 1)[-16]  # exclude 2017 (missing)
#
# final <- read_dta(file.path(DERIVED, "dauco_construction_panel.dta")) %>%
#   dplyr::select(dau_name, dauco_pctcrop, dauco_area) %>%
#   mutate(dauco_acres = dauco_pctcrop * dauco_area * 247.11) %>%
#   group_by(dau_name) %>%
#   summarize(dauco_acres = first(dauco_acres)) %>%
#   rename(DAU_NAME = dau_name)
#
# recharge_list <- vector("list", length(yearlist))
#
# for (i in seq_along(yearlist)) {
#   x <- yearlist[i]
#
#   water <- read_csv(
#     file.path(
#       RAW_DIR, "water_balance",
#       paste0("CA-DWR-WaterBalance-Level2-DP-1000-", x, "-DAUCO.csv")
#     )
#   )
#
#   agwater <- water %>%
#     filter(CategoryC %in% c(
#       "Applied Water Use",
#       "Deep Percolation of Applied Water",
#       "Deep Percolation of Groundwater Recharge"
#     )) %>%
#     group_by(DAU_NAME, CategoryC, CategoryA) %>%
#     summarize(KAcreFt = sum(KAcreFt, na.rm = TRUE)) %>%
#     pivot_wider(
#       values_from = KAcreFt,
#       names_from  = c(CategoryC, CategoryA)
#     ) %>%
#     mutate(
#       total_applied = rowSums(
#         pick(`Applied Water Use_Agriculture`:`Applied Water Use_Wild and Scenic River`),
#         na.rm = TRUE
#       ),
#       total_perc = rowSums(
#         pick(`Deep Percolation of Applied Water_Agriculture`:`Deep Percolation of Groundwater Recharge_Urban`),
#         na.rm = TRUE
#       ),
#       recharge_coef = total_perc / total_applied
#     ) %>%
#     filter(!is.infinite(recharge_coef)) %>%
#     mutate(year = x)
#
#   recharge_list[[i]] <- agwater %>%
#     left_join(final) %>%
#     filter(!is.na(dauco_acres))
# }
#
# recharge_all <- bind_rows(recharge_list)
#
# recharge_byyear <- recharge_all %>%
#   group_by(year) %>%
#   summarize(
#     recharge_coef = weighted.mean(recharge_coef, w = dauco_acres, na.rm = TRUE)
#   )


# ==============================================================================
# SECTION 5: Distance from Domestic to Agricultural Wells
# Source: well_dist.R
# ==============================================================================

ag_wells <- well_construction %>%
  filter(type == "Agriculture") %>%
  filter(year(DateWorkEnded) > 1993) %>%
  group_by(DecimalLongitude, DecimalLatitude) %>%
  summarize(count = n()) %>%
  st_as_sf(coords = c("DecimalLongitude", "DecimalLatitude")) %>%
  st_set_crs("+proj=longlat +datum=WGS84 +no_defs") %>%
  ungroup()

domestic_wells <- well_construction %>%
  filter(year(DateWorkEnded) > 1993) %>%
  filter(type == "Domestic") %>%
  group_by(DecimalLongitude, DecimalLatitude) %>%
  summarize(count = n()) %>%
  st_as_sf(coords = c("DecimalLongitude", "DecimalLatitude")) %>%
  st_set_crs("+proj=longlat +datum=WGS84 +no_defs") %>%
  ungroup()

df_dist <- data.frame(distance = numeric(0))

for (i in seq_len(nrow(domestic_wells))) {
  nn <- st_nn(domestic_wells[i, ], ag_wells, k = 2, returnDist = TRUE, progress = FALSE)
  second_distances <- sapply(nn$dist, function(x) x[2])
  df_dist <- rbind(df_dist, data.frame(distance = second_distances))
}

nn_hist <- ggplot(df_dist %>% within(distance[distance > 10000] <- 10000)) +
  geom_histogram(
    aes(distance / 1000, y = after_stat(density)),
    breaks = seq(0, 10, by = 0.5)
  ) +
  xlab("Dist. to Ag Well (km)") +
  ylab("Share of Domestic Wells") +
  theme_minimal() +
  scale_x_continuous(
    breaks = seq(0, 10, by = 1),
    labels = c(paste(seq(0, 9, by = 1)), ">10")
  )

ggsave(nn_hist, filename = file.path(FIGURES, "nn_hist.png"))

# Buffer approach: count ag wells within 3km of each domestic well
domestic_buffers   <- st_buffer(domestic_wells, dist = 3000)
buffer_intersect   <- st_intersects(domestic_buffers, ag_wells)
domestic_buffers$domestic_count <- lengths(buffer_intersect)

buffer_hist <- ggplot(
  domestic_buffers %>% within(domestic_count[domestic_count > 30] <- 30)
) +
  geom_histogram(aes(domestic_count, y = after_stat(density)), binwidth = 1) +
  xlab("Count of Ag Wells in 3km Buffer") +
  ylab("Share of Domestic Wells") +
  theme_minimal() +
  scale_x_continuous(
    breaks = seq(0, 30, by = 2),
    labels = c(paste(seq(0, 28, by = 2)), ">30")
  )

ggsave(buffer_hist, filename = file.path(FIGURES, "buffer_hist.png"), height = 4, width = 7)


# ==============================================================================
# SECTION 6: Well Failure Probability by Demographic Subgroup
# Source: well_failure_prob.R
# ==============================================================================

domestic_failures_panel <- read_dta(file.path(DERIVED, "domestic_failures_panel.dta")) %>%
  rename(failure = treat)

failures_well <- domestic_failures_panel %>%
  mutate(
    population  = WhitePop / (pct_white / 100),
    crop_acres  = dauco_area * dauco_pctcrop * 247.11
  ) %>%
  group_by(id) %>%
  summarize(
    failure    = max(failure, na.rm = TRUE),
    pct_white  = first(pct_white),
    pct_pov    = first(pct_pov),
    well_depth = first(TotalCompletedDepth3),
    crop_acres = first(dauco_pctcrop),
    population = first(population)
  ) %>%
  ungroup() %>%
  mutate(
    pct_nonwhite = 100 - pct_white,
    nonwhite     = pct_nonwhite > median(pct_nonwhite, na.rm = TRUE),
    lowincome    = pct_pov      > median(pct_pov,      na.rm = TRUE),
    deep         = well_depth   > median(well_depth,   na.rm = TRUE),
    populated    = population   > median(population,   na.rm = TRUE),
    cropped      = crop_acres   > median(crop_acres,   na.rm = TRUE)
  )

demolist <- c("lowincome", "nonwhite", "populated", "cropped")

labels_demo <- c(
  "% Low Income", "% Non-White", "% Crop Acres", "Population"
)
names(labels_demo) <- c("lowincome", "nonwhite", "cropped", "populated")

dat <- data.frame()
for (i in demolist) {
  t1 <- t.test(failures_well$failure[failures_well[[i]] == 1], conf.level = 0.95)
  t2 <- t.test(failures_well$failure[failures_well[[i]] == 0], conf.level = 0.95)
  temp <- data.frame(
    Demographic  = rep(i, 2),
    median       = c("Above", "Below"),
    estimate     = c(t1$estimate, t2$estimate),
    lower.bound  = c(t1$conf.int[1], t2$conf.int[1]),
    upper.bound  = c(t1$conf.int[2], t2$conf.int[2])
  )
  dat <- rbind(temp, dat)
}
dat$id <- seq_len(nrow(dat))
dat$Demographic <- factor(dat$Demographic, levels = c("lowincome", "nonwhite", "cropped", "populated"))

ttest <- ggplot(dat, aes(x = median, y = estimate, color = median)) +
  geom_errorbar(aes(ymin = lower.bound, ymax = upper.bound), lwd = 1.5, alpha = 0.5) +
  geom_point(size = 1.5) +
  scale_y_continuous("Probability of Well Failure", limits = c(0, 0.05)) +
  facet_grid(
    ~Demographic,
    scales   = "free_x",
    space    = "free_x",
    switch   = "x",
    labeller = labeller(Demographic = labels_demo)
  ) +
  xlab("") +
  theme_bw() +
  theme(strip.placement = "outside", legend.position = "none")

ggsave(file.path(FIGURES, "ttest_failure_prob.png"), ttest)

# Well depth by demographic subgroup
dat2 <- data.frame()
for (i in demolist) {
  t1 <- t.test(failures_well$well_depth[failures_well[[i]] == 1], conf.level = 0.95)
  t2 <- t.test(failures_well$well_depth[failures_well[[i]] == 0], conf.level = 0.95)
  temp <- data.frame(
    Demographic  = rep(i, 2),
    median       = c("Above", "Below"),
    estimate     = c(t1$estimate, t2$estimate),
    lower.bound  = c(t1$conf.int[1], t2$conf.int[1]),
    upper.bound  = c(t1$conf.int[2], t2$conf.int[2])
  )
  dat2 <- rbind(temp, dat2)
}
dat2$id <- seq_len(nrow(dat2))
dat2$Demographic <- factor(dat2$Demographic, levels = c("lowincome", "nonwhite", "cropped", "populated"))

ttest2 <- ggplot(dat2, aes(x = median, y = estimate, color = median)) +
  geom_errorbar(aes(ymin = lower.bound, ymax = upper.bound), lwd = 1.5, alpha = 0.5) +
  geom_point(size = 1.5) +
  scale_y_continuous("Average Well Depth") +
  facet_grid(
    ~Demographic,
    scales   = "free_x",
    space    = "free_x",
    switch   = "x",
    labeller = labeller(Demographic = labels_demo)
  ) +
  xlab("") +
  theme_bw() +
  theme(strip.placement = "outside", legend.position = "none")

ggsave(file.path(FIGURES, "ttest_well_depth.png"), ttest2)


# ==============================================================================
# SECTION 7: Parallel Trends Simulation
# Source: diff_trends_simulation.R
# ==============================================================================

set.seed(42)
t     <- seq(1, 100, 1)
shock <- c(rep(0, 49), rep(1, 51))
x     <- 15 + 2 * t + shock * 10 + rnorm(n = 100)
y     <- 10 + 1 * t + shock * 10 + rnorm(n = 100)
z     <- 10 + 0 * t + shock * 10 + rnorm(n = 100)

df_sim <- data.frame(t, shock, x, y, z) %>%
  pivot_longer(cols = c(x, y, z)) %>%
  rename(Well = name, Depth = value)

raw <- ggplot(df_sim) +
  geom_point(aes(t, Depth, color = Well), size = 2, alpha = 0.75) +
  geom_smooth(
    data    = df_sim[df_sim$shock == 0, ],
    aes(t, Depth, color = Well), se = FALSE, method = "lm", linewidth = 2
  ) +
  geom_smooth(
    data    = df_sim[df_sim$shock == 1, ],
    aes(t, Depth, color = Well), se = FALSE, method = "lm", linewidth = 2
  ) +
  geom_vline(xintercept = 50, lty = "dashed") +
  scale_color_discrete(labels = c("x" = "1", "y" = "2", "z" = "3")) +
  xlab("Time") +
  theme_ipsum() +
  theme(
    axis.text.x  = element_blank(), axis.ticks.x = element_blank(),
    axis.text.y  = element_blank(), axis.ticks.y = element_blank()
  )

df_sim1 <- df_sim %>%
  group_by(Well) %>%
  mutate(shock_1 = 0) %>%
  within(shock_1[t == 50] <- 1) %>%
  arrange(t) %>%
  mutate(Flow = Depth - lag(Depth, 1))

diff_plot <- ggplot(df_sim1) +
  geom_point(aes(t, Flow, color = Well), size = 2, alpha = 0.75) +
  geom_smooth(aes(t, Flow, color = Well), method = "lm", se = FALSE, linewidth = 2) +
  geom_vline(xintercept = 50, lty = "dashed") +
  xlab("Time") +
  scale_color_discrete(labels = c("x" = "1", "y" = "2", "z" = "3")) +
  theme_ipsum() +
  theme(
    axis.text.x  = element_blank(), axis.ticks.x = element_blank(),
    axis.text.y  = element_blank(), axis.ticks.y = element_blank()
  )

df_sim1 <- df_sim1 %>%
  group_by(Well) %>%
  mutate(mean = mean(Flow, na.rm = TRUE), dev = Flow - mean)

diff_fe <- ggplot(df_sim1) +
  geom_point(aes(dev, t, color = Well), size = 2, alpha = 0.75) +
  geom_smooth(
    aes(dev, t, color = Well), method = "lm", se = FALSE,
    linewidth = 2, orientation = "y"
  ) +
  geom_hline(yintercept = 50, lty = "dashed") +
  scale_color_discrete(labels = c("x" = "1", "y" = "2", "z" = "3")) +
  xlab("Deviation from Mean Flow Rate") +
  ylab("Time") +
  theme_ipsum() +
  coord_flip() +
  geom_bracket(
    xmin = 0, xmax = 9, y.position = 60,
    label = "ATE", size = 1.5, label.size = 8, coord.flip = TRUE,
    tip.length = c(0.05, 0.05)
  ) +
  theme(
    axis.text.x  = element_blank(), axis.ticks.x = element_blank(),
    axis.text.y  = element_blank(), axis.ticks.y = element_blank()
  )

ggsave(file.path(FIGURES, "diff_trends_raw.png"), raw)
ggsave(file.path(FIGURES, "diff_trends_diff.png"), diff_plot)
ggsave(file.path(FIGURES, "diff_trends_fe.png"),   diff_fe)

ggarrange(raw, diff_plot, diff_fe, nrow = 1, ncol = 3, common.legend = TRUE,
          labels = c("a", "b", "c"))
