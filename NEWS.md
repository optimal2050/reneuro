# reneuro 0.0.0.9000

* `nuts_gs` now carries per-region demand, existing capacity and renewable
  potential alongside area, population and GDP, and declares seven of them as
  weights. Rebuilt by `data-raw/nuts_gs.R`.

* Three vignettes: `vignette("reneuro")` walks a model end to end and carves a
  local model out of NUTS3; `vignette("data")` covers what ships and what
  changing spatial resolution does to it; `vignette("about")` holds the model
  provenance, solver benchmarks, references and licences moved out of the
  README.

* Initial package skeleton, pkgdown site and project documentation.
