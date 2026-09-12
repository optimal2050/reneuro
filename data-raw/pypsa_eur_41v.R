# Builds `pypsa_eur_41v`: the vintaged multi-year model, 2025-2050.
#
# Scaffold (regions, commodities, supplies, demand, weather, storage, trade,
# geoscale) comes from the 2025 conversion; the generator fleet is replaced
# by ONE vintaged technology per carrier: a single `STOCK` vintage carrying
# the fleet's summed surviving-stock path (the 17 build-year bins are
# parameter-flat -- fleet_agg.csv clustering found k = 1 for every type --
# so bins would be pure overhead), plus open investment paths: per-assumption-
# year `NEW<year>` vintage windows with FROZEN efficiency where the cost
# tables move a real parameter (gas), a single year-keyed-eac `NEW` path for
# cost-only carriers (VRE). Retirement of the existing fleet is exogenous,
# from announced DateOut where units have one and the unit's DateIn + carrier
# lifetime elsewhere; both halves are separable in provenance. Demand is held
# flat at the measured 2025 year. Weather ships separately:
# `attach_weather(pypsa_eur_41v, from = pypsa_eur_41)`.
suppressMessages(devtools::load_all("C:/Users/admin/Documents/R/useR/reneuro.dev",
                                    quiet = TRUE))
suppressMessages(library(energyRt))
source(file.path("data-raw", "globals.R"))
source(file.path("data-raw", "vintages.R"))
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || is.na(x)) y else x

ROOT <- "C:/Users/admin/source/pypsa-eur-v2026/resources/entsoe-2025"
NC   <- file.path(ROOT, "networks/base_s_41_elec_y2025.nc")
CS   <- file.path(ROOT, "costs_2025_processed.csv")
MILESTONES <- seq(2025L, 2050L, 5L)

# ---- scaffold ----------------------------------------------------------------
n <- suppressWarnings(read_pypsa(NC))
b <- convert_pypsa(n, cost_source = "network", tranches = NULL,
                   transmission = "transport", costs = CS,
                   name = "PYPSA_EUR_41V", verbose = FALSE)
m <- b$model
maps <- pypsa_namemaps(n)
reg_of <- function(bus) pypsa_name_to(maps$buses, bus)

objs <- m@data[[1]]@data
cls <- vapply(objs, function(z) class(z)[1], "")

# ---- fleet vintaging ---------------------------------------------------------
ppl <- utils::read.csv(file.path(ROOT, "powerplants_s_41.csv"))
costs_tab <- lapply(MILESTONES, function(y) {
  utils::read.csv(file.path(ROOT, sprintf("costs_%d_processed.csv", y)),
                  check.names = FALSE)
})
names(costs_tab) <- MILESTONES
lifetimes <- stats::setNames(costs_tab[["2025"]]$lifetime,
                             costs_tab[["2025"]]$technology)
for (ow in c("offwind-ac", "offwind-dc", "offwind-float")) {
  if (!ow %in% names(lifetimes)) lifetimes[[ow]] <- lifetimes[["offwind"]]
}
vs <- vintage_stock(ppl, MILESTONES, lifetimes)
vs$stock$region <- reg_of(vs$stock$bus)
stopifnot(!anyNA(vs$stock$region))

# ---- year-keyed costs --------------------------------------------------------
# Open-path eac per (carrier, region, build year) from the horizon-series
# networks (each carries its cost vintage's annuitized capital_cost).
gen_eac <- do.call(rbind, lapply(MILESTONES, function(y) {
  ny <- suppressWarnings(read_pypsa(
    file.path(ROOT, sprintf("networks/base_s_41_elec_y%d.nc", y))))
  g <- as.data.frame(ny$static$generators)
  g <- g[g$p_nom_extendable %in% TRUE & g$capital_cost > 0, ]
  data.frame(carrier = g$carrier, region = reg_of(g$bus), year = y,
             eac = g$capital_cost)
}))
gen_eac <- stats::aggregate(eac ~ carrier + region + year, gen_eac, mean)

