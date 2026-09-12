# Renders the source-data figures the data-sources article embeds.
#
#   Rscript data-raw/data_sources_figures.R
#
# The sources live only on the build machine (the PyPSA-Eur clone and the
# 6.7 GB cutout), so the figures are committed as PNGs under
# vignettes/articles/figures/data-sources/ and the article embeds them --
# the same precompute pattern as data-raw/example_reports.R. The cutout
# time-means are extracted to a small CSV first (a python/xarray one-liner;
# see the header of each figure block for the expected input).
suppressPackageStartupMessages({
  library(ggplot2)
  library(data.table)
})

CLONE <- Sys.getenv("RENEURO_PYPSA_EUR", "C:/Users/admin/source/pypsa-eur-v2026")
MEANS <- Sys.getenv(
  "RENEURO_CUTOUT_MEANS",
  file.path(dirname(tempdir()), "cutout_means_2025.csv"))
OUT <- "vignettes/articles/figures/data-sources"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

coast <- if (requireNamespace("rnaturalearth", quietly = TRUE)) {
  rnaturalearth::ne_coastline(scale = 50, returnclass = "sf")
} else NULL
# no titles/subtitles in the figures -- attribution and description live in
# the article's fig.cap captions
map_theme <- theme_void() +
  theme(plot.background = element_rect(fill = "white", colour = NA),
        legend.position = "right")
lims <- list(x = c(-12, 42), y = c(33, 72))

# ---- 1. the weather cutout ---------------------------------------------------
# Input: per-cell 2025 time-means of `wnd100m` and `influx_direct+diffuse`,
# extracted from europe-2025-sarah3-era5.nc with xarray.
if (file.exists(MEANS)) {
  m <- fread(MEANS)
  base <- function(fill_lab) {
    ggplot(m) + labs(fill = fill_lab) + map_theme
  }
  p <- base("m/s") +
    geom_raster(aes(x, y, fill = wnd100m), interpolate = TRUE) +
    energypal::scale_fill_energy_c("windatlas")
  if (!is.null(coast)) p <- p + geom_sf(data = coast, colour = "white",
                                        linewidth = 0.15)
  p <- p + coord_sf(xlim = lims$x, ylim = lims$y, expand = FALSE)
  ggsave(file.path(OUT, "cutout-wind.png"), p, width = 7, height = 6, dpi = 110)

  p <- base("W/m^2") +
    geom_raster(aes(x, y, fill = influx), interpolate = TRUE) +
    energypal::scale_fill_energy_c("solaratlas")
  if (!is.null(coast)) p <- p + geom_sf(data = coast, colour = "white",
                                        linewidth = 0.15)
  p <- p + coord_sf(xlim = lims$x, ylim = lims$y, expand = FALSE)
  ggsave(file.path(OUT, "cutout-solar.png"), p, width = 7, height = 6, dpi = 110)
  message("cutout maps written")
} else {
  message("skipping cutout maps: ", MEANS, " not found")
}

# ---- 2. ENTSO-E demand -------------------------------------------------------
DEM <- file.path(CLONE, "data/entsoe_electricity_demand/archive/2026-02-02",
                 "electricity_demand_entsoe_raw.csv")
if (file.exists(DEM)) {
  d <- fread(DEM)
  setnames(d, 1, "time")
  d <- d[time >= "2025-01-01" & time < "2026-01-01"]
  top <- c("DE", "FR", "IT", "GB", "ES", "PL", "NL", "BE")
  long <- melt(d[, c("time", top), with = FALSE], id.vars = "time",
               variable.name = "country", value.name = "MW")
  long[, week := as.Date(cut(as.Date(substr(time, 1, 10)), "week"))]
  wk <- long[, .(GW = mean(MW, na.rm = TRUE) / 1e3), by = .(country, week)]
  p <- ggplot(wk, aes(week, GW, colour = country)) +
    geom_line(linewidth = 0.5) +
    scale_colour_viridis_d(option = "H", end = 0.9) +
    labs(x = NULL, y = "GW", colour = NULL) +
    theme_minimal() +
    theme(plot.background = element_rect(fill = "white", colour = NA))
  ggsave(file.path(OUT, "demand-entsoe.png"), p, width = 8, height = 4.2,
         dpi = 110)
  message("demand figure written")
} else message("skipping demand: raw csv not found")

# ---- 3. the power plant fleet ------------------------------------------------
PPL <- file.path(CLONE, "resources/entsoe-2025/powerplants_s_41.csv")
if (file.exists(PPL)) {
  pp <- fread(PPL)
  pp <- pp[Capacity >= 100 & !is.na(lat)]
  main <- c("Nuclear", "Hard Coal", "Lignite", "Natural Gas", "Hydro",
            "Wind", "Solar", "Oil")
  pp <- pp[Fueltype %in% main]
  p <- ggplot(pp)
  if (!is.null(coast)) p <- p + geom_sf(data = coast, colour = "grey40",
                                        linewidth = 0.15)
  p <- p +
    geom_point(aes(lon, lat, size = Capacity / 1e3, colour = Fueltype),
               alpha = 0.5, stroke = 0) +
    scale_size_area(max_size = 5) +
    energypal::scale_colour_energy("carriers") +
    coord_sf(xlim = lims$x, ylim = lims$y, expand = FALSE) +
    labs(size = "GW", colour = NULL) +
    map_theme +
    guides(colour = guide_legend(override.aes = list(size = 3, alpha = 1)))
  ggsave(file.path(OUT, "fleet.png"), p, width = 7.5, height = 6, dpi = 110)
  message("fleet figure written")
} else message("skipping fleet: powerplants csv not found")

message("done. ", OUT, ":")
for (f in list.files(OUT)) message("  ", f, "  ",
                                   round(file.size(file.path(OUT, f)) / 1024), " kB")
