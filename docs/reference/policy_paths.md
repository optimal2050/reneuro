# Power-sector CO2 cap trajectories

Three cap paths as factors relative to 2025 emissions, for building
carbon-cap scenarios (see the Scenarios article): `ets_cap` (the EU ETS
cap shape under the Fit-for-55 linear reduction factors, zero around
2039 – deliberately the tightest of the three; note the cap is bankable,
so it is not a hard annual emissions ceiling), `ndc` (the EU's
economy-wide pledges – -55% 2030, the 2035 NDC midpoint, -90% 2040,
neutrality 2050 – mapped to 2025-relative factors) and `nz2050` (linear
to zero at 2050). Multiply by a base-year emission level (the model's
own solved 2025 emissions) to obtain cap right-hand sides.

## Usage

``` r
policy_paths
```

## Format

A data frame: `scenario`, `year`, `factor`, `method`.

## Source

Directive (EU) 2023/959; the EU NDC (Nov 2025) and 2040 target; EEA GHG
inventory. Built by `data-raw/policy_paths.R`.
