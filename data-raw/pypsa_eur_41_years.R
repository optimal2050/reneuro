# Builds the one-year horizon series `pypsa_eur_41_2025` ... `_2050`.
#
# Each is an overnight one-year build on the SAME 2025 weather, load and
# network as `pypsa_eur_41`; what changes per horizon Y is
#   * the cost vintage: base_s_41_elec_y<Y>.nc was built with costs.year = Y,
#     so capex, varom and fuel prices are the technology-data value for Y, and
#   * the existing fleet, aged by data-raw/retire.R: announced DateOut
#     schedules plus assumed carrier-lifetime retirement, recorded separately
#     in provenance so the assumed half can be identified (PyPSA's overnight
#     mode does no ageing at all; myopic drops build_year + lifetime <= Y,
#     which is what the assumed rule reproduces).
#
# THE WEATHER IS NOT DUPLICATED. All six share `pypsa_eur_41`'s profiles
# bit-for-bit, so the series ships weatherless; `attach_weather(m, from =
# pypsa_eur_41)` restores them before interpolation.
suppressMessages(devtools::load_all("C:/Users/admin/Documents/R/useR/reneuro.dev",
                                    quiet = TRUE))
suppressMessages(library(energyRt))
source(file.path("data-raw", "globals.R"))
source(file.path("data-raw", "retire.R"))

ROOT <- "C:/Users/admin/source/pypsa-eur-v2026/resources/entsoe-2025"
YEARS <- c(2025L, 2030L, 2035L, 2040L, 2045L, 2050L)

ppl <- utils::read.csv(file.path(ROOT, "powerplants_s_41.csv"))

for (Y in YEARS) {
  NC <- file.path(ROOT, sprintf("networks/base_s_41_elec_y%d.nc", Y))
  CS <- file.path(ROOT, sprintf("costs_%d_processed.csv", Y))
  stopifnot(file.exists(NC), file.exists(CS))

  n <- suppressWarnings(read_pypsa(NC))
  b <- convert_pypsa(n, cost_source = "network", tranches = NULL,
                     transmission = "transport", costs = CS, verbose = FALSE)
  m <- b$model

  # -- age the fleet ----------------------------------------------------------
  costs <- utils::read.csv(CS, check.names = FALSE)
  lifetimes <- stats::setNames(costs$lifetime, costs$technology)
  # the cost table keys offshore wind as "offwind"; the fleet carriers carry
  # the grid-connection suffix
  for (ow in c("offwind-ac", "offwind-dc", "offwind-float")) {
    if (!ow %in% names(lifetimes)) lifetimes[[ow]] <- lifetimes[["offwind"]]
  }
  fr <- retirement_fractions(ppl, Y, lifetimes)
  maps <- pypsa_namemaps(n)
  ret <- apply_retirement(m, fr, function(x) pypsa_name_to(maps$buses, x))
  m <- ret$model

  # -- strip the weather (shared with pypsa_eur_41) ---------------------------
  objs <- m@data[[1]]@data
  cls <- vapply(objs, function(o) class(o)[1], "")
  m@data[[1]]@data <- objs[cls != "weather"]

  nm <- sprintf("pypsa_eur_41_%d", Y)
  attr(m, "reneuro_provenance") <- c(reneuro_provenance(
    object = nm, source_nc = NC,
    convert_args = list(cost_source = "network", tranches = NULL,
                        transmission = "transport", costs = basename(CS)),
    weather_year = 2025L, capacity_year = NA_integer_, cost_year = Y),
    list(horizon = Y, retirement = ret$applied,
         weather = "stripped; attach_weather(m, from = pypsa_eur_41)"))
  stop_if_no_provenance(m, nm)

  assign(nm, m)
  do.call(usethis::use_data,
          list(as.name(nm), overwrite = TRUE, compress = "xz"))

  gw <- vapply(ret$applied, function(x) x[["announced_GW"]] + x[["assumed_GW"]], 0)
  message(sprintf("%s: retired %.1f GW across %d carriers", nm, sum(gw), length(gw)))
}