# Fuel price per operating year: the cost table carries it on a
# representative converting technology's row.
FUEL_TECH <- c(SUP_GAS = "CCGT", SUP_COA = "coal", SUP_LIG = "lignite",
               SUP_OIL = "oil", SUP_NUC = "nuclear", SUP_BIO = "biomass")
fuel_px <- do.call(rbind, lapply(MILESTONES, function(y) {
  cs <- costs_tab[[as.character(y)]]
  data.frame(sup = names(FUEL_TECH), year = y,
             cost = cs$fuel[match(FUEL_TECH, cs$technology)])
}))

# ---- surgery: flat demand, constant network, year-keyed supplies -------------
for (nm in names(objs)[cls == "demand"]) {
  objs[[nm]]@demand$year <- NA_integer_
}
# capacities were converted with year = 2025, and stock does NOT forward-fill:
# a single dated row zeroes every later milestone. The network and storage
# fleet are constant across the horizon (their expansion is a scenario knob).
for (nm in names(objs)[cls == "trade"]) {
  cl <- objs[[nm]]@capacity
  if ("year" %in% names(cl)) cl$year <- NA_integer_
  objs[[nm]]@capacity <- cl
}
for (nm in names(objs)[cls == "storage"]) {
  s <- objs[[nm]]
  cl <- s@capacity
  if (nrow(cl) > 0 && "year" %in% names(cl)) {
    cl$year <- NA_integer_
    s@capacity <- cl
  }
  objs[[nm]] <- s
}
for (nm in intersect(names(objs)[cls == "supply"], names(FUEL_TECH))) {
  s <- objs[[nm]]
  base <- s@supply[1, , drop = FALSE]
  px <- fuel_px[fuel_px$sup == nm & !is.na(fuel_px$cost), ]
  if (nrow(px) == 0) next
  s@supply <- do.call(rbind, lapply(seq_len(nrow(px)), function(k) {
    r <- base; r$year <- px$year[k]; r$cost <- px$cost[k]; r
  }))
  objs[[nm]] <- s
}

# ---- surgery: vintaged technologies ------------------------------------------
# Semantics (rework 2026-09-09):
#  * LEGACY fleet = ONE `STOCK` vintage per carrier (fleet_agg.csv clustered
#    the 17 bins on the full parameter vector and found k = 1 for every type:
#    the bins are parameter-flat by the 2025 cost-table clamp), carrying the
#    SUMMED announced+assumed surviving-stock path over the bins.
#  * FUTURE builds where the assumption tables change a real parameter
#    (efficiency): one vintage WINDOW per assumption year (`NEW2025` ...
#    `NEW2050`), start/end = the build window, cinp2use and olife FROZEN from
#    that year's table, eac constant within the window. Year-keyed efficiency
#    inside one vintage would read as free retrofit of standing capacity.
#  * Cost-only carriers (VRE): a single implicit-cohort `NEW` path with
#    year-keyed eac stays correct (eac charges at build; nothing else varies).
EXT <- c("CCGT", "OCGT", "onwind", "offwind-ac", "offwind-dc",
         "offwind-float", "solar", "solar-hsat")
tech_of <- function(carrier) paste0("E_", gsub("-", "_", toupper(carrier)))
carriers <- unique(vs$stock$carrier)
carriers <- carriers[tech_of(carriers) %in% names(objs)]

# Legacy-fleet parameters per type from the clustering table; the rework
# stands on k = 1 everywhere — stop loudly if a rebuild ever finds spread.
fagg <- utils::read.csv(file.path("data-raw", "fleet_agg.csv"))
if (any(fagg$fcluster != 1)) {
  stop("fleet_agg.csv reports k > 1 for: ",
       paste(unique(fagg$type[fagg$fcluster != 1]), collapse = ", "),
       " — the single-STOCK-vintage assembly below needs a per-cluster split.")
}
stock_eff <- vapply(split(fagg, fagg$type), function(d) {
  stats::weighted.mean(d$eff, d$stock_2025, na.rm = TRUE)
}, numeric(1))

