# Benchmarking a model across open solvers --------------------------------------
#
# The same interpolated scenario is handed to each back end in turn. Only the
# solver option set differs, so the linear programme is identical and any
# difference in objective indicates a back-end problem rather than a modelling
# choice.

#' Open-solver option sets available on this system
#'
#' @description
#' Lists the `energyRt` solver option sets that use an open solver, and reports
#' which of them this system can run.
#'
#' @details
#' Availability is determined per back end: GLPK requires the `glpsol`
#' executable, JuMP requires Julia with the corresponding package, and Pyomo
#' requires Python with the solver interface. A back end that cannot be reached
#' is reported rather than silently skipped.
#'
#' @param check logical. Test each back end, rather than only listing the
#'   option sets.
#'
#' @return A data frame with one row per option set: `option`, `lang`,
#'   `solver`, and `available` when `check = TRUE`.
#'
#' @examples
#' open_solvers(check = FALSE)
#' @seealso [benchmark_solvers()]
#' @export
open_solvers <- function(check = TRUE) {
  opts <- energyRt::solver_options
  keep <- grep("glpk|cbc|highs", names(opts), value = TRUE)
  keep <- keep[!grepl("^neos", keep)]        # NEOS is remote, not local
  out <- data.frame(
    option = keep,
    lang   = vapply(opts[keep], function(o) o$lang %||% NA_character_, ""),
    solver = vapply(opts[keep], function(o) o$solver %||% NA_character_, ""),
    stringsAsFactors = FALSE
  )
  if (isTRUE(check)) out$available <- vapply(out$lang, .backend_available, TRUE)
  rownames(out) <- NULL
  out
}

# Is the back end reachable? Each is tested by the thing it actually needs.
.backend_available <- function(lang) {
  switch(
    toupper(lang),
    GLPK  = nzchar(Sys.which("glpsol")) ||
            nzchar(Sys.which(file.path(energyRt::get_glpk_path(), "glpsol"))),
    JUMP  = nzchar(Sys.which("julia")) ||
            nzchar(Sys.which(file.path(energyRt::get_julia_path(), "julia"))),
    PYOMO = nzchar(Sys.which(file.path(energyRt::get_python_path(), "python"))) ||
            nzchar(Sys.which("python")),
    FALSE
  )
}

#' Solve one scenario with several solvers and compare
#'
#' @description
#' Solves an interpolated scenario once per solver option set and returns
#' runtime and objective for each, so back ends can be compared on the same
#' linear programme.
#'
#' @details
#' Every run receives the same scenario, so the objectives are expected to
#' agree to solver tolerance. A disagreement larger than `tol` is reported in
#' the `agrees` column and is a signal to investigate the back end, not the
#' model.
#'
#' Solving is sequential. A back end that fails records the error and does not
#' stop the remaining runs.
#'
#' @section Solver choice by model size:
#' Relative performance depends strongly on model size, and the ordering
#' reverses across the range. Measured on one workstation; treat the ratios
#' rather than the absolute times as transferable.
#'
#' \tabular{llll}{
#'   \strong{model} \tab \strong{GLPK} \tab \strong{CBC} \tab \strong{HiGHS} \cr
#'   5 regions, 168 h      \tab 10 s   \tab 19 s   \tab 24-47 s \cr
#'   69 regions, 96 slices \tab 2158 s \tab 809 s  \tab 79-82 s \cr
#'   1035 regions, 96 slices \tab --   \tab --     \tab 18.5 min \cr
#' }
#'
#' On the smallest models GLPK wins on start-up cost alone. From roughly a
#' hundred thousand rows onward HiGHS dominates: at 69 regions it is 27 times
#' faster than GLPK, and the gap widens with size.
#'
#' At 1035 regions on a 96-slice sample the linear programme is 1.3 million
#' rows after presolve, solved by HiGHS interior point in about 16 minutes.
#' Extending the same model to 672 slices produces 9.4 million rows after
#' presolve, at which point the interior-point method fails to return a
#' solution; a first-order method (`solver = "pdlp"`) or dual simplex is the
#' route to test at that size.
#'
#' Julia carries a fixed start-up cost of 20-30 seconds per invocation for
#' just-in-time compilation, which dominates small models and is amortised
#' across a session. Pyomo starts in a few seconds. For a single small solve
#' Pyomo is therefore quicker end to end even where Julia's solver call is
#' faster.
#'
#' @param scen an interpolated scenario, from
#'   [energyRt::interpolate_model()].
#' @param solvers character vector of names in
#'   `energyRt::solver_options`, or a named list of option sets. Defaults to
#'   the open solvers reported available by [open_solvers()].
#' @param tol relative objective difference treated as agreement.
#' @param verbose report each run as it completes.
#'
#' @return A data frame with `solver`, `seconds`, `objective`, `status` and
#'   `agrees`, ordered by runtime. The reference for `agrees` is the first
#'   successful run.
#'
#' @examples
#' \dontrun{
#' scen <- energyRt::interpolate_model(pypsa_eur_5, name = "be")
#' benchmark_solvers(scen)
#' }
#' @seealso [open_solvers()]
#' @export
benchmark_solvers <- function(scen,
                              solvers = NULL,
                              tol = 1e-6,
                              verbose = TRUE) {
  if (is.null(solvers)) {
    av <- open_solvers(check = TRUE)
    solvers <- av$option[av$available]
    if (!length(solvers)) {
      stop("no open solver back end is reachable on this system; ",
           "see open_solvers()", call. = FALSE)
    }
  }
  if (is.character(solvers)) {
    miss <- setdiff(solvers, names(energyRt::solver_options))
    if (length(miss)) {
      stop("unknown solver option(s): ", paste(miss, collapse = ", "),
           call. = FALSE)
    }
    solvers <- energyRt::solver_options[solvers]
  }

  rows <- lapply(names(solvers), function(nm) {
    if (verbose) { message("solving with ", nm, " ...") }
    t0 <- Sys.time()
    res <- try(suppressMessages(energyRt::read_solution(
      energyRt::solve_scenario(scen, solver = solvers[[nm]], wait = TRUE))),
      silent = TRUE)
    secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (inherits(res, "try-error")) {
      return(data.frame(solver = nm, seconds = secs, objective = NA_real_,
                        status = .short_error(res), stringsAsFactors = FALSE))
    }
    obj <- energyRt::getData(res, "vObjective", merge = TRUE)$value
    data.frame(solver = nm, seconds = secs, objective = obj,
               status = "ok", stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)

  ok <- which(out$status == "ok")
  out$agrees <- NA
  if (length(ok)) {
    ref <- out$objective[ok[1]]
    out$agrees[ok] <- abs(out$objective[ok] - ref) / max(abs(ref), 1) < tol
  }
  out <- out[order(out$status != "ok", out$seconds), ]
  rownames(out) <- NULL
  out
}

.short_error <- function(e) {
  msg <- conditionMessage(attr(e, "condition"))
  substr(gsub("\\s+", " ", msg), 1, 60)
}

`%||%` <- function(x, y) if (is.null(x)) y else x
