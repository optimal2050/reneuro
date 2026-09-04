# Model report

A model report documents what goes **into** a run: the regions, horizon
and calendar, an inventory of commodities, supplies, demands and trade,
and then every technology and storage in turn with its diagram and
parameters. It describes assumptions, not results —
`vignette("report-scenario")` is the counterpart for a solved run.

The one below is `pypsa_eur_41`, 41 nodes over the full year. Deriving
it is one call, and takes about five seconds:

``` r

library(energyRt)
library(reneuro)

report(pypsa_eur_41)
```

Without arguments the report lands in
[`get_reports_path()`](https://energyRt.org/reference/reports_path.html)
and opens in the browser. `template = "summary"` drops the per-process
sections; `format =` also accepts `"pdf"`, `"tex"` and `"docx"`;
`name = "E_CCGT"` narrows the whole thing to a datasheet for one
process. [`?report`](https://energyRt.org/reference/report.html) covers
the rest.

[**Open the report in its own
tab**](https://optimal2050.github.io/reneuro/reports/pypsa_eur_41_model.md)
