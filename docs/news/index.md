# Changelog

## reneuro 0.0.0.9000

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
