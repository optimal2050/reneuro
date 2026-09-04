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
#   * An older `reneuro` may be installed in the user library (the 0.1.0 built
#     from the reneuro.dev playground). pkgdown renders each article in a fresh
#     session by default, where the vignette's `library(reneuro)` resolves to
#     that installed copy rather than to this source tree — so the articles
#     would be built against stale shipped data, with no error. Hence
#     `load_all()` here plus `new_process = FALSE` below.
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
for (a in c("reneuro", "data", "translation", "articles/report-model",
            "articles/report-scenario", "about")) {
  r <- try(pkgdown::build_article(a, pkg = ".", new_process = FALSE),
           silent = TRUE)
  failed <- inherits(r, "try-error")
  ok <- ok && !failed
  message(sprintf("  %-9s %s", a,
                  if (failed) paste("FAILED:", conditionMessage(attr(r, "condition")))
                  else "ok"))
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
