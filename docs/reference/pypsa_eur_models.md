# Converted PyPSA-Eur models

Unsolved
[energyRt](https://energyRt.org/reference/energyRt-package.html) models
converted from PyPSA-Eur networks, spanning the range this package is
built for: the European system at several spatial resolutions, a small
Belgian model that runs in seconds with its copperplate reference, a
one-year horizon series, and a vintaged 2025-2050 pathway model. All are
built on 2025 weather and measured ENTSO-E 2025 load, and are loaded
lazily, so they cost nothing until touched.

## Usage

``` r
pypsa_eur_nuts3

pypsa_eur_41

pypsa_eur_5

pypsa_eur_5cp

pypsa_eur_41v

pypsa_eur_41_2025

pypsa_eur_41_2030

pypsa_eur_41_2035

pypsa_eur_41_2040

pypsa_eur_41_2045

pypsa_eur_41_2050
```

## Format

An [energyRt](https://energyRt.org/reference/energyRt-package.html)
`model` object.

An object of class `model` of length 1.

An object of class `model` of length 1.

An object of class `model` of length 1.

An object of class `model` of length 1.

An object of class `model` of length 1.

An object of class `model` of length 1.

An object of class `model` of length 1.

An object of class `model` of length 1.

An object of class `model` of length 1.

An object of class `model` of length 1.

An object of class `model` of length 1.

## Source

Converted from [PyPSA-Eur](https://github.com/PyPSA/pypsa-eur)
`v2026.02.0` (commit `d6383eb`, PyPSA 1.1.0) by `convert_pypsa()`.

**Licence: ODbL-1.0**, required by the share-alike terms of the
OpenStreetMap-derived inputs, and independent of this package's
Apache-2.0 code licence. Attribution is required for OpenStreetMap
contributors and the European Environment Agency among others.

The World Database on Protected Areas, which may not be redistributed,
is **not** present – see
`system.file("LICENSE.note", package = "reneuro")` for how that was
verified and what it costs (renewable land availability in Moldova and
Ukraine is overstated as a result). The same file records that the OPSD
and ENTSO-E demand series carry unclear upstream terms.

The build scripts live in two places. This package's `data-raw/` holds
`pypsa_eur_41.R`, `pypsa_eur_nuts3.R`, `pypsa_eur_41_years.R` and
`pypsa_eur_41v.R`; `pypsa_eur_5` and `pypsa_eur_5cp` are built by the
converter workspace's `reneuro.dev/data-raw/make_models.R`, from the
network also bundled as `reneuro_example("BE_base_s_5_elec.nc")`. All
shipped models were rebuilt 2026-09-03 with the corrected calendar
chronology: the converter used to emit the timetable hour-major, which
chained the storage balance across days at the same wall-clock hour –
storage could not carry noon into evening. The Belgian pair now also
carries the current defaults (flat corridors, sanitised calendar names),
and `be_solved`'s objective gate moved accordingly (verified +0.386%
above PyPSA's own solve of the same network, the documented
transport-relaxation class of difference).

## Details

`pypsa_eur_5` is PyPSA-Eur's own Belgium example: five regions, one week
(168 hourly snapshots). It is small enough to solve in seconds, which
makes it the model every example and test uses.

`pypsa_eur_5cp` is the same network with `transmission = "copperplate"`
– the same corridors, but unbounded and lossless. It is the reference
point for what the network representation costs: a copperplate cannot be
more expensive than any bounded version of itself, so it is the floor.

`pypsa_eur_41` is PyPSA-Eur's own k-means clustering at 41 nodes over
the full year, so it is directly comparable to a PyPSA-Eur run at that
size. Its corridors carry a single flat loss rate: the six-tranche
version it replaced produced 224,640 generated constraints on a
288-slice calendar, which no open solver generates in reasonable time.
It is also the first model built with the fuel price separated – `varom`
holds the true VOM and each fuel's supply carries its price – so a
gas-price sensitivity is a change to one number rather than a
re-conversion.

`pypsa_eur_nuts3` is the NUTS3 network over the **full year** (8,760
hourly snapshots) – the finest resolution the data supports, intended as
the starting point for aggregation and study-area work in R rather than
as a model to solve whole. NUTS3 yields 1,035 AC nodes rather than 1,477
because 442 regions contain no substation and merge into neighbours,
**retaining their demand and generation** in the region they join. Trade
uses one flat loss rate per corridor and a transport formulation without
Kirchhoff's voltage law. Its hourly weather profiles are seven eighths
of its size, so they ship as separate `wx_nuts3_*` objects and are put
back with
[`attach_weather()`](https://optimal2050.github.io/reneuro/reference/attach_weather.md)
– a model without them cannot be interpolated, because its technologies
reference them by name. It carries
[nuts_gs](https://optimal2050.github.io/reneuro/reference/nuts_gs.md),
so `energyRt::aggregate_model_regions(pypsa_eur_nuts3, level = "nuts2")`
needs no second argument; the coarser NUTS levels (289 regions at NUTS2,
106 at NUTS1, 36 at NUTS0) are derived that way rather than shipped.

`pypsa_eur_41_2025` ... `pypsa_eur_41_2050` are the **one-year horizon
series**: the 41-node system rebuilt per planning horizon in five-year
steps. Weather, load and network are identical to `pypsa_eur_41`; what
changes with the horizon is the cost vintage (technology-data v0.14.0
for that year) and the existing fleet, aged by two rules kept separable
in provenance – announced `DateOut` schedules (114 GW, mostly coal and
lignite phase-outs) and assumed carrier-lifetime retirement, which
reproduces what PyPSA's myopic mode does between horizons (its overnight
mode does no ageing at all). `attr(m, "reneuro_provenance")$retirement`
holds the per-carrier split, so the assumed half can be identified and
discounted. The series ships **without weather**: all six share
`pypsa_eur_41`'s profiles, so attach them before interpolating –
`attach_weather(pypsa_eur_41_2030, from = pypsa_eur_41)`.

`pypsa_eur_41v` is the **vintaged multi-year model**: one model over the
2025–2050 horizon (five-year milestones) where each carrier is a single
technology whose existing fleet is split into build-year vintages – the
17 `grouping_years_power` bins PyPSA's myopic mode uses – each with its
own efficiency (from that bin's cost table, clamped to 2025) and a
milestone-by-milestone surviving-stock series from the same two
retirement rules as the horizon series. Alongside the closed bins, each
investable carrier has one open path with year-keyed investment costs
from the six horizon cost tables, so build-year economics are
endogenous. Carriers with no existing fleet (solar-hsat, offwind DC and
floating) stay un-vintaged and investable. Demand is flat at 2025; like
the horizon series it ships without weather –
`attach_weather(pypsa_eur_41v, from = pypsa_eur_41)`.
[`energyRt::getVariants()`](https://energyRt.org/reference/getVariants.html)
and
[`energyRt::variantSummary()`](https://energyRt.org/reference/variantSummary.html)
list the vintages; `attr(m, "reneuro_provenance")` records the bin table
and the announced/assumed retirement split.

The continental models are built on **2025 weather and load** (ENTSO-E
measured demand; the `europe-2025-sarah3-era5` cutout). All were
converted with `cost_source = "network"`, taking costs from the network
rather than from a separate cost assumption, so they agree with the
PyPSA solve they can be compared against.

## Examples

``` r
# Provenance travels with the object.
str(attr(pypsa_eur_5, "reneuro_provenance"), max.level = 1)
#> List of 9
#>  $ clone       : chr "pypsa-eur-v2026"
#>  $ commit      : chr "d6383ebf602767b1adbb676fe8a16e37a6e9f932"
#>  $ describe    : chr "v2026.02.0"
#>  $ dirty       : logi TRUE
#>  $ built_on    : chr "2026-09-03"
#>  $ reneuro     : chr "0.3.0.9000"
#>  $ object      : chr "pypsa_eur_5"
#>  $ source      : chr "base_s_5_elec.nc"
#>  $ convert_args:List of 1
```
