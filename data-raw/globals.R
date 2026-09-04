# Shared pieces for the per-model build scripts. Source this from each script:
#
#   source(file.path("data-raw", "globals.R"))
#
# Mirrors reneuro.dev/data-raw/globals.R + make_models.R:28-45, which attach
# provenance to everything they build; the scripts here did not, which is how
# `pypsa_eur_41` shipped one rebuild with the attribute empty and `_289`,
# `_1035` and `_nuts3` never had it at all.

PYPSA_EUR_ROOT <- "C:/Users/admin/source/pypsa-eur-v2026"

# Record which upstream commit and which data years an object was built from,
# so an .rda taken out of context can still say. The clone is recorded by NAME
# only: these objects ship, and an absolute path would carry the builder's
# home directory into the released data.
#
# The three years are set independently and are easy to conflate, so each is
# stated: `weather_year` is the meteorological year the profiles come from,
# `load_year` the demand year (identical to the weather year unless
# `load: fixed_year` decouples them), `capacity_year` the IRENASTAT reference
# year for the existing renewable fleet, and `cost_year` the technology-data
# vintage the costs and the planning horizon use.
reneuro_provenance <- function(object, source_nc,
                               convert_args = list(),
                               weather_year = NA_integer_,
                               load_year = weather_year,
                               capacity_year = NA_integer_,
                               cost_year = NA_integer_,
                               root = PYPSA_EUR_ROOT) {
  git <- function(...) suppressWarnings(tryCatch(
    system2("git", c("-C", root, ...), stdout = TRUE, stderr = FALSE),
    error = function(e) NA_character_))
  list(
    clone = basename(normalizePath(root, winslash = "/", mustWork = FALSE)),
    commit = git("rev-parse", "HEAD")[1],
    describe = git("describe", "--tags", "--always")[1],
    dirty = length(git("status", "--porcelain")) > 0,
    built_on = as.character(Sys.Date()),
    reneuro = as.character(utils::packageVersion("reneuro")),
    object = object,
    source = basename(source_nc),
    convert_args = convert_args,
    weather_year = weather_year,
    load_year = load_year,
    capacity_year = capacity_year,
    cost_year = cost_year
  )
}

# A model must not be saved without its provenance -- that is exactly how the
# attribute went missing before.
stop_if_no_provenance <- function(obj, name) {
  p <- attr(obj, "reneuro_provenance")
  if (is.null(p) || length(p) == 0L || is.null(p$commit)) {
    stop(name, " has no reneuro_provenance attribute; attach it with ",
         "reneuro_provenance() before use_data().", call. = FALSE)
  }
  invisible(obj)
}
