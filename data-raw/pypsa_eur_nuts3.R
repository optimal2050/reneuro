# Builds `pypsa_eur_nuts3` and its seven weather objects: PyPSA-Eur at NUTS3
# resolution over the full year, 8,760 hourly snapshots.
#
# Source network: base_s_1035_elec.nc, built from a PyPSA-Eur clone with
# clustering.mode = custom_busmap and the NUTS3 busmap in data/busmaps/.
# NUTS3 yields 1,035 clusters rather than 1,477 because 442 NUTS3 regions
# contain no substation.
#
# THE WEATHER SHIPS SEPARATELY. Seven hourly profiles over 1,035 regions are
# 987 MB of the model's 1,431 MB in memory, and the whole of it saves to 181 MB
# -- past GitHub's 100 MB per-file limit. Split, no file exceeds 48 MB and the
# model is usable without loading profiles it does not need. `attach_weather()`
# puts them back.
#
# `nuts_gs` is attached to the model, so `aggregate_model_regions(m, level =
# "nuts1")` needs no second argument. That costs 0.44 MB and is what makes the
# coarser levels derivable rather than shipped.
#
# Trade uses one flat loss rate per corridor (tranches = NULL) and a transport
# formulation without Kirchhoff's voltage law.
#
# NOTE: the conversion functions currently live in the reneuro.dev workspace
# and are loaded from there until they move into this package.
suppressMessages(devtools::load_all("C:/Users/admin/Documents/R/useR/reneuro.dev",
                                    quiet = TRUE))
suppressMessages(library(energyRt))
NC <- "C:/Users/admin/source/pypsa-eur-v2026/resources/entsoe-all/networks/base_s_1035_elec.nc"

n <- suppressWarnings(read_pypsa(NC))
b <- convert_pypsa(n, cost_source = "network", tranches = NULL,
                   transmission = "transport", verbose = FALSE)
m <- b$model

load(file.path("data", "nuts_gs.rda"))
atoms <- as.character(geoscales::geoscale_regions(nuts_gs, "nuts3"))
miss <- setdiff(get_region(m), atoms)
if (length(miss)) {
  stop("the geoscale does not cover ", length(miss), " model region(s): ",
       paste(utils::head(miss, 6), collapse = ", "),
       ". data-raw/nuts_gs.R must key it the way convert_pypsa() keys a model.")
}
m <- setGeoscale(m, nuts_gs)

# ---- split the weather off ---------------------------------------------------
objs <- m@data[[1]]@data
cls <- vapply(objs, function(o) class(o)[1], "")
wx <- objs[cls == "weather"]
if (length(wx) == 0L) stop("no weather objects to split")

m@data[[1]]@data <- objs[cls != "weather"]
pypsa_eur_nuts3 <- m
usethis::use_data(pypsa_eur_nuts3, overwrite = TRUE, compress = "xz")

# One object per resource, named for the resource rather than for the object it
# holds, so `attach_weather(m, "onwind")` reads as the user thinks of it.
for (nm in names(wx)) {
  ds <- paste0("wx_nuts3_", tolower(sub("^W_", "", nm)))
  assign(ds, wx[[nm]])
  do.call(usethis::use_data,
          list(as.name(ds), overwrite = TRUE, compress = "xz"))
}

message("wrote pypsa_eur_nuts3 and ", length(wx), " weather object(s): ",
        paste(paste0("wx_nuts3_", tolower(sub("^W_", "", names(wx)))),
              collapse = ", "))
