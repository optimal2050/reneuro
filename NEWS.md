# reneuro 0.0.0.9000

* New `build_scales()`, `attach_scales()` and `join_scales()` group solved
  results by frames parsed from the model's own process and commodity names --
  carrier, tier, cluster, vintage and a report label. Both name grammars are
  handled, and the optional `_VIN` suffix no longer has to be stripped by hand.
  `build_scales()` returns the scales, `attach_scales()` also stores them in
  `@misc$scales`, and `join_scales()` accepts either. Three name grammars,
  export and import objects, and the optional `_VIN` suffix are all covered.
* `data-raw/compare_41q_extract.R` labels carriers and tiers from the process
  scale instead of its own regex cascade, and now warns by name when a
  technology in the results is absent from the model.
* `tech_ms`'s `fuel` frame is no longer described as the model commodity: it
  carries powerplantmatching's vocabulary, which shares no names with the
  model's.
* New article "Regions and calendars": the two geoscales, what a region
  carries, `recast_geoscale()`, the shipped calendars and the sampled subsets.
  It states the two rules that are easy to violate silently -- the calendar
  must be finer than any storage is long, and objects must name timeslices the
  calendar carries, or the objective collapses to zero without error.
* The articles are shorter and documentation-style throughout.
* New article "Storage": the four storage objects every model carries, their
  three separately-sized capacities, and where `duration` comes from. Hydro
  reservoir durations span 6 hours to 17,544 -- a 6-hour floor applied where
  data is missing (including Ukraine's 7.2 GW) and, at the other end, small
  clustered power divided into a coarse country reservoir figure, giving
  Belgium 12.7 MW of hydro against 200 GWh.
* New article "Demand": the measured 2025 year, the TYNDP 2024 growth paths,
  and extreme paths multiplying demand 2x, 3x and 5x by 2050 -- from 3,356 TWh
  to between 6,713 and 16,782 TWh, against TYNDP's 4,372-5,625. It also states
  the two ceilings on useful spatial resolution: 1,477 NUTS3 regions share 36
  distinct load shapes, and 442 of them carry no demand at all.
* New article "Transmission", comparing the four datasets that describe the
  same European grid: OpenStreetMap (what the models use), the ENTSO-E
  interactive map via GridKit, the TYNDP 2020 project pipeline, and Ember's
  market NTC. Over the 79 shared live borders the models carry 377 GW where
  Ember reports 112 GW -- and every border where the two agree is a DC link,
  every DC link agrees.
* `transmission = "ember"` in that article re-caps each corridor to market
  NTC, apportioned across bus pairs by thermal share. The default `"pypsa"`
  leaves the shipped corridors untouched.
* New article "Energy supply": what each fuel costs, how much of it there is,
  and where. It corrects the shipped models' assumption that every fuel is
  unlimited at one continental price, and solves standalone through a
  stand-in electricity carrier.
* New dataset `biomass_potential`: the JRC ENSPRESO biomass assessment for
  the 36 modelled countries -- potential and cost by commodity, scenario and
  year. 2050 totals run 2,171 TWh (`ENS_Low`) to 5,877 TWh (`ENS_High`)
  against a flat 9.35 EUR/MWh unlimited supply today.
* New `data-raw/modules/build_modules.R`: articles are now the source of
  truth for the assembly, and this harvests them by tangling. Each article
  declares the objects it must leave behind, so one that stops producing a
  declared object fails the build instead of drifting silently.
* `vignette("translation")` no longer claims fuel supplies are priced at
  zero. That was true before `convert_pypsa(costs = )`; every shipped
  continental model now carries the price on the supply.
* New article "Capacity stock": where the existing fleet comes from, what the
  commissioning year is worth, and why the converted network has none. PyPSA's
  generator aggregation sets `build_year = 0` and `lifetime = Inf`, so a
  `.nc` carries an undated, immortal fleet; the unit list one step upstream
  dates 93.5% of capacity back to 1898.
* New `capacity_stock()` aggregates a `powerplants_s_<N>.csv` unit list to any
  combination of region, technology level and build-year cohort, re-aggregating
  the technology axis through `tech_ms` and the region axis through a geoscale.
* New datasets `tech_ms` and `fuel_ms`: the technology and carrier taxonomies
  as `multiscales` scales. `tech_ms` has 45 atoms -- the `(Fueltype,
  Technology)` pair, since neither column identifies a technology on its own --
  under five frames, of which `class` and `origin` deliberately cross-cut.
* New dataset `jrc_units`: per-unit efficiency and commissioning year from
  JRC-PPDB-OPEN, covering 55% of thermal capacity. Check `eff_source` before
  treating a value as a measurement; `ramp_up` and `min_load` ship for
  inspection but should not be loaded (see `?jrc_units`).
* The fleet rules moved from `data-raw/retire.R` and `data-raw/vintages.R`
  into `R/fleet.R`, documented. The two scripts remain as shims, so existing
  build scripts are unchanged.
* `apply_retirement()` no longer skips carriers silently. It reports the
  84.4 GW with no generator technology and warns on the 5.47 GW not covered by
  `known_missing` -- blank-`Technology` hydro and gas, `other`, and a literal
  `"Steam Turbine"` carrier that previously escaped ageing unnoticed.
* `capacity_stock()` keeps units with no `DateIn` as an explicit undated group
  rather than letting `aggregate()` drop them -- 6.5% of capacity.
* `pypsa_eur_41v` reworked: the existing fleet is one `STOCK` vintage per
  carrier carrying the summed retirement path, and gas gains `NEW<year>`
  vintage windows that freeze each assumption year's efficiency, lifetime and
  annuity. The fleet's milestone totals are unchanged.
* Every shipped model now has its own upper-case `@name`. Nine of the eleven
  previously carried the converter default `"pypsa"`, which collided in
  scenario directory names (`EX41_2050-pypsa-...`).
* `pypsa_eur_5` and `pypsa_eur_5cp` can be interpolated again. Their stored
  calendar predated the annualised-`ANNUAL` convention, so
  `interpolate_model(pypsa_eur_5, name = "be")` -- the documented quick
  start -- stopped on a guard.
* Shipped models rebuilt on the current converter: `E_BIOMASS` variable cost
  is exactly zero rather than ~3.6e-15, and `weather` slots carry the
  `transform` column. No other values change.
* New dataset `tyndp_demand`: electricity-demand growth factors by country,
  scenario and milestone year from the TYNDP 2024 scenarios (NT+, Distributed
  Energy, Global Ambition), anchored at the measured 2025 load.
* New `grow_demand()` builds year-keyed demand from a base-year profile and
  any growth-factor table; `build_demand()` wraps it with a source model,
  name, and optional year/region selection.
* In `policy_paths` the ETS-shape scenario is named `ets_cap` (was
  `current_policy`): the legislated linear reduction factors make it the
  tightest of the three paths, and the old name misread as a contradiction.
* New dataset `policy_paths`: three CO2-cap trajectories as factors on 2025
  emissions (the EU ETS shape, the EU NDC pledges, linear net-zero 2050),
  and a Scenarios article showing carbon caps and a carbon tax built with
  plain constraints and taxes on the shipped models.
* The translation article gains a "Revised assumptions" section documenting
  the deliberate deviations shipped as separate model versions: atlas-anchored
  capacity factors, economic retirement, and TYNDP demand growth.

* `nuts_load` and `nuts_lines` region codes are normalized to the same
  underscore convention as `nuts_gs`, so joins across the three datasets
  match for the non-NUTS countries (BA, MD, UA, XK).

* `pypsa_eur_289` and `pypsa_eur_1035` are no longer shipped. The coarser NUTS
  levels are derived from `pypsa_eur_nuts3` with
  `energyRt::aggregate_model_regions()`, and subsetting starts from
  `pypsa_eur_nuts3` directly.

* All shipped models are rebuilt with corrected calendar chronology:
  converter-built calendars ordered timeslices hour-major, so storage could
  not carry energy from one hour to the next. The converted Belgium model
  now reproduces PyPSA's solution within 0.02%. `be_solved` solves to a new
  objective gate (164,899,752.517).
* `convert_pypsa()` gains `expand_transmission`: corridors become
  investable at PyPSA's line costs, for comparing against networks solved
  with transmission expansion.

* All four continental models are rebuilt on **2025 weather and load**
  (ENTSO-E measured demand, the `europe-2025-sarah3-era5` cutout). Regions,
  object names and the existing fleet are unchanged from the 2013 build; the
  demand year total moves from 3,356 to 3,163 TWh.
* New one-year horizon series `pypsa_eur_41_2025` ... `pypsa_eur_41_2050`:
  per-horizon cost vintages and a fleet aged by announced `DateOut` schedules
  plus assumed carrier lifetimes, recorded separately in provenance. The
  series ships without weather; `attach_weather(m, from = pypsa_eur_41)`
  restores it.
* New vintaged multi-year model `pypsa_eur_41v`: the 41-node system over
  2025-2050 milestones, existing fleet split into build-year vintages with
  per-vintage efficiency and retirement, plus one investable path per carrier
  with year-keyed costs. Ships without weather, like the horizon series.
* `attach_weather()` gains `from =`, to copy weather objects from another
  model.
* Every model carries a `reneuro_provenance` attribute recording the upstream
  commit and the weather, load, capacity and cost years; the build scripts
  refuse to save without it.

* `pypsa_eur_41` is rebuilt. Its corridors are flat: the six loss tranches it
  carried -- the converter's default when it was built -- became 224,640
  generated constraints on a 288-slice calendar, 91% of the solver exchange
  files, and no open solver generated them in reasonable time. Every other
  continental model was already `tranches = NULL`.
* `pypsa_eur_41` also has its fuel costs separated: `varom` holds the true VOM
  and each fuel's supply carries its price, taken from the cost table the
  network was built from. The objective is unchanged -- the split is exact --
  and the fuel price is now a number you can vary. Its regions, object names
  and technology stock are unchanged; only trade and the cost split differ.
* Every technology and storage port carries its commodity's unit.
* `data-raw/pypsa_eur_41.R` builds it, so all six shipped models now have a
  build script. The docs name where each lives: this package's `data-raw/`
  for the continental models, `reneuro.dev/data-raw/` for the Belgian ones.

* The website's data documentation is reorganized into four articles:
  "Data in PyPSA-Eur 41-node" (what ships in the 41-node model, with mean
  capacity-factor, demand and network maps), "Data sources" (the upstream
  inputs and the NUTS processing), and new "Wind energy" and "Solar energy"
  articles.
* The wind article documents a quality-aware resource layer: the Global
  Wind Atlas beside the cutout, carved wind-quality areas over the full
  atlas window, an eligibility threshold and resource clusters with
  capacity-factor tiers, and speed-domain calibration along an aggregate
  park power curve.
* The solar article compares the cutout with the Global Solar Atlas (the
  gap is flat -- no calibration applied) and splits the solar supply into
  yield levels with the same carving machinery.
* A data-sources article shows the upstream inputs -- the weather cutout,
  measured ENTSO-E demand, the plant fleet, the network -- as maps and
  figures, with a source/licence table.
* Two website articles show what `report()` produces: a model report for
  `pypsa_eur_41` and a scenario report for the same model solved on a sampled
  calendar. Each gives the call that derives it and then embeds the rendered
  report, built by `data-raw/example_reports.R`.

* `pypsa_eur_nuts3`: the NUTS3 network over the full year, 1,035 regions and
  8,760 hourly snapshots. Its weather profiles ship as seven `wx_nuts3_*`
  objects, since the model whole is 181 MB and past GitHub's file limit;
  `attach_weather()` puts back the ones a study needs and
  `weather_resources()` lists them.
* `pypsa_eur_nuts3` carries `nuts_gs`, so the coarser NUTS levels are derived
  rather than shipped: `energyRt::aggregate_model_regions(pypsa_eur_nuts3,
  level = "nuts1")` gives 36 regions at NUTS0, 106 at NUTS1 and 289 at NUTS2.
* `nuts_gs` is now keyed the way the models are. `convert_pypsa()` rewrites
  every non-alphanumeric character, so the adm1 codes of Bosnia, Moldova,
  Ukraine and Kosovo reach a model as `BA_BIH` where the geoscale had
  `BA-BIH`. The two disagreed on 37 regions -- every region of those four
  countries -- and aggregating a model against the geoscale dropped them.

* `nuts_gs` now carries per-region demand, existing capacity and renewable
  potential alongside area, population and GDP, and declares seven of them as
  weights. Rebuilt by `data-raw/nuts_gs.R`.

* Three vignettes: `vignette("reneuro")` walks a model end to end and carves a
  local model out of NUTS3; `vignette("data")` covers what ships and what
  changing spatial resolution does to it; `vignette("about")` holds the model
  provenance, solver benchmarks, references and licences moved out of the
  README.

* Initial package skeleton, pkgdown site and project documentation.
