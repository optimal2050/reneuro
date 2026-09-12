# TYNDP 2024 electricity-demand growth factors

Growth factors for electricity demand by country, scenario and milestone
year (2025-2050, 5-year steps), anchored at 2025 = 1 – the measured
ENTSO-E load keeps the level, TYNDP 2024 moves it. Scenarios: `"NT"`
(National Trends+, from the market-modelling outputs' native demand;
extrapolated beyond 2040), `"DE"` (Distributed Energy) and `"GA"`
(Global Ambition), which follow the NT path to 2030 and then their own
trajectories. `method` records whether a value comes from the source
series, an extrapolation, or the perimeter-average fill for countries
the sources lack. Apply with `scale_demand()`.

## Usage

``` r
tyndp_demand
```

## Format

A data frame: `scenario`, `country`, `year`, `factor`, `method`.

## Source

TYNDP 2024 Scenarios (ENTSO-E/ENTSOG), CC-BY 4.0;
<https://2024.entsos-tyndp-scenarios.eu/download/>. Built by
`data-raw/tyndp_demand.R`.
