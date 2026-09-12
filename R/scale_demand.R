#' Build multi-year demand from a base-year profile and growth factors
#'
#' `grow_demand()` is the transparent core: it takes a `demand` object
#' whose `@demand` table holds a base-year profile (region x timeslice,
#' optionally year-keyed) and a plain growth-factor table, and writes one
#' profile per factor year — `demand * factor`, keyed by `year`. Nothing
#' else changes: the shape is the base year's, the factors are whatever
#' table you pass ([tyndp_demand] filtered to one scenario is one such
#' table, but any `(country|region, year, factor)` data frame works).
#'
#' `build_demand()` is the convenience wrapper: it pulls a demand object
#' out of a source model, optionally renames it and restricts it to
#' `regions`, and applies `grow_demand()` for the requested `years`.
#'
#' @param dem A `demand` object.
#' @param factors Data frame with columns `year`, `factor`, and either
#'   `region` (matched exactly) or `country` (matched to the first two
#'   letters of the region code).
#' @param base_year Year of the base profile in `dem@demand`. Rows with
#'   that year (or with `year` `NA`, the year-agnostic form) are the
#'   shape that grows; base-year demand is reproduced exactly where
#'   `factor == 1`.
#' @return The `demand` object with a year-keyed `@demand` table.
#' @examples
#' \dontrun{
#' ga <- subset(tyndp_demand, scenario == "GA")
#' d  <- grow_demand(getObjects(pypsa_eur_41)$DEM_ELC, ga, base_year = 2025)
#' }
#' @export
grow_demand <- function(dem, factors, base_year = 2025) {
  stopifnot(methods::is(dem, "demand"), is.data.frame(factors),
            all(c("year", "factor") %in% names(factors)))
  by_country <- !"region" %in% names(factors)
  if (by_country && !"country" %in% names(factors)) {
    stop("`factors` needs a `region` or `country` column")
  }
  d <- dem@demand
  base <- d[is.na(d$year) | d$year == base_year, , drop = FALSE]
  if (!nrow(base)) {
    stop("no base-year (", base_year, " or NA) rows in dem@demand")
  }
  key <- if (by_country) substr(base$region, 1, 2) else base$region

  grown <- do.call(rbind, lapply(sort(unique(factors$year)), function(y) {
    fy <- factors[factors$year == y, , drop = FALSE]
    kf <- if (by_country) fy$country else fy$region
    f <- fy$factor[match(key, kf)]
    if (anyNA(f)) {
      stop("no factor at year ", y, " for: ",
           paste(unique(key[is.na(f)]), collapse = ", "))
    }
    out <- base
    out$demand <- out$demand * f
    out$year <- y
    out
  }))
  dem@demand <- grown
  dem
}

#' @rdname grow_demand
#' @param name Name for the built demand object (default: keep the
#'   source object's name).
#' @param from Source model holding the base-year demand (default
#'   [pypsa_eur_41]).
#' @param years Optional years to keep (subset of `factors$year`);
#'   `NULL` uses every year in `factors`.
#' @param regions Optional region codes to keep.
#' @export
build_demand <- function(name = NULL, factors, base_year = 2025,
                         years = NULL, regions = NULL,
                         from = reneuro::pypsa_eur_41) {
  objs <- unlist(lapply(from@data, function(r) r@data), recursive = FALSE)
  dems <- Filter(function(o) methods::is(o, "demand"), objs)
  stopifnot(length(dems) >= 1)
  dem <- dems[[1]]
  if (!is.null(regions)) {
    dem@demand <- dem@demand[dem@demand$region %in% regions, , drop = FALSE]
    dem@region <- as.character(regions)
  }
  if (!is.null(years)) factors <- factors[factors$year %in% years, ]
  dem <- grow_demand(dem, factors, base_year = base_year)
  if (!is.null(name)) dem@name <- name
  dem
}
