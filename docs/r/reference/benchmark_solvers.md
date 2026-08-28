# Solve one scenario with several solvers and compare

Solves an interpolated scenario once per solver option set and returns
runtime and objective for each, so back ends can be compared on the same
linear programme.

## Usage

``` r
benchmark_solvers(scen, solvers = NULL, tol = 1e-06, verbose = TRUE)
```

## Arguments

- scen:

  an interpolated scenario, from
  [`energyRt::interpolate_model()`](https://energyRt.org/reference/interpolate_model.html).

- solvers:

  character vector of names in `energyRt::solver_options`, or a named
  list of option sets. Defaults to the open solvers reported available
  by
  [`open_solvers()`](https://optimal2050.github.io/reneuro/r/reference/open_solvers.md).

- tol:

  relative objective difference treated as agreement.

- verbose:

  report each run as it completes.

## Value

A data frame with `solver`, `seconds`, `objective`, `status` and
`agrees`, ordered by runtime. The reference for `agrees` is the first
successful run.

## Details

Every run receives the same scenario, so the objectives are expected to
agree to solver tolerance. A disagreement larger than `tol` is reported
in the `agrees` column and is a signal to investigate the back end, not
the model.

Solving is sequential. A back end that fails records the error and does
not stop the remaining runs.

## Solver choice by model size

Relative performance depends strongly on model size, and the ordering
reverses across the range. Measured on one workstation; treat the ratios
rather than the absolute times as transferable.

|                         |          |         |           |
|-------------------------|----------|---------|-----------|
| **model**               | **GLPK** | **CBC** | **HiGHS** |
| 5 regions, 168 h        | 10 s     | 19 s    | 24-47 s   |
| 69 regions, 96 slices   | 2158 s   | 809 s   | 79-82 s   |
| 1035 regions, 96 slices | –        | –       | 18.5 min  |

On the smallest models GLPK wins on start-up cost alone. From roughly a
hundred thousand rows onward HiGHS dominates: at 69 regions it is 27
times faster than GLPK, and the gap widens with size.

At 1035 regions on a 96-slice sample the linear programme is 1.3 million
rows after presolve, solved by HiGHS interior point in about 16 minutes.
Extending the same model to 672 slices produces 9.4 million rows after
presolve, at which point the interior-point method fails to return a
solution; a first-order method (`solver = "pdlp"`) or dual simplex is
the route to test at that size.

Julia carries a fixed start-up cost of 20-30 seconds per invocation for
just-in-time compilation, which dominates small models and is amortised
across a session. Pyomo starts in a few seconds. For a single small
solve Pyomo is therefore quicker end to end even where Julia's solver
call is faster.

## See also

[`open_solvers()`](https://optimal2050.github.io/reneuro/r/reference/open_solvers.md)

## Examples

``` r
if (FALSE) { # \dontrun{
scen <- energyRt::interpolate_model(pypsa_eur_5, name = "be")
benchmark_solvers(scen)
} # }
```
