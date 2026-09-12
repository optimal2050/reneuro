# tyndp_demand -- electricity-demand growth factors by country, scenario
# and milestone year, from the TYNDP 2024 scenarios (ENTSO-E/ENTSOG,
# CC-BY 4.0, attribution "TYNDP 2024 Scenarios"). Parsed by
# data-raw/tyndp/01_parse_tyndp_demand.py into tyndp_demand_raw.csv.
#
# Factors are growth RATES anchored at 2025 = 1: our measured ENTSO-E
# load keeps the level, TYNDP moves it. Scope constants (losses,
# electrolysis, perimeter conventions) cancel inside each source series:
# - NT: per-country line through (2030, 2040) extrapolated back to 2025
#   and forward to 2050 (method flags mark the extensions);
# - DE / GA: diverge from the NT 2030 point (TYNDP's own construction),
#   growing along the workbook series interpolated between REF 2019 and
#   their 2040/2050 values;
# - countries a source lacks take the perimeter-average factor
#   (method = "filled").
library(dplyr)
library(tidyr)

raw <- read.csv("data-raw/tyndp/tyndp_demand_raw.csv")
YEARS <- seq(2025, 2050, 5)
countries <- sort(unique(c(raw$country, "XK")))   # XK: model country absent
                                                  # from both sources -> filled

interp <- function(y, y1, v1, y2, v2) v1 + (y - y1) * (v2 - v1) / (y2 - y1)

nt <- raw |> filter(scenario == "NT") |>
  select(country, year, twh) |>
  pivot_wider(names_from = year, values_from = twh, names_prefix = "y")
wb <- raw |> filter(source == "demand_workbook") |>
  select(scenario, country, year, twh) |>
  pivot_wider(names_from = c(scenario, year), values_from = twh)

grid <- crossing(country = countries, year = YEARS,
                 scenario = c("NT", "DE", "GA")) |>
  left_join(nt, by = "country") |>
  left_join(wb, by = "country")

fac <- grid |>
  mutate(
    nt_2025 = pmax(interp(2025, 2030, y2030, 2040, y2040), 0.6 * y2030),
    f_nt = ifelse(year == 2025, 1,
                  interp(year, 2030, y2030, 2040, y2040) / nt_2025),
    f_nt30 = y2030 / nt_2025,
    dev40 = ifelse(scenario == "DE", DE_2040, GA_2040),
    dev50 = ifelse(scenario == "DE", DE_2050, GA_2050),
    dev30 = interp(2030, 2019, REF_2019, 2040, dev40),
    g_dev = case_when(
      year <= 2040 ~ interp(year, 2030, dev30, 2040, dev40) / dev30,
      .default = interp(year, 2040, dev40, 2050, dev50) / dev30),
    # DE/GA ride the NT path to 2030 (TYNDP's own construction), then
    # grow along their workbook series
    factor = ifelse(scenario == "NT" | year <= 2030, f_nt,
                    f_nt30 * g_dev),
    method = case_when(
      is.na(factor) ~ "filled",
      scenario == "NT" & year > 2040 ~ "extrapolated",
      scenario != "NT" & is.na(dev40) ~ "filled",
      .default = "source")) |>
  mutate(factor = ifelse(scenario != "NT" & is.na(dev40), NA, factor),
         method = ifelse(is.na(factor), "filled", method))

# fill gaps with the year x scenario average factor over covered countries
fill <- fac |> filter(!is.na(factor)) |>
  summarise(fill = mean(factor), .by = c(scenario, year))
tyndp_demand <- fac |>
  left_join(fill, by = c("scenario", "year")) |>
  transmute(scenario, country, year,
            factor = coalesce(factor, fill), method) |>
  arrange(scenario, country, year)

stopifnot(!anyNA(tyndp_demand$factor),
          all(abs(tyndp_demand$factor[tyndp_demand$year == 2025] - 1) < 1e-9))
cat("factors at 2050 (mean by scenario):\n")
print(tyndp_demand |> filter(year == 2050) |>
        summarise(mean_factor = round(mean(factor), 3), .by = scenario))

attr(tyndp_demand, "source") <- paste(
  "TYNDP 2024 Scenarios (ENTSO-E/ENTSOG), CC-BY 4.0.",
  "NT: market-modelling outputs (native demand per zone);",
  "DE/GA: demand-scenarios workbook (final electricity by sector).")
usethis::use_data(tyndp_demand, overwrite = TRUE)
cat("tyndp_demand:", nrow(tyndp_demand), "rows\n")
