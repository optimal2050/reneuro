# Build the shipped NUTS geoscale
# -----------------------------------------------------------------------------
#   RENEURO_PYPSA_EUR=/path/to/pypsa-eur Rscript data-raw/nuts_gs.R
#
# The object carries two families of per-region data on its leaftable, and the
# distinction between them decides which columns may serve as weights.
#
# GEOGRAPHIC, from PyPSA-Eur's nuts3_shapes.geojson: area, population and GDP.
# Defined for every one of the 1,477 NUTS3 regions.
#
# MODEL, from the NUTS3 network: demand, existing capacity and renewable
# potential. These are located at substation buses, and 442 regions contain
# none, so they are zero there. That is the model's own allocation -- a busless
# region's land and load were folded into the neighbour it clusters with -- not
# a statement about the region's geography.
#
# The AC bus names of base_s_1035_elec.nc are NUTS3 codes, so the model layer
# joins on the atom key directly.
#
# The three offwind potentials OVERLAP: 313 of the 314 offshore buses carry more
# than one type, being alternative ways to use the same sea area. They are kept
# as separate columns and never summed. solar and solar-hsat overlap the same
# way on land.

suppressPackageStartupMessages({
  library(data.table)
})
for (p in c("sf", "geoscales", "energyRt")) {
  if (!requireNamespace(p, quietly = TRUE)) stop("need the '", p, "' package")
}
# Conversion code still lives in the reneuro.dev workspace; see data-raw/README.
devtools::load_all(Sys.getenv("RENEURO_DEV",
                              "C:/Users/admin/Documents/R/useR/reneuro.dev"),
                   quiet = TRUE)

root <- Sys.getenv("RENEURO_PYPSA_EUR", unset = NA)
if (is.na(root) || !dir.exists(root)) {
  stop("set RENEURO_PYPSA_EUR to a PyPSA-Eur clone (got: ", root, ")")
}
nc <- file.path(root, "resources/entsoe-all/networks/base_s_1035_elec.nc")
if (!file.exists(nc)) stop("missing NUTS3 network at ", nc)

# ---- geographic base ---------------------------------------------------------
# Region codes, hierarchy, geometry and the shape-derived weights come from the
# base object built by data-raw/make_nuts.R. Only those columns are taken, so
# re-running this script rebuilds rather than accumulates.
load(file.path("data", "nuts_gs.rda"))
base_cols <- c("region", "europe", "nuts0", "nuts1", "nuts2", "nuts3",
               "km2", "pop", "gdp", "gdp_total")
lt <- as.data.table(geoscales::geoscale_leaftable(nuts_gs))
miss <- setdiff(base_cols, names(lt))
if (length(miss)) stop("geographic base is missing: ", paste(miss, collapse = ", "))
# The sfc in atom order, not geoscale_geometry(), which returns an sf keyed by
# geoframe and cannot be passed back to the constructor.
geom <- S7::prop(nuts_gs, "geometry")
prov_base <- attr(nuts_gs, "reneuro_provenance")
lt <- lt[, ..base_cols]
message("geographic base: ", nrow(lt), " atoms")

# ---- demand ------------------------------------------------------------------
# nuts_load already aggregates electricity_demand_base_s.nc against the
# unsimplified shapes; its NUTS3 rows are the atom-level values.
load(file.path("data", "nuts_load.rda"))
dem <- as.data.table(nuts_load)[level == "nuts3",
                                .(region, load_twh, peak_mw = peak_gw * 1e3,
                                  n_buses)]
lt <- merge(lt, dem, by = "region", all.x = TRUE, sort = FALSE)
message("demand joined: ", sum(!is.na(lt$load_twh)), " regions, ",
        sum(lt$n_buses == 0L, na.rm = TRUE), " with no substation")

# ---- model layer -------------------------------------------------------------
message("reading ", basename(nc), " ...")
n <- suppressWarnings(read_pypsa(nc))
ac <- n$static$buses$name[n$static$buses$carrier == "AC"]
if (!all(ac %in% lt$region)) {
  stop(sum(!ac %in% lt$region), " AC bus name(s) are not NUTS3 codes; the ",
       "network is not the NUTS3 clustering")
}
g  <- as.data.table(n$static$generators)[, .(bus, carrier, p_nom, p_nom_max)]
su <- as.data.table(n$static$storage_units)[, .(bus, carrier, p_nom)]

# Existing capacity: everything that can generate today, generators and hydro
# storage alike. p_nom is the built capacity; a purely extendable unit has zero.
cap <- rbind(g[, .(bus, carrier, p_nom)], su)[
  , .(cap_mw = sum(p_nom, na.rm = TRUE)), by = bus]
hyd <- rbind(g[carrier == "ror", .(bus, p_nom)], su[, .(bus, p_nom)])[
  , .(hydro_mw = sum(p_nom, na.rm = TRUE)), by = bus]

# Potential: p_nom_max is the land-availability limit for the expandable
# renewables and infinite for the rest, so non-finite values are dropped.
pot_of <- c(onwind = "onwind", solar = "solar", solar_hsat = "solar-hsat",
            offwind_ac = "offwind-ac", offwind_dc = "offwind-dc",
            offwind_float = "offwind-float")
pot <- g[is.finite(p_nom_max) & carrier %in% pot_of,
         .(mw = sum(p_nom_max, na.rm = TRUE)), by = .(bus, carrier)]
pot <- dcast(pot, bus ~ carrier, value.var = "mw", fill = 0)
setnames(pot, unname(pot_of), paste0("pot_", names(pot_of)), skip_absent = TRUE)

for (tb in list(cap, hyd, pot)) {
  lt <- merge(lt, tb, by.x = "region", by.y = "bus", all.x = TRUE, sort = FALSE)
}

