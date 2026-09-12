# Solving models on GPUs via Hugging Face

Some networks are too large for an open-source CPU solver. The 41-node,
full-year European network shipped with this project has **36.1 million
non-zeros**, and HiGHS does not solve it. A GPU does, in about three
minutes, on rented hardware costing well under a dollar.

`linopy-hf` (in `linopy-hf/` in this repository) makes that a one-line
change to an ordinary PyPSA call. It is a Python package, independent of
the reneuro R package — it is kept here for convenience while it
stabilises.

## What it does

PyPSA builds its optimisation problem with
[linopy](https://github.com/PyPSA/linopy), which has a `remote=` hook
for solving elsewhere. `linopy-hf` implements that hook: it serialises
the model, runs a job on a Hugging Face GPU, and reads the solved model
back. Nothing in PyPSA or linopy is patched, and **the solver never has
to be installed locally** — the client needs only `linopy`,
`huggingface_hub` and `netcdf4`.

          your machine                    Hugging Face Jobs
     ┌──────────────────┐            ┌──────────────────────────┐
     │ n.optimize(      │  netCDF    │ pip install linopy[gpu]   │
     │   remote=HFHandler) ───────►  │ linopy.read_netcdf(...)   │
     │                  │            │   .solve("cuopt")         │
     │ n.buses_t.       │  ◄───────  │ .to_netcdf(...)           │
     │   marginal_price │  netCDF    │                           │
     └──────────────────┘            └──────────────────────────┘

## Usage

``` python
from linopy_hf import HFHandler
import pypsa

n = pypsa.Network("resources/entsoe-2025/networks/base_s_41_elec.nc")

n.optimize(
    remote=HFHandler(flavor="a10g-large", namespace="<your-hf-org>"),
    solver_name="cuopt",
)

n.objective                 # 45,635,195,214.39
n.buses_t.marginal_price    # populated: duals come back
```

Authentication uses your existing Hugging Face token (`HF_TOKEN`, or
`hf auth login`). Jobs are billed to the account or organisation you
name.

## Choosing hardware

`linopy_hf.sizing` estimates what a model needs and picks the cheapest
flavour that holds it. The constants are measured, not guessed.

``` python
from linopy_hf.sizing import describe
describe(36_088_734)
# 36,088,734 raw nnz (~18,044,367 presolved) -> t4-medium ($0.6/h):
#   needs ~13.58 GB VRAM, ~23.46 GB host
```

**Memory depends on the algorithm, not only on the matrix.** These
estimates assume PDLP. The barrier method on the same 36M-nonzero model
tried to allocate **118.9 GB** of GPU memory. That is why the handler
sets `method=1` by default — see below.

## Benchmarks

All figures measured on the networks in this repository, September 2026.

### BE-5 (`base_s_5_elec_`, 168 snapshots, 51,884 non-zeros)

Small enough for HiGHS, so it serves as the correctness reference.

| solver            | objective     | error vs HiGHS | prices (mean) |
|-------------------|---------------|----------------|---------------|
| HiGHS (local CPU) | 54,551,017.53 | —              | 65.46         |
| cuOpt (T4)        | 54,551,162.90 | 2.7e-06        | 65.57         |
| cuPDLPx (T4)      | 54,558,980.57 | 1.5e-04        | 65.71         |

cuOpt is roughly 50x more accurate than cuPDLPx here, returns duals, and
needs no compilation — it is the default for those reasons.

Adding crossover recovers the exact vertex optimum:

| options                 | objective           | error vs HiGHS | solve |
|-------------------------|---------------------|----------------|-------|
| `method=1`              | 54,558,977.82       | 1.5e-04        | 1.1 s |
| `method=1, crossover=1` | **54,551,017.5294** | **exact**      | 1.4 s |

### 41-node, full year (`base_s_41_elec`, 8,760 snapshots, 36.1M non-zeros)

**HiGHS cannot solve this model.** Both GPU runs agree to sixteen
significant figures, and the objective was verified independently
against operating plus capital costs recomputed from the solution.

|             | a10g-large            | h200                  |
|-------------|-----------------------|-----------------------|
| solve       | 1210.2 s              | **185.7 s**           |
| netCDF read | 207.4 s               | 510.6 s               |
| write       | 25.4 s                | 12.6 s                |
| wall        | 1595.7 s              | 860.9 s               |
| rate        | \$1.50/h              | \$5.00/h              |
| **cost**    | **\$0.66**            | \$1.20                |
| objective   | 45,635,195,214.390945 | 45,635,195,214.390945 |

Two things worth reading off this table. The H200 solves 6.5x faster —
PDLP is bandwidth-bound and the H200 has roughly eight times the memory
bandwidth — but the cheaper card still **wins on total cost**, because
the hourly rate differs by 3.3x and much of the job is not solving.

And **transport dominates**: on the H200, 59% of the job was spent
parsing netCDF against 22% solving. At this scale the bottleneck is
moving the model, not solving it.

## Defaults that matter

Each of these was established by a failure, and each is set for you.

**`method=1` (PDLP).** linopy defaults cuOpt to `method=3` (barrier),
because cuOpt’s own default of 0 (concurrent) crashes. Barrier is the
wrong choice at this scale — it asked for 118.9 GB of VRAM on a 22 GB
card and died with `Out of memory in barrier_solver_t`.

**`io_api="direct"`.** GPU solvers in linopy have no file interface;
without this you get “linopy currently only supports reading models from
netcdf files”.

**Solver option names differ.** cuOpt uses snake_case (`time_limit`,
`relative_gap_tolerance`), cuPDLPx uses `TimeLimit`. Passing the wrong
one is rejected outright.

**The objective is always recomputed.** linopy misreports the objective
for GPU solvers on some models — sign-flipped and about twice the
magnitude — while the solution itself, the dispatch, the capacities and
the duals are all correct. The worker recomputes it as `c·x` from the
objective vector and the returned solution, prefers that when they
disagree, and records both:

``` json
"objective_check": {"cx": 54551017.53, "reported": -55163387.07,
                    "relative_disagreement": 2.011}
```

This is deliberately loud. A wrong objective with a plausible solution
is the most dangerous failure mode available: comparing objectives alone
would condemn a correct solver, and inspecting prices and capacities
alone would miss it entirely. The discrepancy is unexplained, survives
crossover and every method setting, and does not occur on all models.

## Reproducing the benchmarks

``` bash
cd linopy-hf/benchmarks
python run_bench.py <network.nc> --tag be5 --method highs
python run_bench.py <network.nc> --tag be5 --method hf --flavor t4-small
```

Each run writes a JSON record and the solved network to
`linopy-hf/benchmarks/results/`, including model size, timings, price
statistics, generation and capacity by carrier, and the independent
objective check.

## Limitations

- cuOpt support is on linopy’s **master branch**, not yet in a release,
  so the worker installs linopy from git.
- Linear problems only; cuPDLPx additionally rejects quadratic and
  mixed-integer problems, so unit commitment is out.
- Job scheduling latency on Hugging Face is unpredictable — usually
  seconds, occasionally many minutes. For small models this dominates
  everything else, and a GPU is not worth using.
- The netCDF round trip is heavy: 2.7 GB for the 41-node full-year
  model.
