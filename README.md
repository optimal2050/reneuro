
<!-- README.md is generated from README.Rmd. Please edit that file, then run
     devtools::build_readme() or rmarkdown::render("README.Rmd"). -->

# reneuro <a href="https://optimal2050.github.io/reneuro/"><img src="man/figures/logo.png" align="right" height="136" alt="reneuro website" /></a>

**A European energy system optimization model with an R interface.**

> **Note:** the repository is under an update — expected **September
> 25**.

`r·en·euro` provides a European energy system model built on
[energyRt](https://energyRt.org). It was developed as teaching material
for a modelling course, to replicate
[PyPSA-Eur](https://github.com/PyPSA/pypsa-eur), an established open
model of the European power system, at several spatial resolutions.

Eleven models ship with the package, ready to solve — all built on
**2025 weather and load** (the `europe-2025-sarah3-era5` cutout;
measured ENTSO-E demand). They need neither Python nor a PyPSA-Eur
clone, and are lazy-loaded, so they cost nothing until touched.

| model | nodes | planning horizon |
|----|---:|----|
| `pypsa_eur_5`, `_5cp` | 5 | single year, one week (Belgium; `_5cp` copperplated) |
| `pypsa_eur_41` | 41 | single year, full hourly year |
| `pypsa_eur_41_2025` … `_2050` | 41 | one year per horizon, fleet aged by retirement |
| `pypsa_eur_41v` | 41 | 2025–2050 in five-year milestones, vintaged fleet |
| `pypsa_eur_nuts3` | 1,035 | single year, full hourly year |

`pypsa_eur_nuts3` follows Eurostat’s NUTS3 regions rather than an
algorithmic clustering, so it joins to published statistics; it is a
**source** model — carve a study area from it or aggregate it to
NUTS0/1/2 with `energyRt::aggregate_model_regions()`. Its hourly weather
ships as separate objects that `attach_weather()` puts back; the horizon
series and `pypsa_eur_41v` reuse `pypsa_eur_41`’s weather the same way.
The [About](https://optimal2050.github.io/reneuro/articles/about.html)
article covers how each model was built and what is planned next.

## Installation

``` r
# install.packages("pak")
pak::pak("optimal2050/reneuro")
```

[`energyRt`](https://energyRt.org) is not on CRAN; `pak` installs it
from GitHub alongside `reneuro`. A solver is also required — see the
[installation guide](https://energyRt.org/articles/install.html) and
[`en_setup()`](https://energyRt.org/reference/en_setup.html). GLPK
solves the five-node models; HiGHS (via Julia or Python) handles sampled
larger models on a standard laptop, while full-resolution models call
for commercial or GPU solvers.

## Quick start

``` r
library(reneuro)
library(energyRt)

report(pypsa_eur_5)

scen <- interpolate_model(pypsa_eur_5, name = "be")
scen <- write_script(scen, solver = solver_options$glpk)
scen <- read_solution(solve_scenario(scen, wait = TRUE))

getData(scen, "vObjective", merge = TRUE)$value
report(scen)
```

The solved scenario also ships as `be_solved`, so the results can be
explored without a solver installed.

## Documentation

- [Getting
  started](https://optimal2050.github.io/reneuro/articles/reneuro.html)
  — a model end to end, and carving a local model out of NUTS3
- [The data](https://optimal2050.github.io/reneuro/articles/data.html) —
  what ships, and what changing spatial resolution does to it
- [Data
  sources](https://optimal2050.github.io/reneuro/articles/data-sources.html)
  — the upstream inputs as maps and figures, with the source and licence
  table
- [Wind
  energy](https://optimal2050.github.io/reneuro/articles/wind-potential.html)
  — a quality-aware wind resource layer built beside the replica, with the
  Global Wind Atlas setting the long-term level and ERA5 the hourly
  variability
- [Solar
  energy](https://optimal2050.github.io/reneuro/articles/solar-potential.html)
  — the solar half of that layer, checked against the Global Solar Atlas
- [About](https://optimal2050.github.io/reneuro/articles/about.html) —
  how the models were built, solver benchmarks, references and licences

## Contributing

Issues and pull requests are welcome at
[github.com/optimal2050/reneuro](https://github.com/optimal2050/reneuro);
the package follows the [optimal2050
conventions](https://github.com/optimal2050/.github/blob/main/CONVENTIONS.md).

## Licence

`reneuro`’s sources are Apache-2.0. It imports `energyRt`, which is
AGPL-3, so a distribution of the two together is conveyed under AGPL-3.
The shipped models inherit the licences of their inputs, chiefly
ODbL-1.0 for OpenStreetMap transmission topology. Full detail, including
data provenance, is in the
[About](https://optimal2050.github.io/reneuro/articles/about.html)
article and in `NOTICE`.

If you use `reneuro` in research, please cite it with
`citation("reneuro")` and also cite PyPSA-Eur — see
[References](https://optimal2050.github.io/reneuro/articles/about.html#references).
