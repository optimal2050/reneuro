# Scenario report

A scenario report documents what came **out** of a run: solve status and
objective, the generation, capacity and new-capacity mixes, a sub-annual
dispatch profile, emissions and costs, and the
[`verify_solution()`](https://energyRt.org/reference/verify_solution.html)
checks. It is the counterpart of `vignette("report-model")`, which
documents the assumptions going in.

The one below is `pypsa_eur_41` solved on a sampled calendar — one day
per month, 288 of the 8,760 hours — which keeps every region and process
while making the solve tractable:

``` r

library(energyRt)
library(reneuro)

cal  <- calendars$d365_h24_1dpm
scen <- interpolate_model(pypsa_eur_41, cal, name = "eur41_m12")
scen <- write_script(scen, solver = solver_options$julia_highs_barrier)
scen <- read_solution(solve_scenario(scen, wait = TRUE))

report(scen)
```

Two notes on running it.

**The sample shortens the solve, not the interpolation.** Parameters are
interpolated and only then filtered to the declared timeslices, so
interpolation costs much the same whichever calendar it is given – about
35 seconds here – while the solve drops to about 220 seconds from a
calendar thirty times larger.

**Use HiGHS.** GLPK solves the five-node models in seconds, but at 41
nodes it was still iterating after ten minutes on a problem the barrier
closes in under four.
[`open_solvers()`](https://optimal2050.github.io/reneuro/reference/open_solvers.md)
reports what this machine has.

Beyond the defaults: `run =` reports a run other than the active one,
`verify = FALSE` omits the checks section, `levcost = TRUE` adds an
ex-post cost table, and
`report(compare_scenarios(list(a = ..., b = ...)))` puts several runs
side by side.

[**Open the report in its own
tab**](https://optimal2050.github.io/reneuro/reports/pypsa_eur_41_scenario.md)
