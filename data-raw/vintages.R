# Fleet vintaging for the multi-year model `pypsa_eur_41v`.
#
# Bins every plant into PyPSA's `grouping_years_power` build-year bins and
# derives, per (region, carrier, bin), the surviving-stock series over the
# model milestones. Retirement combines the two rules of data-raw/retire.R,
# kept separable: announced `DateOut` where a unit has one, otherwise the
# unit's own `DateIn` plus the carrier lifetime. A unit with neither date
# never retires.
#
# Per-vintage efficiencies come from the cost table of the bin year, clamped
# to the earliest available vintage (the tables ship 2025-2050 here; PyPSA's
# add_existing_baseyear clamps the same way).

source(file.path("data-raw", "retire.R"))   # plant_carriers()

GROUPING_YEARS <- c(1920L, 1950L, 1955L, 1960L, 1965L, 1970L, 1975L, 1980L,
                    1985L, 1990L, 1995L, 2000L, 2005L, 2010L, 2015L, 2020L,
                    2025L)

# Bin label for a build year: the LAST grouping year <= DateIn (PyPSA's
# convention); units older than the first bin fall into it.
vintage_bin <- function(datein) {
  i <- findInterval(datein, GROUPING_YEARS)
  GROUPING_YEARS[pmax(i, 1L)]
}

# Surviving-stock series per (bus, carrier, bin, milestone).
#
# ppl:        powerplants table (Fueltype/Technology/Capacity/DateIn/DateOut)
# milestones: integer model years
# lifetimes:  named numeric, carrier -> lifetime years
#
# Returns one row per (bus, carrier, bin, year): stock plus the announced /
# assumed / undated split of what has retired by that year.
vintage_stock <- function(ppl, milestones, lifetimes) {
  d <- data.frame(
    bus = ppl$bus,
    carrier = plant_carriers(ppl),
    mw = ppl$Capacity,
    datein = suppressWarnings(as.numeric(ppl$DateIn)),
    dateout = suppressWarnings(as.numeric(ppl$DateOut))
  )
  d <- d[!is.na(d$carrier) & !is.na(d$bus) & d$mw > 0, ]
  # undated units go to the oldest bin and never retire (no basis to age them)
  d$bin <- ifelse(is.na(d$datein), GROUPING_YEARS[1], vintage_bin(d$datein))
  d$life <- unname(lifetimes[d$carrier])
  d$out_year <- ifelse(!is.na(d$dateout), d$dateout,
                       ifelse(!is.na(d$datein) & !is.na(d$life),
                              d$datein + d$life, Inf))
  d$rule <- ifelse(!is.na(d$dateout), "announced",
                   ifelse(is.finite(d$out_year), "assumed", "undated"))

  out <- do.call(rbind, lapply(milestones, function(y) {
    alive <- d$out_year > y
    agg <- stats::aggregate(mw ~ bus + carrier + bin, data = d[alive, ],
                            FUN = sum)
    if (nrow(agg) == 0) return(NULL)
    agg$year <- y
    agg
  }))
  names(out)[names(out) == "mw"] <- "stock"

  split <- stats::aggregate(mw ~ carrier + bin + rule, data = d, FUN = sum)
  list(stock = out, retirement_rules = split, units = d)
}

# Per-vintage efficiency: the cost table of max(bin, earliest available).
vintage_efficiency <- function(cost_dir, bins, carriers,
                               years = c(2025L, 2030L, 2035L, 2040L, 2045L,
                                         2050L)) {
  tabs <- lapply(years, function(y) {
    utils::read.csv(file.path(cost_dir, sprintf("costs_%d_processed.csv", y)),
                    check.names = FALSE)
  })
  names(tabs) <- years
  out <- expand.grid(carrier = carriers, bin = bins, stringsAsFactors = FALSE)
  out$cost_year <- pmax(pmin(out$bin, max(years)), min(years))
  out$eff <- mapply(function(cr, cy) {
    t <- tabs[[as.character(cy)]]
    v <- t$efficiency[t$technology == cr]
    if (length(v)) v[1] else NA_real_
  }, out$carrier, out$cost_year)
  out
}
