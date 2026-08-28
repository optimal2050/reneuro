# A solved Belgium scenario

[pypsa_eur_5](https://optimal2050.github.io/reneuro/r/reference/pypsa_eur_models.md)
interpolated and solved with GLPK. It ships so the vignettes can show
results without requiring a solver at build time.

## Usage

``` r
be_solved
```

## Format

An [energyRt](https://energyRt.org/reference/energyRt-package.html)
`scenario` object with its solution attached.

## Source

Solved by `data-raw/make_be_solved.R`. Same data licence and provenance
as
[pypsa_eur_models](https://optimal2050.github.io/reneuro/r/reference/pypsa_eur_models.md).

## Details

The objective is `164664296.503735`. That figure is a regression gate
rather than a curiosity: `data-raw/make_be_solved.R` refuses to save a
scenario that does not reproduce it, so this object cannot silently
drift.

The value corresponds to the six-tranche loss default. Converting the
same network with `tranches = NULL` – a single flat loss rate, rung 1 of
the transmission ladder – gives `164899752.517096` instead.

## Examples

``` r
attr(be_solved, "reneuro_provenance")$objective
#> [1] 164664297
```
