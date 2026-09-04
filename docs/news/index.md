# Changelog

## reneuro 0.0.0.9000

- `pypsa_eur_289` and `pypsa_eur_1035` are no longer shipped. The
  coarser NUTS levels are derived from `pypsa_eur_nuts3` with
  [`energyRt::aggregate_model_regions()`](https://energyRt.org/reference/aggregate_model_regions.html),
  and subsetting starts from `pypsa_eur_nuts3` directly.

- All shipped models are rebuilt with corrected calendar chronology:
  converter-built calendars ordered timeslices hour-major, so storage
  could not carry energy from one hour to the next. The converted
  Belgium model now reproduces PyPSA’s solution within 0.02%.
  `be_solved` solves to a new objective gate (164,899,752.517).

- `convert_pypsa()` gains `expand_transmission`: corridors become
  investable at PyPSA’s line costs, for comparing against networks
  solved with transmission expansion.

- All four continental models are rebuilt on **2025 weather and load**
  (ENTSO-E measured demand, the `europe-2025-sarah3-era5` cutout).
  Regions, object names and the existing fleet are unchanged from the
  2013 build; the demand year total moves from 3,356 to 3,163 TWh.

- New one-year horizon series `pypsa_eur_41_2025` … `pypsa_eur_41_2050`:
  per-horizon cost vintages and a fleet aged by announced `DateOut`
  schedules plus assumed carrier lifetimes, recorded separately in
  provenance. The series ships without weather;
  `attach_weather(m, from = pypsa_eur_41)` restores it.

- New vintaged multi-year model `pypsa_eur_41v`: the 41-node system over
  2025-2050 milestones, existing fleet split into build-year vintages
  with per-vintage efficiency and retirement, plus one investable path
  per carrier with year-keyed costs. Ships without weather, like the
  horizon series.

- [`attach_weather()`](https://optimal2050.github.io/reneuro/reference/attach_weather.md)
  gains `from =`, to copy weather objects from another model.

- Every model carries a `reneuro_provenance` attribute recording the
  upstream commit and the weather, load, capacity and cost years; the
  build scripts refuse to save without it.

- `pypsa_eur_41` is rebuilt. Its corridors are flat: the six loss
  tranches it carried – the converter’s default when it was built –
  became 224,640 generated constraints on a 288-slice calendar, 91% of
  the solver exchange files, and no open solver generated them in
  reasonable time. Every other continental model was already
  `tranches = NULL`.

- `pypsa_eur_41` also has its fuel costs separated: `varom` holds the
  true VOM and each fuel’s supply carries its price, taken from the cost
  table the network was built from. The objective is unchanged – the
  split is exact – and the fuel price is now a number you can vary. Its
  regions, object names and technology stock are unchanged; only trade
  and the cost split differ.

- Every technology and storage port carries its commodity’s unit.

- `data-raw/pypsa_eur_41.R` builds it, so all six shipped models now
  have a build script. The docs name where each lives: this package’s
  `data-raw/` for the continental models, `reneuro.dev/data-raw/` for
  the Belgian ones.

- A data-sources article shows the upstream inputs – the weather cutout,
  measured ENTSO-E demand, the plant fleet, the network – as maps and
  figures, with a source/licence table.

- Two website articles show what
  [`report()`](https://energyRt.org/reference/report.html) produces: a
  model report for `pypsa_eur_41` and a scenario report for the same
  model solved on a sampled calendar. Each gives the call that derives
  it and then embeds the rendered report, built by
  `data-raw/example_reports.R`.

- `pypsa_eur_nuts3`: the NUTS3 network over the full year, 1,035 regions
  and 8,760 hourly snapshots. Its weather profiles ship as seven
  `wx_nuts3_*` objects, since the model whole is 181 MB and past
  GitHub’s file limit;
  [`attach_weather()`](https://optimal2050.github.io/reneuro/reference/attach_weather.md)
  puts back the ones a study needs and
  [`weather_resources()`](https://optimal2050.github.io/reneuro/reference/weather_resources.md)
  lists them.

- `pypsa_eur_nuts3` carries `nuts_gs`, so the coarser NUTS levels are
  derived rather than shipped:
  `energyRt::aggregate_model_regions(pypsa_eur_nuts3, level = "nuts1")`
  gives 36 regions at NUTS0, 106 at NUTS1 and 289 at NUTS2.

- `nuts_gs` is now keyed the way the models are. `convert_pypsa()`
  rewrites every non-alphanumeric character, so the adm1 codes of
  Bosnia, Moldova, Ukraine and Kosovo reach a model as `BA_BIH` where
  the geoscale had `BA-BIH`. The two disagreed on 37 regions – every
  region of those four countries – and aggregating a model against the
  geoscale dropped them.

- `nuts_gs` now carries per-region demand, existing capacity and
  renewable potential alongside area, population and GDP, and declares
  seven of them as weights. Rebuilt by `data-raw/nuts_gs.R`.

- Three vignettes:
  [`vignette("reneuro")`](https://optimal2050.github.io/reneuro/articles/reneuro.md)
  walks a model end to end and carves a local model out of NUTS3;
  [`vignette("data")`](https://optimal2050.github.io/reneuro/articles/data.md)
  covers what ships and what changing spatial resolution does to it;
  [`vignette("about")`](https://optimal2050.github.io/reneuro/articles/about.md)
  holds the model provenance, solver benchmarks, references and licences
  moved out of the README.

- Initial package skeleton, pkgdown site and project documentation.
