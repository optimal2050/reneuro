# Legacy-fleet aggregation for the vintaging rework: the build-year bins
# of pypsa_eur_41v are collapsed per technology into k <= MAX_K clusters
# over the bins' FULL parameter vector (efficiency, varom, availability
# where present), capacity-weighted; a flat fleet collapses to k = 1.
# Output: data-raw/fleet_agg.csv (type, fcluster, region, stock_2025 and
# the cluster parameter values) + a review table printed for the user
# BEFORE any assembly consumes it.
suppressMessages({
  library(reneuro); library(dplyr); library(tidyr)
})
MAX_K <- 3
TOL <- 0.05    # capacity-weighted within-cluster relative sd tolerance

objs <- energyRt:::getObjects(pypsa_eur_41v)
is_vintaged <- vapply(objs, function(o) {
  class(o)[1] == "technology" && nrow(o@vintage) > 1
}, TRUE)

bin_params <- function(t) {
  legacy <- setdiff(t@vintage$vintage, c("new", "TOTAL"))
  if (!length(legacy)) return(NULL)
  eff <- if (nrow(t@ceff)) {
    t@ceff |> filter(vintage %in% legacy, !is.na(cinp2use)) |>
      summarise(eff = mean(cinp2use), .by = vintage)
  } else data.frame(vintage = legacy, eff = NA_real_)
  vo <- if (nrow(t@varom) && "vintage" %in% names(t@varom)) {
    t@varom |> filter(vintage %in% legacy, !is.na(varom)) |>
      summarise(varom = mean(varom), .by = vintage)
  } else data.frame(vintage = legacy, varom = NA_real_)
  af <- if (nrow(t@af) && "vintage" %in% names(t@af) &&
            "af.up" %in% names(t@af)) {
    t@af |> filter(vintage %in% legacy, !is.na(af.up)) |>
      summarise(af = mean(af.up), .by = vintage)
  } else data.frame(vintage = legacy, af = NA_real_)
  st <- t@capacity |> filter(vintage %in% legacy, !is.na(stock),
                             year == min(year, na.rm = TRUE)) |>
    summarise(gw = sum(stock) / 1e3, .by = vintage)
  data.frame(vintage = legacy) |>
    left_join(eff, by = "vintage") |> left_join(vo, by = "vintage") |>
    left_join(af, by = "vintage") |> left_join(st, by = "vintage") |>
    filter(!is.na(gw), gw > 0)
}

cluster_bins <- function(bp) {
  pcols <- c("eff", "varom", "af")[colSums(!is.na(bp[c("eff", "varom", "af")])) > 0]
  pcols <- pcols[vapply(pcols, function(cc)
    length(unique(round(bp[[cc]], 6))) > 1, TRUE)]
  if (!length(pcols) || nrow(bp) == 1) return(rep(1L, nrow(bp)))
  X <- scale(as.matrix(bp[pcols]))
  X[is.na(X)] <- 0
  wsd0 <- sum(apply(X, 2, function(x)
    sqrt(sum(bp$gw * (x - weighted.mean(x, bp$gw))^2) / sum(bp$gw))))
  for (k in 1:min(MAX_K, nrow(bp))) {
    cl <- if (k == 1) rep(1L, nrow(bp)) else
      kmeans(X, centers = k, nstart = 10)$cluster
    wsd <- sum(vapply(split(seq_len(nrow(bp)), cl), function(i) {
      sum(apply(X[i, , drop = FALSE], 2, function(x)
        sqrt(sum(bp$gw[i] * (x - weighted.mean(x, bp$gw[i]))^2) /
               sum(bp$gw[i]))))
    }, numeric(1)))
    if (wsd0 == 0 || wsd / wsd0 <= TOL || k == min(MAX_K, nrow(bp))) {
      return(cl)
    }
  }
}

out <- list(); review <- list()
for (nm in names(objs)[is_vintaged]) {
  t <- objs[[nm]]
  bp <- bin_params(t)
  if (is.null(bp) || !nrow(bp)) next
  bp$fcluster <- cluster_bins(bp)
  # per-cluster capacity-weighted parameters + per-region stock split
  cl <- bp |> summarise(eff = weighted.mean(eff, gw),
                        varom = weighted.mean(varom, gw),
                        af = weighted.mean(af, gw),
                        gw = sum(gw), .by = fcluster)
  st <- t@capacity |> filter(vintage %in% bp$vintage, !is.na(stock),
                             year == min(year, na.rm = TRUE)) |>
    inner_join(bp |> select(vintage, fcluster), by = "vintage") |>
    summarise(stock_2025 = sum(stock), .by = c(fcluster, region))
  out[[nm]] <- st |> left_join(cl |> select(-gw), by = "fcluster") |>
    mutate(type = nm, .before = 1)
  review[[nm]] <- cl |> mutate(type = nm, k = max(bp$fcluster),
                               bins = nrow(bp), .before = 1)
}
fleet <- bind_rows(out)
write.csv(fleet, "data-raw/fleet_agg.csv", row.names = FALSE)

cat("== REVIEW: legacy fleet aggregation (bins -> clusters) ==\n")
bind_rows(review) |>
  mutate(across(c(gw, eff, varom, af), ~round(., 3))) |>
  select(type, bins, k, fcluster, gw, eff, varom, af) |>
  as.data.frame() |> print(row.names = FALSE)
cat(sprintf("\nfleet_agg.csv: %d rows | total %0.1f GW\n",
            nrow(fleet), sum(fleet$stock_2025) / 1e3))
