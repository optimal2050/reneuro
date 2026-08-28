# Changelog

## reneuro 0.0.0.9000

- `nuts_gs` now carries per-region demand, existing capacity and
  renewable potential alongside area, population and GDP, and declares
  seven of them as weights. Rebuilt by `data-raw/nuts_gs.R`.

- Three vignettes:
  [`vignette("reneuro")`](https://optimal2050.github.io/reneuro/r/articles/reneuro.md)
  walks a model end to end and carves a local model out of NUTS3;
  [`vignette("data")`](https://optimal2050.github.io/reneuro/r/articles/data.md)
  covers what ships and what changing spatial resolution does to it;
  [`vignette("about")`](https://optimal2050.github.io/reneuro/r/articles/about.md)
  holds the model provenance, solver benchmarks, references and licences
  moved out of the README.

- Initial package skeleton, pkgdown site and project documentation.