# Per-window olife from each assumption year's table.
life_of_year <- function(carrier, y) {
  cs <- costs_tab[[as.character(y)]]
  v <- cs$lifetime[cs$technology == carrier]
  if (length(v) && is.finite(v[1])) as.integer(round(v[1]))
  else as.integer(round(lifetimes[carrier] %||% 30))
}

for (carrier in carriers) {
  tn <- tech_of(carrier)
  t <- objs[[tn]]
  # the converter leaves all-NA year columns as logical; update() type-checks
  # new data against the slot's current classes
  for (sl in c("invcost", "ceff", "capacity", "varom", "fixom")) {
    d <- methods::slot(t, sl)
    if ("year" %in% names(d) && is.logical(d$year)) {
      d$year <- as.integer(d$year)
      methods::slot(t, sl) <- d
    }
  }
  fleet <- vs$stock[vs$stock$carrier == carrier, ]
  # Plants can sit in regions the network's technology does not cover. A
  # weather-driven technology must NOT gain regions (no availability profile
  # there would mean an unconstrained one); others extend their scope.
  extra <- setdiff(unique(fleet$region), t@region)
  if (length(extra)) {
    if (nrow(t@weather) > 0) {
      lost <- sum(fleet$stock[fleet$region %in% extra & fleet$year == 2025])
      message(sprintf("%s: dropping %.0f MW in %d region(s) without a weather profile (%s)",
                      tn, lost, length(extra), paste(extra, collapse = ", ")))
      fleet <- fleet[!fleet$region %in% extra, ]
    } else {
      t@region <- sort(union(t@region, extra))
    }
  }
  is_ext <- carrier %in% EXT

  # A carrier is WINDOWED when its assumption tables move efficiency across
  # the horizon; the rest of the investables are cost-only.
  ye <- vintage_efficiency(ROOT, MILESTONES, carrier)
  ye <- ye[!is.na(ye$eff), ]
  windowed <- is_ext && nrow(ye) > 1 &&
    (max(ye$eff) - min(ye$eff)) > 1e-6

  # vintage table: the aggregated legacy fleet, then the open path(s).
  # STOCK decline is driven entirely by the stock series (olife stays NA).
  vin <- data.frame(vintage = "STOCK", end = 2024L)
  if (is_ext) {
    if (windowed) {
      wy <- sort(ye$bin)   # assumption years with a table value
      vin <- dplyr::bind_rows(vin, data.frame(
        vintage = sprintf("NEW%d", wy),
        start = as.integer(wy),
        end = c(as.integer(wy[-1] - 1L), NA_integer_),
        olife = vapply(wy, function(y) life_of_year(carrier, y), integer(1))))
    } else {
      vin <- dplyr::bind_rows(vin, data.frame(
        vintage = "NEW", start = 2025L,
        olife = as.integer(round(lifetimes[carrier] %||% 30))))
    }
  }

  # capacity: the summed surviving-stock path of the legacy fleet; regional
  # potentials become TOTAL bounds across vintages
  path <- stats::aggregate(stock ~ region + year, data = fleet, FUN = sum)
  cap <- data.frame(vintage = "STOCK", region = path$region,
                    year = path$year, stock = path$stock)
  old <- t@capacity
  if (is_ext && "cap.up" %in% names(old) && any(is.finite(old$cap.up))) {
    up <- old[is.finite(old$cap.up), c("region", "cap.up"), drop = FALSE]
    cap <- dplyr::bind_rows(cap, data.frame(
      vintage = "TOTAL", region = up$region, cap.up = up$cap.up))
  }

  args <- list(t, vintage = vin, capacity = cap)

  # per-vintage fuel efficiency (fuel-burning carriers only): the STOCK
  # vintage carries the capacity-weighted legacy value; each window carries
  # its table year's value, CONSTANT within the vintage (no year key).
  ce <- t@ceff
  if (nrow(ce) > 0 && any(!is.na(ce$cinp2use))) {
    base <- ce[!is.na(ce$cinp2use), ][1, c("comm", "cinp2use"), drop = FALSE]
    se <- if (tn %in% names(stock_eff) && is.finite(stock_eff[[tn]])) {
      stock_eff[[tn]]
    } else base$cinp2use
    rows <- data.frame(vintage = "STOCK", comm = base$comm, cinp2use = se)
    if (is_ext) {
      if (windowed) {
        rows <- dplyr::bind_rows(rows, data.frame(
          vintage = sprintf("NEW%d", ye$bin), comm = base$comm,
          cinp2use = ye$eff))
      } else {
        rows <- dplyr::bind_rows(rows, data.frame(
          vintage = "NEW", comm = base$comm, cinp2use = ye$eff[1]))
      }
    }
    # free-retrofit guard: efficiency must never be year-keyed in a vintage
    stopifnot(!"year" %in% names(rows))
    args$ceff <- rows
  }

  # open-path investment: windowed carriers freeze the window year's eac;
  # cost-only carriers keep the year-keyed build-year annuity (implicit
  # cohorts price correctly when ONLY cost varies).
  if (is_ext) {
    ge <- gen_eac[gen_eac$carrier == carrier, ]
    if (windowed) {
      gw <- ge[ge$year %in% ye$bin, ]
      args$invcost <- data.frame(vintage = sprintf("NEW%d", gw$year),
                                 region = gw$region, eac = gw$eac)
    } else {
      args$invcost <- data.frame(vintage = "NEW", region = ge$region,
                                 year = ge$year, eac = ge$eac)
    }
  } else {
    args$invcost <- data.frame(invcost = numeric(0))
  }

  objs[[tn]] <- do.call(energyRt::update, args)
}

