# Builds `pypsa_eur_41`: PyPSA-Eur clustered to 41 nodes, full year.
#
# Source network: base_s_41_elec.nc, PyPSA-Eur's own k-means `cluster_network`
# at 41 clusters, so the model is directly comparable to a PyPSA-Eur run at the
# same size.
#
# FLAT TRADE. The object this replaces carried six loss tranches on 65 of its
# 92 corridors -- the converter's default when it was built. Each tranche
# becomes a generated constraint per corridor, direction and timeslice: 224,640
# of them on a 288-slice calendar, which no open solver generates in reasonable
# time, and 91% of the exchange files. Every other continental model is
# `tranches = NULL`, which is also the converter's default now.
#
# COSTS ARE SPLIT. With `costs =` the fuel price moves onto each fuel's supply
# and comes back out of `varom`, so a gas-price sensitivity is possible. The
# table is the one this network was built from, and the split is cost-neutral:
# the objective is unchanged.
#
# NOTE: the conversion functions currently live in the reneuro.dev workspace
# and are loaded from there until they move into this package.
suppressMessages(devtools::load_all("C:/Users/admin/Documents/R/useR/reneuro.dev",
                                    quiet = TRUE))
suppressMessages(library(energyRt))

ROOT <- "C:/Users/admin/source/pypsa-eur-v2026/resources/entsoe-2025"
NC   <- file.path(ROOT, "networks/base_s_41_elec.nc")
CS   <- file.path(ROOT, "costs_2050_processed.csv")

n <- suppressWarnings(read_pypsa(NC))
# @name is a solver-set identifier: CAPITALS (house rule for every @name
# stored in model sets). The R object / .rda symbol stays lowercase.
b <- convert_pypsa(n, cost_source = "network", tranches = NULL,
                   transmission = "transport", costs = CS,
                   name = "PYPSA_EUR_41", verbose = FALSE)
pypsa_eur_41 <- b$model

# Guards on the two properties this rebuild exists for.
o <- pypsa_eur_41@data[[1]]@data
cls <- vapply(o, function(z) class(z)[1], "")
ncl <- vapply(o[cls == "trade"], function(z) nrow(z@cluster), 0L)
if (any(ncl > 0)) {
  stop("still tranched: ", sum(ncl > 0), " corridor(s) carry clusters")
}
sup <- o[cls == "supply"]
priced <- vapply(sup, function(s) any(s@supply$cost > 0), TRUE)
if (!any(priced)) stop("no supply carries a fuel price; was `costs` read?")
message("trade corridors: ", sum(cls == "trade"), " (all flat)")
message("priced supplies: ", sum(priced), " of ", length(sup))

# Carry provenance on the object itself, so a user holding only the .rda can
# still say where it came from and which years it was built on. Weather and
# load are the 2025 snapshots. Existing renewables enter as cap.lo floors from
# the powerplantmatching plant database (attach_renewable_powerplants);
# IRENASTAT is not used, so no single capacity reference year applies.
source(file.path("data-raw", "globals.R"))
attr(pypsa_eur_41, "reneuro_provenance") <- reneuro_provenance(
  object = "pypsa_eur_41", source_nc = NC,
  convert_args = list(cost_source = "network", tranches = NULL, transmission = "transport", costs = basename(CS)),
  weather_year = 2025L, capacity_year = NA_integer_, cost_year = 2050L)
stop_if_no_provenance(pypsa_eur_41, "pypsa_eur_41")

usethis::use_data(pypsa_eur_41, overwrite = TRUE, compress = "xz")
