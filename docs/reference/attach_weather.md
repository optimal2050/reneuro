# Attach weather profiles to a model

`pypsa_eur_nuts3` and the horizon series `pypsa_eur_41_2025` ...
`pypsa_eur_41_2050` ship without their hourly weather profiles, which
are most of their size (the six horizon models share `pypsa_eur_41`'s
profiles bit-for-bit, so shipping them six more times would store
nothing new). Their technologies still reference the profiles by name,
so a model must have them attached before it is interpolated.

## Usage

``` r
attach_weather(mod, resources = NULL, from = NULL)
```

## Arguments

- mod:

  A `model`, normally `pypsa_eur_nuts3` or a `pypsa_eur_41_<year>`.

- resources:

  Resource names to attach, from
  [`weather_resources()`](https://optimal2050.github.io/reneuro/reference/weather_resources.md).
  `NULL` (default) attaches all of them. Ignored when `from` is given.

- from:

  A `model` to copy the `weather` objects from instead of the
  `wx_nuts3_*` datasets — `pypsa_eur_41` for the horizon series.

## Value

`mod` with the requested `weather` objects added.

## Details

Attaching only what a study uses keeps the model small: a
solar-and-onshore analysis loads 75 MB rather than 182 MB.

## Examples

``` r
# \donttest{
m <- attach_weather(pypsa_eur_nuts3, c("onwind", "solar"))
names(energyRt::getObject(m, class = "weather"))
#> [1] "W_ONWIND" "W_SOLAR" 

m25 <- attach_weather(pypsa_eur_41_2025, from = pypsa_eur_41)
# }
```
