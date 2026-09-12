# Public example solves of the shipped models on the sampled calendar
# (one day per month), local Julia/HiGHS — the reproducible-by-readers
# runs behind the site's numbers.
#
#   Rscript data-raw/example_solves.R
#
# Three scenarios into the project store (save_scenario, embed_model):
#   EX41       pypsa_eur_41       single planning year, own weather
#   EX41_2050  pypsa_eur_41_2050  2050 horizon, weather from pypsa_eur_41
#   EX41V      pypsa_eur_41v      2025-2050 vintaged pathway, same weather
ENERGYRT <- Sys.getenv("ENERGYRT_SRC", "C:/Users/admin/Documents/R/energyRt")
suppressMessages(pkgload::load_all(ENERGYRT, quiet = TRUE))
suppressMessages(pkgload::load_all(".", quiet = TRUE))
open_project("projects/pypsa_eur")

cal <- calendars$d365_h24_1dpm

run1 <- function(m, nm, solver = solver_options$julia_highs_barrier) {
  message("== ", nm, " ==")
  t0 <- proc.time()[["elapsed"]]
  scen <- interpolate_model(m, cal, name = nm, overwrite = TRUE)
  message(sprintf("interpolated in %.1f min",
                  (proc.time()[["elapsed"]] - t0) / 60))
  scen <- write_script(scen, solver = solver)
  scen <- read_solution(solve_scenario(scen, wait = TRUE))
  obj <- getData(scen, "vObjective", merge = TRUE)$value
  stopifnot(length(obj) == 1L, is.finite(obj))
  v <- verify_solution(scen)
  message(nm, " objective: ", format(obj, digits = 10),
          " | verify ok: ", isTRUE(v$ok))
  save_scenario(scen, embed_model = TRUE)
  message(nm, " solved and saved")
  invisible(obj)
}

run1(pypsa_eur_41, "EX41")
run1(attach_weather(pypsa_eur_41_2050, from = pypsa_eur_41), "EX41_2050")
run1(attach_weather(pypsa_eur_41v, from = pypsa_eur_41), "EX41V")

message("all example solves done")
