# Getting started with the model

``` r

library(energyRt)
library(reneuro)
```

This article uses only shipped data. It needs no PyPSA-Eur clone and no
Python. The results shown come from `be_solved`, a scenario solved in
advance, so a solver is not required either.

It covers four steps — pick a model, interpolate it, solve it, read the
result — and then restricting a model to a subset of its regions.

## 1. Pick a model

The models range from five nodes to a thousand, all of the same European
system.
[`vignette("about")`](https://optimal2050.github.io/reneuro/r/articles/about.md)
gives the resolutions and how each was built.

``` r

summary(pypsa_eur_5)
#> Model:  pypsa 
#> Description:  Converted from base_s_5_elec.nc 
#> Repositories:  pypsa_repo 
#> Regions: 5 (BE0_0, BE0_1, BE0_2, BE0_3, BE0_4)
#> Objects: 38
#>  commodity     demand    storage     supply technology      trade    weather 
#>          8          1          2          5         11          5          6
```

`pypsa_eur_5` covers five Belgian regions over one week: eleven
generation technologies, five supplies, two storages, five trade
corridors and six weather profiles holding the wind and solar
availability.

[`getObject()`](https://energyRt.org/reference/getObject.html) returns
the objects of one class,
[`get_region()`](https://energyRt.org/reference/get_region.html) the
declared regions:

``` r

names(getObject(pypsa_eur_5, class = "technology"))
#>  [1] "E_BIOMASS"       "E_CCGT"          "E_NUCLEAR"       "E_OFFWIND_AC"   
#>  [5] "E_OFFWIND_DC"    "E_OFFWIND_FLOAT" "E_OIL"           "E_ONWIND"       
#>  [9] "E_SOLAR"         "E_SOLAR_HSAT"    "E_WASTE"
get_region(pypsa_eur_5)
#> [1] "BE0_0" "BE0_1" "BE0_2" "BE0_3" "BE0_4"
```

Each model carries its provenance as an attribute:

``` r

str(attr(pypsa_eur_5, "reneuro_provenance")[c("commit", "source", "built_on")])
#> List of 3
#>  $ commit  : chr "d6383ebf602767b1adbb676fe8a16e37a6e9f932"
#>  $ source  : chr "base_s_5_elec.nc"
#>  $ built_on: chr "2026-08-25"
```

## 2. Interpolate

[`interpolate_model()`](https://energyRt.org/reference/interpolate_model.html)
expands the model’s declarations into the parameter tables a solver
needs: wildcards over regions, years and timeslices are expanded, and
the maps connecting processes to commodities are applied.

``` r

scen <- interpolate_model(pypsa_eur_5, name = "be")
```

At continental scale this step dominates the runtime. The 1,035-node
model interpolates to roughly ten million parameter rows.

## 3. Solve

``` r

scen <- write_script(scen, solver = solver_options$glpk)
scen <- read_solution(solve_scenario(scen, wait = TRUE))
```

GLPK is sufficient at this size. Past a few dozen regions, use
Julia/HiGHS or Pyomo/HiGHS;
[`vignette("about")`](https://optimal2050.github.io/reneuro/r/articles/about.md)
has the measured times, and
[`benchmark_solvers()`](https://optimal2050.github.io/reneuro/r/reference/benchmark_solvers.md)
repeats them on another machine.

Those two chunks produced `be_solved`, which ships with the package:

``` r

# print() would round this to 9 significant digits; the gate is exact.
format(getData(be_solved, "vObjective", merge = TRUE)$value, digits = 16)
#> [1] "164664296.503735"
```

The build script refuses to save a scenario whose objective differs from
that figure, so it also serves as a regression test on the conversion.

## 4. Read the result

[`getData()`](https://energyRt.org/reference/getData.html) reads
variables, parameters and bounds alike. With `merge = TRUE` it returns a
long data frame with the index columns resolved to names.

``` r

library(dplyr)

getData(be_solved, "vTechAct", merge = TRUE, process = TRUE,
        drop.zeros = FALSE, timeframe = "lowest") |>
  group_by(process) |>
  summarise(GWh = round(sum(value) / 1e3, 1)) |>
  arrange(desc(GWh)) |>
  head(8)
#> # A tibble: 8 × 2
#>   process        GWh
#>   <chr>        <dbl>
#> 1 E_CCGT       664. 
#> 2 E_NUCLEAR    511. 
#> 3 E_SOLAR      248  
#> 4 E_OFFWIND_AC 142. 
#> 5 E_SOLAR_HSAT  70.9
#> 6 E_ONWIND      55.3
#> 7 E_WASTE       44.6
#> 8 E_BIOMASS     18.7
```

Gas and nuclear supply most of the week, followed by solar and offshore
wind. The same quantities are available from a PyPSA solve of the
network, so the mix can be compared directly.

## 5. Carve out a local model

`pypsa_eur_nuts3` is not intended to be solved at full resolution. Its
use is to supply a study area at NUTS3 granularity, which the coarser
models cannot: their aggregation has already averaged that detail away.

``` r

pt <- geoscales::geoscale_leaftable(nuts_gs) |>
  as.data.frame() |>
  dplyr::filter(nuts0 == "PT") |>
  dplyr::pull(region) |>
  intersect(get_region(pypsa_eur_nuts3))

m <- attach_weather(pypsa_eur_nuts3, c("onwind", "solar", "ror")) |>
  subset_model_regions(region = pt)
```

The result is Portugal at 22 nodes — every NUTS3 region containing a
substation, with the network between them intact. `region` accepts any
subset of the model’s regions, so a study area need not follow a
national border.

[`subset_model_regions()`](https://energyRt.org/reference/subset_model_regions.html)
drops the corridors crossing the boundary and reports each. Without
replacement the model is **islanded** and must meet demand from its own
resources, so its cost is an upper bound. `boundary_prices` replaces the
dropped routes with priced import/export stubs.

## Region data

`nuts_gs` is the region hierarchy the NUTS models are built from. It
carries geometry and per-region data: population, GDP, demand, existing
capacity and renewable potential.

``` r

geoscales::geoscale_leaftable(nuts_gs) |>
  as.data.frame() |>
  group_by(nuts0) |>
  summarise(twh = sum(load_twh), wind_gw = sum(pot_onwind) / 1e3) |>
  arrange(desc(twh)) |>
  head(5)
#> # A tibble: 5 × 3
#>   nuts0   twh wind_gw
#>   <chr> <dbl>   <dbl>
#> 1 DE     509.    490.
#> 2 FR     492.    969.
#> 3 IT     316.    504.
#> 4 GB     316.    439.
#> 5 ES     246.    938.
```

The column used to aggregate or split by is a modelling choice. National
demand divides by `load_twh` or `pop`, a wind target by `pot_onwind`;
area is rarely the right weight for either.

## Where next

- [`vignette("data")`](https://optimal2050.github.io/reneuro/r/articles/data.md)
  — the shipped datasets and their aggregation rules
- [`vignette("about")`](https://optimal2050.github.io/reneuro/r/articles/about.md)
  — how each model was built, solver benchmarks, references
- [`?pypsa_eur_models`](https://optimal2050.github.io/reneuro/r/reference/pypsa_eur_models.md),
  [`?nuts_gs`](https://optimal2050.github.io/reneuro/r/reference/nuts_gs.md)
  — the shipped objects and their licences
