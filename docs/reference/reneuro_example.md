# Path to an example PyPSA-Eur file shipped with reneuro

Path to an example PyPSA-Eur file shipped with reneuro

## Usage

``` r
reneuro_example(file = NULL)
```

## Arguments

- file:

  file name. If `NULL` (the default), the available files are listed
  instead.

## Value

a file path, or a character vector of available names when
`file = NULL`.

## Examples

``` r
reneuro_example()
#> [1] "BE_base_s_5_elec.nc"                  
#> [2] "geo/regions_offshore_base_s_5.geojson"
#> [3] "geo/regions_onshore_base_s_5.geojson" 
reneuro_example("BE_base_s_5_elec.nc")
#> [1] "C:/Users/admin/AppData/Local/R/win-library/4.5/reneuro/extdata/BE_base_s_5_elec.nc"
```
