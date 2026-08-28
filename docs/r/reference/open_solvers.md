# Open-solver option sets available on this system

Lists the `energyRt` solver option sets that use an open solver, and
reports which of them this system can run.

## Usage

``` r
open_solvers(check = TRUE)
```

## Arguments

- check:

  logical. Test each back end, rather than only listing the option sets.

## Value

A data frame with one row per option set: `option`, `lang`, `solver`,
and `available` when `check = TRUE`.

## Details

Availability is determined per back end: GLPK requires the `glpsol`
executable, JuMP requires Julia with the corresponding package, and
Pyomo requires Python with the solver interface. A back end that cannot
be reached is reported rather than silently skipped.

## See also

[`benchmark_solvers()`](https://optimal2050.github.io/reneuro/r/reference/benchmark_solvers.md)

## Examples

``` r
open_solvers(check = FALSE)
#>                  option  lang      solver
#> 1                  glpk  GLPK        <NA>
#> 2             pyomo_cbc PYOMO         cbc
#> 3       pyomo_cbc_arrow PYOMO         cbc
#> 4            pyomo_glpk PYOMO        glpk
#> 5           pyomo_highs PYOMO appsi_highs
#> 6   pyomo_highs_barrier PYOMO appsi_highs
#> 7             julia_cbc  JuMP         Cbc
#> 8           julia_highs  JuMP       HiGHS
#> 9     julia_highs_arrow  JuMP       HiGHS
#> 10  julia_highs_barrier  JuMP       HiGHS
#> 11           julia_glpk  JuMP        GLPK
#> 12  julia_highs_simplex  JuMP       HiGHS
#> 13 julia_highs_parallel  JuMP       HiGHS
#> 14         gams_csv_cbc  GAMS         CBC
#> 15         gams_gdx_cbc  GAMS         CBC
```
