# policy_paths -- power-sector CO2 cap trajectories as factors relative to
# 2025 emissions, for the policy scenarios of the Scenarios article.
# Factors multiply a base-year emission level of the user's choosing (the
# model's own solved 2025 emissions being the natural one), so the paths
# are growth-factor-transparent like tyndp_demand.
#
# Anchors (all citable):
# - ets_cap: the EU ETS cap shape. Directive (EU) 2023/959: linear
#   reduction factor 4.3%/yr (2024-2027) and 4.4%/yr (2028+) of the base
#   amount, plus rebasings -90 Mt (2024) and -27 Mt (2026); -62% by 2030
#   vs 2005. At these LRFs the ETS-1 cap reaches zero around 2039. Power
#   is ETS-covered, so the power cap is modelled as LINEAR TO ZERO AT
#   2039, held at zero after.
# - ndc: the EU's economy-wide net targets vs 1990 -- -55% by 2030
#   (Climate Law), 66.25-72.5% indicative for 2035 (NDC submitted to the
#   UNFCCC Nov 2025; midpoint used), -90% by 2040 (2040 target adopted
#   2025), neutrality by 2050 -- converted to 2025-relative factors with
#   the EEA estimate that EU net GHG stood at about -37% vs 1990 by
#   2023/2025: factor(y) = (1 - target_y) / (1 - 0.37). APPROXIMATE and
#   conservative for power (the power sector decarbonises faster than the
#   economy-wide average); marked method = "mapped".
# - nz2050: linear from 2025 to zero at 2050 ("zero emissions by 2050,
#   total").
library(dplyr)

YEARS <- seq(2025, 2050, 5)

cp <- tibble(scenario = "ets_cap", year = YEARS,
             factor = pmax(0, 1 - (YEARS - 2025) / (2039 - 2025)),
             method = ifelse(YEARS <= 2039, "ets_linear", "held_zero"))

ndc_targets <- c(`2030` = 0.55, `2035` = 0.694, `2040` = 0.90, `2050` = 1)
base_2025 <- 0.37   # EU net GHG vs 1990 by ~2025 (EEA)
nd <- tibble(year = as.integer(names(ndc_targets)),
             remaining = (1 - ndc_targets) / (1 - base_2025))
nd <- tibble(scenario = "ndc", year = YEARS,
             factor = approx(c(2025, nd$year), c(1, nd$remaining),
                             xout = YEARS)$y,
             method = "mapped")

nz <- tibble(scenario = "nz2050", year = YEARS,
             factor = 1 - (YEARS - 2025) / 25,
             method = "linear_to_zero")

policy_paths <- bind_rows(cp, nd, nz) |> arrange(scenario, year)
stopifnot(all(policy_paths$factor[policy_paths$year == 2025] == 1),
          all(policy_paths$factor[policy_paths$year == 2050 &
                                    policy_paths$scenario != "ndc"] == 0))
print(tidyr::pivot_wider(policy_paths |> select(-method),
                         names_from = year, values_from = factor) |>
        mutate(across(where(is.numeric), ~round(., 3))))

attr(policy_paths, "source") <- paste(
  "EU ETS Directive (EU) 2023/959 (LRF 4.3/4.4%/yr, cap ~zero by 2039);",
  "EU Climate Law -55% 2030; EU NDC Nov 2025 (2035 indicative 66.25-72.5%);",
  "2040 target -90% vs 1990; EEA GHG inventory (~-37% vs 1990 by 2025).")
usethis::use_data(policy_paths, overwrite = TRUE)
cat("policy_paths:", nrow(policy_paths), "rows\n")
