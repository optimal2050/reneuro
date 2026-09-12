# Translation

``` r

library(reneuro)
library(energyRt)
```

This article documents how a PyPSA network becomes an energyRt model:
which component becomes which object, where a slot’s value comes from,
and the four places where the two representations do not correspond one
to one.

It describes the conversion behind the shipped models. Reading it is not
required to use them —
[`vignette("reneuro")`](https://optimal2050.github.io/reneuro/articles/reneuro.md)
covers that — but it is what you need to check a converted number
against its source, or to decide whether a question the model answers is
one the translation supports.

Scope is the electricity-only network at the `base_s_{clusters}_elec.nc`
cut point: after the network is built, before policy overlays and
temporal averaging are applied.

## The component table

| PyPSA | energyRt |  |
|:---|:---|:---|
| `Bus` carrier | `commodity` | bus carriers only — see below |
| `Load` | `demand` | series in `@demand`, one row per region and timeslice |
| `Generator` | `technology` (+ `supply`) | one object per carrier, regions in a `region` column |
| `Generator` `p_max_pu` series | `weather` | kept out of the technology object |
| `StorageUnit` | `storage` | one object; `duration` from `max_hours` |
| `Store` + two `Link`s | `storage` | one object with three part capacities |
| `Line` (AC) | `trade` | transport, not Kirchhoff — see below |
| `Link` (DC) | `trade` | transport, faithful |
| `StorageUnit` `inflow` | `commodity` + `supply` + `storage` + `technology` | four objects — see below |

Everything below is a case where that one-line summary is not the whole
story.

## `carrier` names two different things

PyPSA’s `carrier` field is used for two purposes, and only one of them
is a commodity:

- on a **bus** it names the energy flowing there — `AC`, `H2`, `battery`
  — and that is a commodity;
- on a **generator** or **link** it names the technology or the fuel —
  `CCGT`, `onwind`, `battery charger` — and that is not.

So commodities are taken from bus carriers, and generator carriers
become technology names. The `carriers` component itself is a lookup
table of attributes, not a set of objects to create.

## Generators carry their fuel explicitly

In an electricity-only network a generator has no fuel bus:
`marginal_cost` already folds fuel price divided by efficiency into one
number. Translating that literally gives an output-only technology — a
CCGT that consumes no gas. It is arithmetically equivalent, but it
cannot carry a fuel price, a resource limit, or an emission factor.

Thermal carriers therefore get an explicit fuel `@input` with
`combustion = 1` and the efficiency in `@ceff$cinp2use`. CO₂ then
follows from the fuel’s carbon content on the commodity, rather than
from a coefficient on the technology.

**The fuel supply is priced at zero and `varom` keeps the whole
`marginal_cost`.** The fuel price is not recoverable from the network
file, and charging the supply as well would count it twice. This is the
one place in the translation where double counting could enter.

Capacity depends on whether the generator is extendable:

| PyPSA          | energyRt                                           |
|----------------|----------------------------------------------------|
| not extendable | `@capacity$stock` — exogenous, no capital charged  |
| extendable     | `@capacity$cap.lo` / `cap.up` — built and paid for |

## Storage: two shapes in, one shape out

PyPSA has two storage representations and a network may use both:

- **`StorageUnit`** — one component carrying a power rating `p_nom`, a
  duration `max_hours`, and a round trip split into `efficiency_store`
  and `efficiency_dispatch`.
- **`Store` + two `Link`s** — an energy reservoir on its own bus, plus a
  charger and a discharger that carry the conversion efficiencies and
  their own ratings.

Both become **one** energyRt `storage`, because a storage has three
independent capacity variables — charge, discharge and reservoir — so
the second shape needs no extra objects:

``` r

stg <- getObject(pypsa_eur_5, class = "storage")[["STG_BATTERY"]]
grep("^(inp|out|stg)\\.stock$", names(stg@capacity), value = TRUE)
#> [1] "out.stock" "inp.stock" "stg.stock"
stg@seff[, c("stgeff", "inpeff", "outeff")]
#>   stgeff    inpeff    outeff
#> 1     NA 0.9797959 0.9797959
```

`inp.*` is the charger, `out.*` the discharger, `stg.*` the reservoir,
and `@seff` carries the two conversion efficiencies plus standing loss.
A converted model contains no separate charger or discharger
technologies.

## Transmission is a transport model

PyPSA is a hybrid: Kirchhoff’s voltage law applies to the AC `Line`s,
which form sub-networks and receive cycle constraints, while DC `Link`s
are free transport. energyRt’s `trade` is transport throughout.

The consequence is asymmetric and worth stating plainly:

- **DC links translate faithfully** — a controllable branch is what a
  transport model represents natively.
- **AC lines are a relaxation.** The converted model’s AC flows are less
  constrained than the source, so its objective is a **lower bound**,
  and it should not be used to draw transmission-expansion conclusions.

[`energyRt::newACLine()`](https://energyRt.org/reference/newACLine.html)
with `kvl = TRUE` at interpolation restores the cycle constraints where
that matters.

Capacity belongs to the trade object rather than to a route, so each bus
pair becomes its own object and parallel lines on a pair are merged by
summing `s_nom` — indistinguishable in a transport model in any case.

Quadratic AC losses are linearised. The default gives each corridor one
flat `teff` evaluated at a chosen loading; `tranches = n` splits it into
`n` equal capacity tranches with rising loss rates instead,
approximating the curve without integer variables. Tranches were the
default once, which is why `pypsa_eur_5` still carries six of them – at
continental scale they cost a generated constraint per corridor, tranche
and timeslice, which is why the larger models are flat.

## Availability leaves the technology object

PyPSA keeps availability in two places at once. `p_max_pu` is a static
column, and `generators_t.p_max_pu` is a series covering the
weather-driven generators only. For every generator that has a series
the static value is exactly 1, a placeholder — so reading the static
column alone would make every wind farm permanently available.

energyRt keeps the bulk series out of the technology: a `weather` object
holds region × timeslice values and the technology references it by
name.

``` r

names(getObject(pypsa_eur_5, class = "weather"))
#> [1] "W_OFFWIND_AC"    "W_OFFWIND_DC"    "W_OFFWIND_FLOAT" "W_ONWIND"       
#> [5] "W_SOLAR"         "W_SOLAR_HSAT"
```

## Hydro inflow becomes four objects

`storage_units_t.inflow` has no direct equivalent — an energyRt storage
can be charged from a commodity, but not from an exogenous series. A
hydro reservoir therefore decomposes:

| object                 | role                                              |
|------------------------|---------------------------------------------------|
| `commodity` `HYDWAT`   | virtual reservoir energy, balanced hourly         |
| `supply` `SUP_HYDWAT`  | availability follows the inflow series            |
| `storage` `STG_HYDRO`  | the reservoir                                     |
| `technology` `E_HYDRO` | `HYDWAT` → electricity at the dispatch efficiency |

## Conventions that differ

Two conventions produce correct-looking numbers that mean different
things, and both are places to check before comparing against a source
model.

**Rating side.** A `Link`’s `p_nom` is rated on its input bus; an
energyRt capacity is rated on activity, i.e. output. Converting one to
the other scales by the efficiency: `capacity = p_nom * eff`, and
`invcost = capital_cost / eff`.

**Cost annualisation.** Where `capital_cost` is already annuitised it
maps to `@invcost$eac`, not to `invcost` — supplying it as `invcost`
would annuitise a second time.

## Revised assumptions

Everything above translates PyPSA-Eur faithfully — same data, same
assumptions, verified against the source model’s own solutions. Two
assumption families are also *revised* in separate model versions, so
the faithful model and the revised one can be solved side by side and
the difference read as the effect of the assumption, never of the
translation.

### Economic retirement

The overnight convention treats the existing fleet asymmetrically:
non-extendable capacity survives to the planning year whole and free,
while extendable carriers are implicitly retired in full and must be
rebuilt at least to today’s size. The revised version replaces both
halves with one consistent rule set:

- **Long-lived, non-replicable assets** — nuclear, geothermal, and the
  hydro chain (reservoir, run-of-river, pumped storage’s sibling dam) —
  keep their capacity with no investment option, paying explicit fixed
  O&M.
- **Everything else in the fleet can retire economically.** Fixed O&M is
  split out of PyPSA’s `capital_cost` annuity (which includes it), so
  the solver may retire capacity whose O&M exceeds its value
  (`optimizeRetirement`), and new builds pay the pure annuity plus the
  same O&M without double-counting. The fossil floors are gone: existing
  gas is free stock that can retire, not a rebuild obligation.
- **Carbon-free floors stay.** Wind, solar and offshore keep `cap.lo` =
  today’s capacity — a no-backsliding assumption — and pumped-hydro and
  battery storage join them, rebuilt at the cost table’s annuities.
  Reinvested capacity lives its technology lifetime.

### Demand

The measured 2025 load is a level, not a forecast: solved against 2050
costs it understates what a 2050 system must build. The revision keeps
the measured hourly shapes and levels at 2025 and grows them by the
**TYNDP 2024 scenarios** (ENTSO-E/ENTSOG, CC-BY 4.0): National Trends+
(national plans; extrapolated beyond its 2040 horizon), and the
carbon-neutrality pathways Distributed Energy and Global Ambition, which
follow the National Trends path to 2030 and then diverge — the
scenarios’ own construction. Growth factors are per country and
milestone year (`tyndp_demand`), anchored so 2025 equals the measured
load exactly; countries the TYNDP perimeter lacks take the average
factor, marked as such. `scale_demand()` applies a scenario to any
shipped model — one year for an overnight solve, all milestones for the
multi-year models.

## What the translation does not do

The conversion reports rather than repairs. A parameter that cannot be
represented is named and its entity excluded; it is never replaced with
a plausible value. The register travels with each model:

``` r

str(attr(pypsa_eur_5, "reneuro_provenance")[c("describe", "commit", "source")])
#> List of 3
#>  $ describe: chr "v2026.02.0"
#>  $ commit  : chr "d6383ebf602767b1adbb676fe8a16e37a6e9f932"
#>  $ source  : chr "base_s_5_elec.nc"
```

## See also

- [`vignette("reneuro")`](https://optimal2050.github.io/reneuro/articles/reneuro.md)
  — using a shipped model
- [`vignette("about")`](https://optimal2050.github.io/reneuro/articles/about.md)
  — how each model was built, and the licences
- [`vignette("data")`](https://optimal2050.github.io/reneuro/articles/data.md)
  — the region datasets and their aggregation rules
