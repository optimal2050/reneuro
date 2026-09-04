# Renders the two example reports the report articles embed.
#
#   Rscript data-raw/example_reports.R
#
# They are committed under pkgdown/assets/reports/, which init_site() copies to
# docs/reports/. They are NOT built by pkgdown/build.R: the scenario report
# needs a solve, and a solve does not belong in a site build.
#
# Both use `pypsa_eur_41` -- large enough that a report has something to show,
# small enough to render in seconds. The scenario is solved on a sampled
# calendar (one day per month, 288 of 8,760 hours), which keeps every region
# and process while making the solve tractable.
#
# Budget about five minutes: ~35 s to interpolate and ~4 min to solve.
ENERGYRT <- Sys.getenv("ENERGYRT_SRC", "C:/Users/admin/Documents/R/energyRt")
suppressMessages(pkgload::load_all(ENERGYRT, quiet = TRUE))
suppressMessages(pkgload::load_all(".", quiet = TRUE))

OUT <- "pkgdown/assets/reports"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

# ---- the model: assumptions --------------------------------------------------
message("model report ...")
report(pypsa_eur_41, template = "model",
       file = file.path(OUT, "pypsa_eur_41_model.html"),
       format = "html", open = FALSE, force = TRUE)

# ---- the scenario: results ---------------------------------------------------
# The Arrow exchange writes one file per symbol and a generated variant
# constraint has a long name, so under a deep scenarios directory the paths
# reach Windows' 260-character limit and the solve fails on a missing path.
# Hence a shallow root.
ROOT <- file.path(dirname(tempdir()), "e41")
dir.create(ROOT, showWarnings = FALSE, recursive = TRUE)
set_scenarios_path(ROOT)

# The sample goes to interpolate_model(), not onto the model: the model keeps
# its full-year calendar and only this scenario is restricted. The sample
# shortens the solve, not the interpolation -- parameters are interpolated and
# only then filtered to the declared timeslices.
cal <- calendars$d365_h24_subset_1day_per_month
message("interpolating on the sampled calendar (~35 s) ...")
scen <- interpolate_model(pypsa_eur_41, cal, name = "eur41_m12")

# GLPK was still iterating after ten minutes at this size; the barrier closes
# it in under four.
if (!isTRUE(.backend_available("JuMP"))) {
  stop("this needs Julia + HiGHS: GLPK does not converge at this size in ",
       "reasonable time")
}
message("solving (barrier) ...")
scen <- write_script(scen, solver = solver_options$julia_highs_barrier)
scen <- read_solution(solve_scenario(scen, wait = TRUE))

obj <- getData(scen, "vObjective", merge = TRUE)$value
if (length(obj) != 1L || !is.finite(obj)) {
  stop("the example scenario did not solve; refusing to ship a report of it")
}
message("  objective: ", format(obj, digits = 10))

message("scenario report ...")
report(scen, template = "scenario",
       file = file.path(OUT, "pypsa_eur_41_scenario.html"),
       format = "html", open = FALSE, force = TRUE)

# The sidecars are render bookkeeping, not site content.
unlink(list.files(OUT, pattern = "[.]report[.]yml$", full.names = TRUE))
for (f in list.files(OUT, full.names = TRUE)) {
  message(sprintf("  %-34s %5.2f MB", basename(f), file.size(f) / 1024^2))
}
