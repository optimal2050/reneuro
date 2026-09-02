# The full-year NUTS3 model ships without its weather: seven hourly profiles
# over 1,035 regions are most of its size, and split off, no shipped file
# exceeds GitHub's 100 MB limit. The technologies still reference them by name,
# so a model must have them attached before it is interpolated.

#' Weather resources of the full-year NUTS3 model
#'
#' The resource names [attach_weather()] accepts, in the order they are
#' attached. Each names a dataset `wx_nuts3_<resource>`.
#'
#' @return A character vector.
#' @examples
#' weather_resources()
#' @export
weather_resources <- function() {
  c("onwind", "offwind_ac", "offwind_dc", "offwind_float", "solar",
    "solar_hsat", "ror")
}

#' Attach weather profiles to a model
#'
#' `pypsa_eur_nuts3` ships without its hourly weather profiles, which are most
#' of its size. Its technologies still reference them by name, so the profiles
#' a run needs must be attached before it is interpolated.
#'
#' Attaching only what a study uses keeps the model small: a solar-and-onshore
#' analysis loads 75 MB rather than 182 MB.
#'
#' @param mod A `model`, normally `pypsa_eur_nuts3`.
#' @param resources Resource names to attach, from [weather_resources()].
#'   `NULL` (default) attaches all of them.
#'
#' @return `mod` with the requested `weather` objects added.
#'
#' @examples
#' \donttest{
#' m <- attach_weather(pypsa_eur_nuts3, c("onwind", "solar"))
#' names(energyRt::getObject(m, class = "weather"))
#' }
#' @export
attach_weather <- function(mod, resources = NULL) {
  if (!inherits(mod, "model")) stop("`mod` must be a model", call. = FALSE)
  known <- weather_resources()
  if (is.null(resources)) resources <- known
  resources <- as.character(resources)
  unknown <- setdiff(resources, known)
  if (length(unknown)) {
    stop("unknown weather resource(s): ", paste(unknown, collapse = ", "),
         ". One of: ", paste(known, collapse = ", "), call. = FALSE)
  }
  have <- names(energyRt::getObject(mod, class = "weather"))
  for (r in resources) {
    ds <- paste0("wx_nuts3_", r)
    w <- get(ds, envir = asNamespace("reneuro"))
    if (w@name %in% have) next
    mod <- energyRt::add(mod, w)
  }
  mod
}
