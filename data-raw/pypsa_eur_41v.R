# Builds `pypsa_eur_41v`: the vintaged multi-year model, 2025-2050.
#
# Scaffold (regions, commodities, supplies, demand, weather, storage, trade,
# geoscale) comes from the 2025 conversion; the generator fleet is replaced
# by ONE vintaged technology per carrier -- 17 build-year bins with per-bin
# efficiency and a surviving-stock series over the milestones, plus one open
# "new" vintage carrying year-keyed investment costs (build-year EAC is
# automatic). Retirement of the existing fleet is exogenous, from announced
# DateOut where units have one and the unit's DateIn + carrier lifetime
# elsewhere; both halves are separable in provenance. Demand is held flat at
# the measured 2025 year. Weather ships separately:
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
                   transmission = "transport", costs = CS, verbose = FALSE)
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
veff <- vintage_efficiency(ROOT, GROUPING_YEARS, unique(vs$stock$carrier))

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
EXT <- c("CCGT", "OCGT", "onwind", "offwind-ac", "offwind-dc",
         "offwind-float", "solar", "solar-hsat")
tech_of <- function(carrier) paste0("E_", gsub("-", "_", toupper(carrier)))
carriers <- unique(vs$stock$carrier)
carriers <- carriers[tech_of(carriers) %in% names(objs)]
vlab <- function(b) sprintf("v%d", b)

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
  bins <- sort(unique(fleet$bin))
  is_ext <- carrier %in% EXT

  # vintage table: closed legacy bins; extendables add the open "new" path.
  # Bin decline is driven entirely by the stock series (olife stays NA).
  vin <- data.frame(vintage = vlab(bins), end = 2024L)
  if (is_ext) {
    vin <- dplyr::bind_rows(vin, data.frame(
      vintage = "new", start = 2025L,
      olife = as.integer(round(lifetimes[carrier] %||% 30))))
  }

  # capacity: per-bin surviving stock series; regional potentials become
  # TOTAL bounds across vintages
  cap <- data.frame(vintage = vlab(fleet$bin), region = fleet$region,
                    year = fleet$year, stock = fleet$stock)
  old <- t@capacity
  if (is_ext && "cap.up" %in% names(old) && any(is.finite(old$cap.up))) {
    up <- old[is.finite(old$cap.up), c("region", "cap.up"), drop = FALSE]
    cap <- dplyr::bind_rows(cap, data.frame(
      vintage = "TOTAL", region = up$region, cap.up = up$cap.up))
  }

  args <- list(t, vintage = vin, capacity = cap)

  # per-vintage fuel efficiency (fuel-burning carriers only)
  ce <- t@ceff
  if (nrow(ce) > 0 && any(!is.na(ce$cinp2use))) {
    base <- ce[!is.na(ce$cinp2use), ][1, c("comm", "cinp2use"), drop = FALSE]
    ve <- veff[veff$carrier == carrier & veff$bin %in% bins & !is.na(veff$eff), ]
    rows <- data.frame(vintage = vlab(ve$bin), comm = base$comm,
                       cinp2use = ve$eff)
    if (is_ext) {
      ye <- vintage_efficiency(ROOT, MILESTONES, carrier)
      ye <- ye[!is.na(ye$eff), ]
      rows <- dplyr::bind_rows(rows, data.frame(
        vintage = "new", year = ye$bin, comm = base$comm, cinp2use = ye$eff))
    }
    args$ceff <- rows
  }

  # open path investment: year-keyed eac -> build-year annuities
  if (is_ext) {
    ge <- gen_eac[gen_eac$carrier == carrier, ]
    args$invcost <- data.frame(vintage = "new", region = ge$region,
                               year = ge$year, eac = ge$eac)
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
       efficiency_clamp = "bins before 2025 use the 2025 cost table",
       demand = "flat 2025",
       weather = "stripped; attach_weather(m, from = pypsa_eur_41)"))
stop_if_no_provenance(pypsa_eur_41v, "pypsa_eur_41v")

usethis::use_data(pypsa_eur_41v, overwrite = TRUE, compress = "xz")
message("pypsa_eur_41v: ", length(m@data[[1]]@data), " objects, ",
        length(carriers), " vintaged carriers")
