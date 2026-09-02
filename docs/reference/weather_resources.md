# Weather resources of the full-year NUTS3 model

The resource names
[`attach_weather()`](https://optimal2050.github.io/reneuro/reference/attach_weather.md)
accepts, in the order they are attached. Each names a dataset
`wx_nuts3_<resource>`.

## Usage

``` r
weather_resources()
```

## Value

A character vector.

## Examples

``` r
weather_resources()
#> [1] "onwind"        "offwind_ac"    "offwind_dc"    "offwind_float"
#> [5] "solar"         "solar_hsat"    "ror"          
```