# A region with no bus has no model quantity, which is zero and not unknown.
model_cols <- c("load_twh", "peak_mw", "n_buses", "cap_mw", "hydro_mw",
                paste0("pot_", names(pot_of)))
for (cl in model_cols) set(lt, which(is.na(lt[[cl]])), cl, 0)
message("model layer totals:\n", paste(sprintf("  %-16s %12.0f", model_cols,
        vapply(model_cols, function(k) sum(lt[[k]]), 0)), collapse = "\n"))

# ---- weights -----------------------------------------------------------------
# A weight splits a coarse quantity across its atoms and averages an intensive
# one back up, so a parent group whose weights sum to zero divides by zero. That
# is what is checked, not whether an individual atom is zero, which is harmless.
#
# The geographic weights are clean at every level. The model weights cannot be:
# a group containing no substation carries no demand, no capacity and no
# potential, so it sums to zero by construction. Those groups are exactly the
# ones that lose a node on aggregation -- 296 NUTS2 regions give 289 buses and
# 109 NUTS1 give 106. A few groups are degenerate for a second reason: Inner
# London has substations but no generation and no land the availability rules
# admit, so capacity and potential are genuinely zero there.
#
# Neither is patched. Substituting a plausible number would hide the defect
# exactly where it matters, so the degenerate groups are recorded on the object
# instead, queryable through attr(nuts_gs, "weight_degeneracy").
#
# The offshore potentials are excluded from the weight set altogether: they are
# zero for every landlocked country, which is most of them. So is hydro for a
# country without any. Both stay on the leaftable as data.
w_geo   <- c("km2", "pop", "gdp_total")
w_model <- c("load_twh", "cap_mw", "pot_onwind", "pot_solar")
weights <- c(w_geo, w_model)
setcolorder(lt, c(base_cols, model_cols))
ltd <- as.data.frame(lt)

zero_groups <- function(v, lvl) {
  tot <- tapply(v, ltd[[lvl]], sum, na.rm = TRUE)
  names(tot)[tot == 0]
}
levels_up <- c("nuts2", "nuts1", "nuts0", "europe")
busless <- lapply(levels_up, function(l) zero_groups(ltd$n_buses, l))
names(busless) <- levels_up
message("groups with no substation: ",
        paste(sprintf("%s %d", levels_up, lengths(busless)), collapse = ", "))

degeneracy <- list()
for (w in weights) {
  v <- ltd[[w]]
  # NA and negative values are defects in the source, not properties of it.
  if (anyNA(v)) stop("weight '", w, "': ", sum(is.na(v)), " NA", call. = FALSE)
  if (any(v < 0)) {
    stop("weight '", w, "': ", sum(v < 0), " negative", call. = FALSE)
  }
  z <- lapply(levels_up, function(l) zero_groups(v, l))
  names(z) <- levels_up
  z <- z[lengths(z) > 0]
  if (length(z)) degeneracy[[w]] <- z
  if (!length(z)) {
    message("weight '", w, "': clean")
  } else {
    extra <- vapply(names(z), function(l) length(setdiff(z[[l]], busless[[l]])), 0L)
    message("weight '", w, "': zero-sum in ",
            paste(sprintf("%d %s", lengths(z), names(z)), collapse = ", "),
            " group(s); ", sum(extra), " of them have a substation")
  }
}
if (length(degeneracy)) {
  hits <- unique(unlist(lapply(degeneracy, function(z)
    unlist(mapply(setdiff, z, busless[names(z)], SIMPLIFY = FALSE)))))
  if (length(hits)) message("degenerate despite a substation: ",
                            paste(sort(hits), collapse = ", "))
}

# ---- assemble ----------------------------------------------------------------
# Geometry is passed back in leaftable order, which the merges preserve
# (sort = FALSE on every one); the check below is the guard on that.
if (length(geom) != nrow(ltd)) stop("geometry no longer matches the leaftable")

nuts_gs <- geoscales::geoscale_from_leaftable(
  leaftable = ltd,
  geoframes = c("europe", "nuts0", "nuts1", "nuts2", "nuts3"),
  key = "region",
  weights = weights,
  default_weight = "km2",
  geometry = geom,
  name = "nuts",
  desc = paste("NUTS 2021 regions as used by PyPSA-Eur (adm1 for BA, MD, UA,",
               "XK), with population, GDP, demand, capacity and renewable",
               "potential per region"),
  crs = 4326,
  source = "PyPSA-Eur nuts3_shapes.geojson and base_s_1035_elec.nc"
)

cov <- geoscales::geoscale_coverage(nuts_gs)
message("coverage: ", paste(format(cov), collapse = ", "))

git <- function(...) suppressWarnings(tryCatch(
  system2("git", c("-C", root, ...), stdout = TRUE, stderr = FALSE),
  error = function(e) NA_character_))
attr(nuts_gs, "reneuro_provenance") <- list(
  clone = basename(normalizePath(root, winslash = "/", mustWork = FALSE)),
  commit = git("rev-parse", "HEAD")[1],
  built_on = as.character(Sys.Date()),
  object = "nuts_gs",
  source = c("nuts3_shapes.geojson", basename(nc)),
  simplify_keep = prov_base$simplify_keep,
  geographic_base = prov_base$built_on)
attr(nuts_gs, "weight_degeneracy") <- degeneracy

out <- file.path("data", "nuts_gs.rda")
save(nuts_gs, file = out, compress = "xz")
message(sprintf("saved %s  (%.2f MB, %d atoms, %d columns)",
                out, file.size(out) / 1024^2, nrow(ltd), ncol(ltd)))
