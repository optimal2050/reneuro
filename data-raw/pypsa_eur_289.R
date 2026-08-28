# Builds `pypsa_eur_289`: PyPSA-Eur aggregated to NUTS2, full calendar.
#
# PyPSA-Eur is normally clustered to 50-250 nodes for computational reasons.
# This model sits at the top of that range: the NUTS3 network (1,035 AC buses)
# aggregated to NUTS2 with reneuro's own `aggregate_pypsa()`, rather than by a
# second PyPSA-Eur clustering run. 296 NUTS2 regions yield 289 AC nodes, since
# seven contain no substation and merge into a neighbour; their demand and
# generation are retained in the cluster they join.
#
# Aggregation follows PyPSA's own strategies: capacities sum, intensive
# quantities take capacity-weighted means, intra-cluster branches are dropped
# and corridor lengths are recomputed from cluster centroids.
#
# NOTE: the conversion functions currently live in the reneuro.dev workspace
# and are loaded from there until they move into this package.
suppressMessages(devtools::load_all("C:/Users/admin/Documents/R/useR/reneuro.dev",
                                    quiet = TRUE))
NC <- "C:/Users/admin/source/pypsa-eur-v2026/resources/entsoe-all/networks/base_s_1035_elec.nc"

n  <- suppressWarnings(read_pypsa(NC))
bm <- pypsa_busmap(n, nuts_gs, "nuts2")
a  <- aggregate_pypsa(n, bm, verbose = FALSE)
b  <- convert_pypsa(a, cost_source = "network", tranches = NULL,
                    transmission = "transport", verbose = FALSE)

pypsa_eur_289 <- b$model
usethis::use_data(pypsa_eur_289, overwrite = TRUE, compress = "xz")