# ---- model-level: horizon, weather split, ship -------------------------------
m@data[[1]]@data <- objs
m <- setHorizon(m, period = 2021:2050, intervals = rep(5L, 6L),
                mid_is_end = TRUE, force_BY_interval_to_1_year = FALSE)
stopifnot(identical(as.integer(m@config@horizon@intervals$mid), MILESTONES))

objs <- m@data[[1]]@data
cls <- vapply(objs, function(z) class(z)[1], "")
m@data[[1]]@data <- objs[cls != "weather"]
pypsa_eur_41v <- m

attr(pypsa_eur_41v, "reneuro_provenance") <- c(reneuro_provenance(
  object = "pypsa_eur_41v", source_nc = NC,
  convert_args = list(cost_source = "network", tranches = NULL,
                      transmission = "transport", costs = basename(CS)),
  weather_year = 2025L, capacity_year = NA_integer_, cost_year = 2025L),
  list(milestones = MILESTONES,
       vintages = vs$retirement_rules,
       legacy_fleet = paste(
         "one STOCK vintage per carrier (fleet_agg.csv: k = 1 for every",
         "type); capacity path = announced + assumed retirement summed over",
         "build-year bins; efficiency = capacity-weighted legacy value"),
       future_builds = paste(
         "NEW<year> vintage windows with frozen per-table efficiency for",
         "carriers whose assumption tables move it (gas); single NEW path",
         "with year-keyed eac for cost-only carriers (VRE)"),
       demand = "flat 2025",
       weather = "stripped; attach_weather(m, from = pypsa_eur_41)"))
stop_if_no_provenance(pypsa_eur_41v, "pypsa_eur_41v")

usethis::use_data(pypsa_eur_41v, overwrite = TRUE, compress = "xz")
message("pypsa_eur_41v: ", length(m@data[[1]]@data), " objects, ",
        length(carriers), " vintaged carriers")
