# EX41V re-solve: barrier + crossover (the crossover-off preset stopped
# near-optimal at this size; the public example needs a proven optimum).
#   Rscript data-raw/example_solve_41v.R
ENERGYRT <- Sys.getenv("ENERGYRT_SRC", "C:/Users/admin/Documents/R/energyRt")
suppressMessages(pkgload::load_all(ENERGYRT, quiet = TRUE))
suppressMessages(pkgload::load_all(".", quiet = TRUE))
open_project("projects/pypsa_eur")

s <- solver_options$julia_highs_barrier
s$inc3 <- sub('run_crossover", "off"', 'run_crossover", "on"', s$inc3, fixed = TRUE)
stopifnot(grepl('run_crossover", "on"', s$inc3, fixed = TRUE))

cal <- calendars$d365_h24_1dpm
m <- attach_weather(pypsa_eur_41v, from = pypsa_eur_41)
scen <- interpolate_model(m, cal, name = "EX41V", overwrite = TRUE)
scen <- write_script(scen, solver = s)
scen <- read_solution(solve_scenario(scen, wait = TRUE))
obj <- getData(scen, "vObjective", merge = TRUE)$value
stopifnot(length(obj) == 1L, is.finite(obj))
v <- verify_solution(scen)
message("EX41V objective: ", format(obj, digits = 10),
        " | verify ok: ", isTRUE(v$ok))
if (!isTRUE(v$ok)) stop("EX41V still not verifying -- do not ship")
save_scenario(scen, embed_model = TRUE)
message("EX41V solved and saved (crossover)")
