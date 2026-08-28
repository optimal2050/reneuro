# Builds `pypsa_eur_1035`: PyPSA-Eur at NUTS3 resolution, seasonal sample.
#
# Source network: base_s_1035_elec.nc, built from a PyPSA-Eur clone with
# clustering.mode = custom_busmap and the NUTS3 busmap in data/busmaps/.
# NUTS3 yields 1,035 clusters rather than 1,477 because 442 NUTS3 regions
# contain no substation.
#
# The calendar is four mid-season days at hourly resolution (96 of 8,760
# snapshots). `capital_cost` is rescaled by the sampled fraction, so investment
# and operating costs stay commensurate.
#
# Trade uses one flat loss rate per corridor (tranches = NULL) and a transport
# formulation without Kirchhoff's voltage law, which keeps the model solvable
# at this resolution.
#
# NOTE: the conversion functions currently live in the reneuro.dev workspace
# and are loaded from there until they move into this package.
suppressMessages(devtools::load_all("C:/Users/admin/Documents/R/useR/reneuro.dev",
                                    quiet = TRUE))
NC <- "C:/Users/admin/source/pypsa-eur-v2026/resources/entsoe-all/networks/base_s_1035_elec.nc"

n <- suppressWarnings(read_pypsa(NC))
s <- sample_pypsa(n, "seasons")
b <- convert_pypsa(s, cost_source = "network", tranches = NULL,
                   transmission = "transport", verbose = FALSE)

pypsa_eur_1035 <- b$model
usethis::use_data(pypsa_eur_1035, overwrite = TRUE, compress = "xz")
