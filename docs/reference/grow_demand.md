# Build multi-year demand from a base-year profile and growth factors

`grow_demand()` is the transparent core: it takes a `demand` object
whose `@demand` table holds a base-year profile (region x timeslice,
optionally year-keyed) and a plain growth-factor table, and writes one
profile per factor year — `demand * factor`, keyed by `year`. Nothing
else changes: the shape is the base year's, the factors are whatever
table you pass
([tyndp_demand](https://optimal2050.github.io/reneuro/reference/tyndp_demand.md)
filtered to one scenario is one such table, but any
`(country|region, year, factor)` data frame works).

## Usage

``` r
grow_demand(dem, factors, base_year = 2025)

build_demand(
  name = NULL,
  factors,
  base_year = 2025,
  years = NULL,
  regions = NULL,
  from = reneuro::pypsa_eur_41
)
```

## Arguments

- dem:

  A `demand` object.

- factors:

  Data frame with columns `year`, `factor`, and either `region` (matched
  exactly) or `country` (matched to the first two letters of the region
  code).

- base_year:

  Year of the base profile in `dem@demand`. Rows with that year (or with
  `year` `NA`, the year-agnostic form) are the shape that grows;
  base-year demand is reproduced exactly where `factor == 1`.

- name:

  Name for the built demand object (default: keep the source object's
  name).

- years:

  Optional years to keep (subset of `factors$year`); `NULL` uses every
  year in `factors`.

- regions:

  Optional region codes to keep.

- from:

  Source model holding the base-year demand (default
  [pypsa_eur_41](https://optimal2050.github.io/reneuro/reference/pypsa_eur_models.md)).

## Value

The `demand` object with a year-keyed `@demand` table.

## Details

`build_demand()` is the convenience wrapper: it pulls a demand object
out of a source model, optionally renames it and restricts it to
`regions`, and applies `grow_demand()` for the requested `years`.

## Examples

``` r
if (FALSE) { # \dontrun{
ga <- subset(tyndp_demand, scenario == "GA")
d  <- grow_demand(getObjects(pypsa_eur_41)$DEM_ELC, ga, base_year = 2025)
} # }
```
