# Build the pkgdown site.
#
#   Rscript pkgdown/build.R
#
# The site is built locally and committed under `docs/` — there is no pkgdown
# workflow, matching the sibling packages in the stack. GitHub Pages serves
# `docs/` from the default branch, and pkgdown writes there directly.
#
# Do NOT replace this with a plain `pkgdown::build_site()`. Two things would go
# wrong silently:
#
#   * A stale `reneuro` may be installed in the user library. pkgdown renders
#     each article in a fresh session by default, where the vignette's
#     `library(reneuro)` resolves to that installed copy rather than to this
#     source tree — so the articles would be built against stale shipped data,
#     with no error. Hence `load_all()` here plus `new_process = FALSE` below,
#     AND the data sentinel in the article loop: the in-process guard has been
#     observed to leak mid-run (2026-09-06: the data vignette rendered against
#     a pre-repair installed copy while earlier articles used the dev tree),
#     so every article's build is followed by a namespace check that fails
#     loudly instead of shipping a stale page. Keeping the installed copy
#     current (devtools::install) is the belt to this suspender.
#   * The articles exercise recent energyRt changes, so the dev energyRt is
#     loaded too rather than whatever is installed.
#
# Only the singular `build_article()` accepts `new_process`, which is why the
# articles are built in a loop rather than with `build_articles()`.

ENERGYRT <- Sys.getenv("ENERGYRT_SRC", "C:/Users/admin/Documents/R/energyRt")

suppressMessages(pkgload::load_all(ENERGYRT, quiet = TRUE))
suppressMessages(pkgload::load_all(".", quiet = TRUE))

ok <- TRUE

# `build_site()` does this first; the per-step builders below do not. Without
# it the site's CSS and assets are never regenerated, so changes to the
# `template.bslib` block or to pkgdown/extra.css render HTML that still links
# the previous theme -- silently, since every page still builds.
init <- try(pkgdown::init_site(), silent = TRUE)
if (inherits(init, "try-error")) {
  message("  init_site FAILED: ", conditionMessage(attr(init, "condition")))
  ok <- FALSE
}

# `reneuro` is the intro ("Get started") by pkgdown convention, being named
# after the package; the rest are articles.
# The two report articles live in vignettes/articles/ -- they are website-only
# (they embed docs/reports/) and are named by their path.
# Data sentinel: the loaded reneuro namespace must serve the normalized
# region keys (underscores only). A nonzero count means the dev tree got
# shadowed by a stale installed copy and pages built after that point carry
# stale data.
stale_keys <- function() {
  nl <- get("nuts_lines", envir = asNamespace("reneuro"))
  sum(grepl("-", nl$from)) + sum(grepl("-", nl$to))
}
stopifnot(stale_keys() == 0L)

for (a in c("reneuro", "data", "translation", "articles/data-sources",
            "articles/wind-potential", "articles/solar-potential",
            "articles/scenarios", "articles/gpu-solving",
            "articles/report-model", "articles/report-scenario", "about")) {
  r <- try(pkgdown::build_article(a, pkg = ".", new_process = FALSE),
           silent = TRUE)
  failed <- inherits(r, "try-error")
  sk <- stale_keys()
  if (sk > 0L) {
    message("  STALE DATA after ", a, ": ", sk,
            " hyphen keys served by the reneuro namespace — the dev tree ",
            "was shadowed; pages from here on are unreliable")
    ok <- FALSE
  }
  ok <- ok && !failed
  message(sprintf("  %-9s %s", a,
                  if (failed) paste("FAILED:", conditionMessage(attr(r, "condition")))
                  else "ok"))
}

# Content sentinel: the namespace check above cannot see a render that
# resolves the INSTALLED reneuro inside a child process, so also assert
# the built data page carries the post-repair corridor table. If this
# fires, the installed copy is stale — refresh it with
# `devtools::install()` (close R sessions holding it first), or build
# with `R_LIBS=<fresh library>` so every resolution path finds current
# data.
dh <- "docs/articles/data-sources.html"
if (file.exists(dh) &&
    !any(grepl("nuts0\\s+65\\s+356", readLines(dh, warn = FALSE)))) {
  message("  STALE PAGE: docs/articles/data-sources.html lacks the 65/356 ",
          "corridor table — rendered against a stale installed reneuro")
  ok <- FALSE
}

steps <- list(
  reference     = function() pkgdown::build_reference(preview = FALSE),
  articles_index = pkgdown::build_articles_index,
  news          = pkgdown::build_news,
  home          = function() pkgdown::build_home(preview = FALSE)
)
for (nm in names(steps)) {
  r <- try(steps[[nm]](), silent = TRUE)
  if (inherits(r, "try-error")) {
    message("  ", nm, " FAILED: ", conditionMessage(attr(r, "condition")))
    ok <- FALSE
  }
}

# Rendered example reports are committed under pkgdown/assets/reports/ and
# copied to docs/reports/ by init_site(); the report articles link them. They
# are built by data-raw/example_reports.R rather than here -- a scenario report
# needs a solve, which does not belong in a site build.
if (!dir.exists("docs/reports")) {
  message("  MISSING after build: docs/reports (the report articles link it)")
  ok <- FALSE
}

# GitHub Pages runs Jekyll unless told not to. `build_site()` would write
# `.nojekyll`, but the per-step builders used above do not, so write it here --
# and assert, since a missing one breaks the served site quietly.
if (!file.exists("docs/.nojekyll")) invisible(file.create("docs/.nojekyll"))
if (!file.exists("docs/.nojekyll")) {
  message("  MISSING after build: docs/.nojekyll")
  ok <- FALSE
}

message(if (ok) "site ok" else "site had failures")
if (!ok) quit(status = 1L)
