# Attach weather profiles to a model

`pypsa_eur_nuts3` ships without its hourly weather profiles, which are
most of its size. Its technologies still reference them by name, so the
profiles a run needs must be attached before it is interpolated.

## Usage

``` r
attach_weather(mod, resources = NULL)
```

## Arguments

- mod:

  A `model`, normally `pypsa_eur_nuts3`.

- resources:

  Resource names to attach, from
  [`weather_resources()`](https://optimal2050.github.io/reneuro/reference/weather_resources.md).
  `NULL` (default) attaches all of them.

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
# }
```
