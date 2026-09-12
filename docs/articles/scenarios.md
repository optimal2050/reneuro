# Scenarios

Policy enters a converted model through two native energyRt levers: a
**constraint** on the emission accounting variable (a carbon cap) and a
**tax** on the CO₂ commodity (a carbon price). Both are plain objects
added to a model before interpolation — no converter machinery involved.
The fuels of every shipped model already carry their emission factors
(0.198 tCO₂/MWh_(th) for gas, 0.336 for coal, 0.407 for lignite, …), so
`vEmsFuelTot` accounts emissions per region and year out of the box.

For scale: the *uncapped* `pypsa_eur_41` full-year solve at 2050 costs
emits about **860 Mt CO₂** — with nothing pricing carbon, the inherited
coal fleet runs baseload. The levers below are what change that.

``` r

library(reneuro)
library(energyRt)
```

## A carbon cap: zero emissions by 2050

A cap is a `constraint` on the sum of `vEmsFuelTot` — dimensions not
listed in `for.each` (here: region) are summed, so this caps the
**total** system:

``` r

CO2_ZERO <- newConstraint(
  name = "CO2_ZERO", eq = "<=",
  for.each = data.frame(year = 2050, comm = "CO2"),
  term1 = list(variable = "vEmsFuelTot"),
  rhs = 0, defVal = Inf)
```

Added to the overnight model with `add(pypsa_eur_41, CO2_ZERO)`, the
2050 solve must displace all 860 Mt.

## A carbon tax

[`newTax()`](https://energyRt.org/reference/newTax.html) prices a
commodity’s balance; with costs in EUR and emissions in tonnes, `bal` is
EUR/tCO₂. A rising illustrative path:

``` r

CT_CO2 <- newTax(
  name = "CT_CO2", comm = "CO2",
  tax = data.frame(year = c(2025, 2050), bal = c(80, 250)))
```

Values between the anchor years interpolate linearly. A tax leaves the
emission level to the solver — the cap and the tax are the two ends of
the same lever, and both can be present.

## Data-backed scenarios: `policy_paths`

The `policy_paths` dataset carries three sourced cap trajectories as
factors relative to 2025 emissions:

- **`current_policy`** — the EU ETS cap shape: linear reduction at the
  Fit-for-55 rates (Directive (EU) 2023/959, 4.3 %/yr to 2027 and 4.4
  %/yr after), which takes the ETS-1 cap to zero around 2039; power is
  ETS-covered, so the power cap follows it.
- **`ndc`** — the EU’s economy-wide pledges mapped to 2025-relative
  factors: −55 % by 2030 vs 1990 (Climate Law), the 66.25–72.5 %
  indicative 2035 range of the NDC submitted to the UNFCCC in November
  2025 (midpoint used), −90 % by 2040, neutrality by 2050. The mapping
  uses the EEA estimate of about −37 % vs 1990 reached by 2025, and is
  conservative for power, which decarbonises faster than the economy-
  wide average.
- **`nz2050`** — a plain linear path from 2025 to zero at 2050.

``` r

library(ggplot2)
ggplot(policy_paths, aes(year, factor, colour = scenario)) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.6) +
  labs(x = NULL, y = "cap relative to 2025 emissions", colour = NULL) +
  theme_minimal()
```

![The three cap trajectories, as factors on 2025
emissions.](scenarios_files/figure-html/paths-1.png)

The three cap trajectories, as factors on 2025 emissions.

A factor path becomes a cap by choosing the base — the natural choice is
the model’s own solved 2025 emissions, read from a first-milestone
dispatch:

``` r

E2025 <- 8.6e8   # tCO2; replace with your solved 2025 emissions:
                 # sum(getData(scen, "vEmsFuelTot", year = 2025)$value)
ndc <- subset(policy_paths, scenario == "ndc")
CO2_NDC <- newConstraint(
  name = "CO2_NDC", eq = "<=",
  for.each = data.frame(year = ndc$year, comm = "CO2"),
  term1 = list(variable = "vEmsFuelTot"),
  rhs = data.frame(year = ndc$year, rhs = ndc$factor * E2025),
  defVal = Inf)
```

On the multi-year models (`pypsa_eur_41v`, the integrated
`pypsa_eur_41i`) the cap binds at every milestone; between anchor rows
the right-hand side interpolates linearly.

## Solving a scenario

``` r

m <- add(pypsa_eur_41i, CO2_NDC)
scen <- interpolate_model(
  m, name = "ndc",
  calendar = calendars$d365_h24_1dpm)
scen <- solve_scenario(scen, solver = solver_options$julia_highs)
```

The comparison of the solved policy scenarios — capacity, dispatch,
retirement and cost against the unconstrained baseline — belongs to the
results pages as solves accumulate.

## Sources

- [Directive (EU)
  2023/959](https://eur-lex.europa.eu/legal-content/EN/TXT/PDF/?uri=CELEX:32023L0959)
  — the revised EU ETS (linear reduction factors, rebasing).
- [EU ETS emissions
  cap](https://climate.ec.europa.eu/areas-action/carbon-markets/eu-emissions-trading-system-eu-ets/eu-ets-emissions-cap_en)
  — European Commission.
- [The EU’s updated NDC, November
  2025](https://www.consilium.europa.eu/en/press/press-releases/2025/11/05/paris-agreement-the-eu-submits-its-updated-ndc-with-an-indicative-target-for-2035-to-the-un-ahead-of-cop30/)
  — Council of the EU.
- [The 2040 climate
  target](https://climate.ec.europa.eu/areas-action/climate-strategies-targets/2040-climate-target_en)
  — European Commission.
