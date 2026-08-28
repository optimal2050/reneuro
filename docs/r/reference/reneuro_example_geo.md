# Directory holding the example GeoJSON region layers

`pypsa_geo_layers()` takes a directory rather than individual files, so
the shipped sidecars are reached through this rather than
[`reneuro_example()`](https://optimal2050.github.io/reneuro/r/reference/reneuro_example.md).

## Usage

``` r
reneuro_example_geo()
```

## Value

path to the directory of example GeoJSON layers

## Examples

``` r
list.files(reneuro_example_geo())
#> [1] "regions_offshore_base_s_5.geojson" "regions_onshore_base_s_5.geojson" 
```
