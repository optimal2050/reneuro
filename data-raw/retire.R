# Fleet ageing for the one-year `pypsa_eur_41_<YYYY>` builds.
#
# PyPSA-Eur's overnight mode carries the fleet un-aged: the static
# powerplants_filter keeps every unit without an announced DateOut, so a 2050
# network still holds the 2025 fleet. These helpers compute, per (bus,
# carrier), the capacity fraction surviving to a horizon year under two rules
# kept separable:
#
#   announced: DateOut <= Y                     (real phase-out schedules;
#                                                62/67% of coal/lignite units)
#   assumed:   no DateOut and DateIn + L <= Y   (L = carrier lifetime from the
#                                                horizon's cost table)
#
# Ageing is DateIn-based, matching PyPSA's own lifetime = DateOut - DateIn
# convention; DateRetrofit is ignored (a refinement, not implemented). Units
# with neither DateOut nor DateIn (3% of capacity) never retire.

# Carrier assignment replicating add_electricity.load_and_aggregate_powerplants
# (to_pypsa_names lower-cases Fueltype; then the two dicts; then hydro and
# natural gas resolve to their Technology). Rows that end with an NA carrier
# (e.g. Natural Gas with no Technology) are dropped there too.
plant_carriers <- function(ppl) {
  carrier <- tolower(ppl$Fueltype)
  cd <- c("ocgt" = "OCGT", "ccgt" = "CCGT", "bioenergy" = "biomass",
          "ccgt, thermal" = "CCGT", "hard coal" = "coal")
  hit <- carrier %in% names(cd)
  carrier[hit] <- cd[carrier[hit]]
  td <- c("Run-Of-River" = "ror", "Reservoir" = "hydro",
          "Pumped Storage" = "PHS")
  tech <- ppl$Technology
  hit <- tech %in% names(td)
  tech[hit] <- td[tech[hit]]
  carrier[carrier %in% c("hydro", "natural gas")] <-
    tech[carrier %in% c("hydro", "natural gas")]
  # wind resolves by Technology, as attach_renewable_powerplants'
  # technology_mapping does (Onshore -> onwind, Offshore -> offwind-ac)
  wd <- c("Onshore" = "onwind", "Offshore" = "offwind-ac")
  wind <- carrier == "wind" & tech %in% names(wd)
  carrier[wind] <- wd[tech[wind]]
  carrier[carrier == "wind"] <- NA
  carrier
}

# Surviving-capacity fractions at horizon `year`.
#
# ppl:        powerplants_s_41.csv as a data.frame
# year:       horizon (integer)
# lifetimes:  named numeric, carrier -> lifetime in years (from
#             costs_<Y>_processed.csv); carriers without an entry get no
#             assumed retirement
#
# Returns one row per (bus, carrier): total_mw, announced_mw, assumed_mw,
# frac (surviving share, in [0, 1]).
retirement_fractions <- function(ppl, year, lifetimes) {
  stopifnot(is.numeric(year), length(year) == 1L)
  d <- data.frame(
    bus = ppl$bus,
    carrier = plant_carriers(ppl),
    mw = ppl$Capacity,
    datein = suppressWarnings(as.numeric(ppl$DateIn)),
    dateout = suppressWarnings(as.numeric(ppl$DateOut))
  )
  d <- d[!is.na(d$carrier) & !is.na(d$bus) & d$mw > 0, ]
  d$life <- unname(lifetimes[d$carrier])
  announced <- !is.na(d$dateout) & d$dateout <= year
  assumed <- is.na(d$dateout) & !is.na(d$datein) & !is.na(d$life) &
    d$datein + d$life <= year
  agg <- function(x) stats::aggregate(
    mw ~ bus + carrier, data = transform(d, mw = mw * x), FUN = sum)
  out <- agg(rep(TRUE, nrow(d)))
  names(out)[3] <- "total_mw"
  a <- agg(announced); names(a)[3] <- "announced_mw"
  s <- agg(assumed);   names(s)[3] <- "assumed_mw"
  out <- merge(merge(out, a, all.x = TRUE), s, all.x = TRUE)
  out$frac <- pmax(0, 1 - (out$announced_mw + out$assumed_mw) / out$total_mw)
  out
}

# Scale a converted model's existing fleet by the fractions: `stock` (fixed
# capacity) and `cap.lo` (brownfield floors on extendable carriers) both
# shrink; upper bounds and everything else stay. `busmap` translates plant bus
# names to model regions (pypsa_name_to(maps$buses, .)).
#
# Returns list(model, applied): `applied` is the per-carrier GW summary that
# goes into provenance.
apply_retirement <- function(m, fr, busmap) {
  fr$region <- busmap(fr$bus)
  if (anyNA(fr$region)) {
    stop("unmapped plant buses: ",
         paste(utils::head(unique(fr$bus[is.na(fr$region)]), 5), collapse = ", "))
  }
  objs <- m@data[[1]]@data
  applied <- list()
  for (carrier in unique(fr$carrier)) {
    tech_nm <- paste0("E_", gsub("-", "_", toupper(carrier)))
    if (!tech_nm %in% names(objs)) next
    t <- objs[[tech_nm]]
    f <- fr[fr$carrier == carrier, ]
    key <- stats::setNames(f$frac, f$region)
    cl <- t@capacity
    frac <- key[cl$region]
    frac[is.na(frac)] <- 1
    changed <- FALSE
    if ("stock" %in% names(cl) && any(!is.na(cl$stock))) {
      cl$stock <- cl$stock * frac
      changed <- TRUE
    }
    if ("cap.lo" %in% names(cl) && any(!is.na(cl$cap.lo))) {
      cl$cap.lo <- cl$cap.lo * frac
      changed <- TRUE
    }
    if (changed) {
      t@capacity <- cl
      objs[[tech_nm]] <- t
      applied[[carrier]] <- c(
        announced_GW = sum(f$announced_mw) / 1e3,
        assumed_GW = sum(f$assumed_mw) / 1e3,
        total_GW = sum(f$total_mw) / 1e3
      )
    }
  }
  m@data[[1]]@data <- objs
  list(model = m, applied = applied)
}
