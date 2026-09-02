# `pypsa_eur_nuts3` ships without its weather, so a model is not usable until
# the profiles its technologies reference are put back.

test_that("the full-year model ships without weather but with a geoscale", {
  skip_if_not_installed("energyRt")
  expect_length(energyRt::getObject(pypsa_eur_nuts3, class = "weather"), 0L)
  expect_length(energyRt::get_region(pypsa_eur_nuts3), 1035L)
  expect_s3_class(pypsa_eur_nuts3@config@geoscale, "geoscales::Geoscale")
})

test_that("attach_weather adds the named resources and no others", {
  skip_if_not_installed("energyRt")
  m <- attach_weather(pypsa_eur_nuts3, c("onwind", "solar"))
  expect_setequal(names(energyRt::getObject(m, class = "weather")),
                  c("W_ONWIND", "W_SOLAR"))
})

test_that("attaching everything gives one object per resource", {
  skip_if_not_installed("energyRt")
  m <- attach_weather(pypsa_eur_nuts3)
  expect_length(energyRt::getObject(m, class = "weather"),
                length(weather_resources()))
  # attaching twice must not duplicate
  expect_length(energyRt::getObject(attach_weather(m), class = "weather"),
                length(weather_resources()))
})

test_that("an unknown resource is named in the error", {
  expect_error(attach_weather(pypsa_eur_nuts3, "windy"), "windy")
  expect_error(attach_weather("not a model"), "must be a model")
})

test_that("every weather resource has a dataset and covers the regions", {
  skip_if_not_installed("energyRt")
  regions <- energyRt::get_region(pypsa_eur_nuts3)
  for (r in weather_resources()) {
    w <- get(paste0("wx_nuts3_", r), envir = asNamespace("reneuro"))
    expect_s4_class(w, "weather")
    expect_true(all(stats::na.omit(w@weather$region) %in% regions),
                info = r)
  }
})

test_that("nuts_gs is keyed the way the models are", {
  skip_if_not_installed("geoscales")
  skip_if_not_installed("energyRt")
  atoms <- as.character(geoscales::geoscale_regions(nuts_gs, "nuts3"))
  # convert_pypsa() rewrites every non-alphanumeric character, so the adm1
  # codes of BA, MD, UA and XK reach a model as BA_BIH rather than BA-BIH.
  expect_false(any(grepl("-", atoms)))
  expect_true(all(energyRt::get_region(pypsa_eur_nuts3) %in% atoms))
  expect_true(all(energyRt::get_region(pypsa_eur_1035) %in% atoms))
})
