# Documentation for the shipped models ----------------------------------------
#
# All model objects are DERIVED. data-raw/ holds the scripts that rebuild them
# and records the upstream commit; each object also carries a
# `reneuro_provenance` attribute, so an .rda taken out of context can still say
# where it came from:
#
#   attr(pypsa_eur_5, "reneuro_provenance")

#' Converted PyPSA-Eur models
#'
#' Unsolved [energyRt] models converted from PyPSA-Eur networks, spanning the
#' range this package is built for: the European system at several spatial
#' resolutions, a small Belgian model that runs in seconds with its copperplate
#' reference, a one-year horizon series, and a vintaged 2025-2050 pathway
#' model. All are built on 2025 weather and measured ENTSO-E 2025 load, and
#' are loaded lazily, so they cost nothing until touched.
#'
#' @details
#' `pypsa_eur_5` is PyPSA-Eur's own Belgium example: five regions, one week
#' (168 hourly snapshots). It is small enough to solve in seconds, which makes
#' it the model every example and test uses.
#'
#' `pypsa_eur_5cp` is the same network with `transmission = "copperplate"` --
#' the same corridors, but unbounded and lossless. It is the reference point
#' for what the network representation costs: a copperplate cannot be more
#' expensive than any bounded version of itself, so it is the floor.
#'
#' `pypsa_eur_41` is PyPSA-Eur's own k-means clustering at 41 nodes over the
#' full year, so it is directly comparable to a PyPSA-Eur run at that size. Its
#' corridors carry a single flat loss rate: the six-tranche version it replaced
#' produced 224,640 generated constraints on a 288-slice calendar, which no
#' open solver generates in reasonable time. It is also the first model built
#' with the fuel price separated -- `varom` holds the true VOM and each fuel's
#' supply carries its price -- so a gas-price sensitivity is a change to one
#' number rather than a re-conversion.
#'
#' `pypsa_eur_nuts3` is the NUTS3 network over the **full year** (8,760
#' hourly snapshots) -- the finest resolution the data supports, intended as
#' the starting point for aggregation and study-area work in R rather than as
#' a model to solve whole. NUTS3 yields 1,035 AC nodes rather than 1,477
#' because 442 regions contain no substation and merge into neighbours,
#' **retaining their demand and generation** in the region they join. Trade
#' uses one flat loss rate per corridor and a transport formulation without
#' Kirchhoff's voltage law. Its hourly weather profiles are seven eighths of
#' its size, so they ship as separate `wx_nuts3_*` objects and are put back
#' with [attach_weather()] -- a model without them cannot be interpolated,
#' because its technologies reference them by name. It carries [nuts_gs], so
#' `energyRt::aggregate_model_regions(pypsa_eur_nuts3, level = "nuts2")` needs
#' no second argument; the coarser NUTS levels (289 regions at NUTS2, 106 at
#' NUTS1, 36 at NUTS0) are derived that way rather than shipped.
#'
#' `pypsa_eur_41_2025` ... `pypsa_eur_41_2050` are the **one-year horizon
#' series**: the 41-node system rebuilt per planning horizon in five-year
#' steps. Weather, load and network are identical to `pypsa_eur_41`; what
#' changes with the horizon is the cost vintage (technology-data v0.14.0 for
#' that year) and the existing fleet, aged by two rules kept separable in
#' provenance -- announced `DateOut` schedules (114 GW, mostly coal and
#' lignite phase-outs) and assumed carrier-lifetime retirement, which
#' reproduces what PyPSA's myopic mode does between horizons (its overnight
#' mode does no ageing at all). `attr(m, "reneuro_provenance")$retirement`
#' holds the per-carrier split, so the assumed half can be identified and
#' discounted. The series ships **without weather**: all six share
#' `pypsa_eur_41`'s profiles, so attach them before interpolating --
#' `attach_weather(pypsa_eur_41_2030, from = pypsa_eur_41)`.
#'
#' `pypsa_eur_41v` is the **vintaged multi-year model**: one model over the
#' 2025--2050 horizon (five-year milestones) where each carrier is a single
#' technology with a `STOCK` vintage carrying the existing fleet's
#' milestone-by-milestone surviving-stock series (announced retirements plus
#' assumed lifetime aging, summed over PyPSA's build-year bins -- the bins
#' themselves are parameter-flat under the 2025 cost-table clamp, so they are
#' aggregated away) and, for investable carriers, open paths: where the
#' assumption tables move a real parameter across the horizon (gas
#' efficiency), one `NEW<year>` vintage window per assumption year with that
#' table's efficiency, lifetime and annuity frozen -- year-keyed efficiency
#' inside a single open path would let standing capacity retrofit itself for
#' free -- and where only cost varies (VRE), a single `NEW` path with
#' year-keyed investment costs, so build-year economics stay endogenous.
#' Carriers with no existing fleet (solar-hsat, offwind DC and floating) stay
#' un-vintaged and investable. Demand is flat at 2025; like the horizon
#' series it ships without weather --
#' `attach_weather(pypsa_eur_41v, from = pypsa_eur_41)`.
#' `energyRt::getVariants()` and `energyRt::variantSummary()` list the
#' vintages; `attr(m, "reneuro_provenance")` records the retirement-rule
#' split and the aggregation.
#'
#' The continental models are built on **2025 weather and load** (ENTSO-E
#' measured demand; the `europe-2025-sarah3-era5` cutout). All were converted
#' with `cost_source = "network"`, taking costs from the network rather than
#' from a separate cost assumption, so they agree with the PyPSA solve they
#' can be compared against.
#'
#' @format An [energyRt] `model` object.
#'
#' @source
#' Converted from [PyPSA-Eur](https://github.com/PyPSA/pypsa-eur) `v2026.02.0`
#' (commit `d6383eb`, PyPSA 1.1.0) by `convert_pypsa()`.
#'
#' **Licence: ODbL-1.0**, required by the share-alike terms of the
#' OpenStreetMap-derived inputs, and independent of this package's Apache-2.0
#' code licence. Attribution is required for OpenStreetMap contributors and the
#' European Environment Agency among others.
#'
#' The World Database on Protected Areas, which may not be redistributed, is
#' **not** present -- see `system.file("LICENSE.note", package = "reneuro")`
#' for how that was verified and what it costs (renewable land availability in
#' Moldova and Ukraine is overstated as a result). The same file records that
#' the OPSD and ENTSO-E demand series carry unclear upstream terms.
#'
#' The build scripts live in two places. This package's `data-raw/` holds
#' `pypsa_eur_41.R`, `pypsa_eur_nuts3.R`, `pypsa_eur_41_years.R` and
#' `pypsa_eur_41v.R`; `pypsa_eur_5` and `pypsa_eur_5cp` are built by the
#' converter workspace's `reneuro.dev/data-raw/make_models.R`, from the network
#' also bundled as `reneuro_example("BE_base_s_5_elec.nc")`. All shipped
#' models were rebuilt 2026-09-03 with the corrected calendar chronology:
#' the converter used to emit the timetable hour-major, which chained the
#' storage balance across days at the same wall-clock hour -- storage could
#' not carry noon into evening. The Belgian pair now also carries the
#' current defaults (flat corridors, sanitised calendar names), and
#' `be_solved`'s objective gate moved accordingly (verified +0.386% above
#' PyPSA's own solve of the same network, the documented
#' transport-relaxation class of difference).
#'
#' @examples
#' # Provenance travels with the object.
#' str(attr(pypsa_eur_5, "reneuro_provenance"), max.level = 1)
#' @name pypsa_eur_models
#' @aliases pypsa_eur_41 pypsa_eur_5 pypsa_eur_5cp
#'   pypsa_eur_nuts3 pypsa_eur_41_2025 pypsa_eur_41_2030 pypsa_eur_41_2035
#'   pypsa_eur_41_2040 pypsa_eur_41_2045 pypsa_eur_41_2050 pypsa_eur_41v
NULL

#' @rdname pypsa_eur_models
"pypsa_eur_nuts3"

#' @rdname pypsa_eur_models
"pypsa_eur_41"

#' @rdname pypsa_eur_models
"pypsa_eur_5"

#' @rdname pypsa_eur_models
"pypsa_eur_5cp"

#' @rdname pypsa_eur_models
"pypsa_eur_41v"

#' @rdname pypsa_eur_models
"pypsa_eur_41_2025"

#' @rdname pypsa_eur_models
"pypsa_eur_41_2030"

#' @rdname pypsa_eur_models
"pypsa_eur_41_2035"

#' @rdname pypsa_eur_models
"pypsa_eur_41_2040"

#' @rdname pypsa_eur_models
"pypsa_eur_41_2045"

#' @rdname pypsa_eur_models
"pypsa_eur_41_2050"

#' A solved Belgium scenario
#'
#' [pypsa_eur_5] interpolated and solved with GLPK. It ships so the vignettes
#' can show results without requiring a solver at build time.
#'
#' @details
#' The objective is `164899752.517096`. That figure is a regression gate rather
#' than a curiosity: the build (`reneuro.dev/data-raw/make_be_solved.R`)
#' refuses to save a scenario that does not reproduce it, so this object cannot
#' silently drift.
#'
#' The value corresponds to the current flat single-loss-rate corridors.
#' The retired six-tranche default gave `164664296.503735`; converting with
#' `tranches = 6` still reproduces that rung of the transmission ladder.
#'
#' @format An [energyRt] `scenario` object with its solution attached.
#' @source [pypsa_eur_5] interpolated and solved with GLPK. Same data licence
#'   and provenance as [pypsa_eur_models].
#' @examples
#' attr(be_solved, "reneuro_provenance")$objective
"be_solved"

#' Map of the 41-region European system
#'
#' A [geoscales::geoscales] `Geoscale` for [pypsa_eur_41]: the model regions as polygons,
#' with the `sync -> country -> bus` hierarchy PyPSA-Eur clusters them by.
#'
#' @details
#' This ships **separately from the model** rather than attached to it. The
#' models are the modelling artefact and stay exactly as `convert_pypsa()`
#' produces them; the map is a convenience for looking at them. Attach it when
#' you want one:
#'
#' ```r
#' m <- setGeoscale(pypsa_eur_41, pypsa_eur_41_gs)
#' ```
#'
#' Two geoframes, coarsest first: `country` (36) and `bus` (41 model regions,
#' the atoms). Five countries — DK, ES, FR, GB, IT — are split into two buses
#' each, which is how 36 becomes 41.
#'
#' PyPSA's synchronous zones are carried as a `sync` **column**, deliberately
#' not as a geoframe. `sync` is a genuine partition of the atoms and is coarser
#' than `country` by member count (7 against 36), but it does **not nest**
#' inside it: those same five countries each straddle two zones. A geoframe
#' chain must nest — listing `sync` in it made those countries children of two
#' parents, and the spatial roll-up would then add each one's balance into both
#' zones. Group by the column, or build a separate geoscale from it, when
#' synchronous zones are what you want.
#'
#' @section The geometry is simplified:
#' The upstream onshore boundaries are 13 MB of GeoJSON. They are reduced with
#' `rmapshaper::ms_simplify(keep = 0.03, keep_shapes = TRUE)`, which drops
#' vertices while guaranteeing every polygon survives — islands included; the
#' build script refuses to save an object that lost a region.
#'
#' It is therefore a **display** geometry. Do not compute areas or distances
#' from it. Rebuild at full resolution from a PyPSA-Eur clone with
#' `pypsa_geo_layers()` and `pypsa_geoscale()` if you need those.
#'
#' No map ships for [pypsa_eur_5]; its GeoJSON sidecars are in the package
#' instead, reachable through [reneuro_example_geo()].
#'
#' @format A [geoscales::geoscales] `Geoscale` with 41 atoms and attached geometry.
#' @source Same provenance and ODbL-1.0 data licence as [pypsa_eur_models].
#'   Regenerated by `data-raw/make_geoscales.R`.
#' @examples
#' attr(pypsa_eur_41_gs, "reneuro_provenance")$simplify_keep
#' @seealso [pypsa_eur_models], [reneuro_example_geo()]
"pypsa_eur_41_gs"


#' NUTS regions of Europe, as a nested geoscale
#'
#' The administrative hierarchy PyPSA-Eur builds its regions from, as a
#' [geoscales::geoscales] `Geoscale`: **1,477 atoms** in five nested geoframes.
#'
#' @details
#' | geoframe | regions | what it is |
#' |---|---:|---|
#' | `europe` | 1 | the whole territory |
#' | `nuts0` | 36 | countries |
#' | `nuts1` | 109 | NUTS1 |
#' | `nuts2` | 296 | NUTS2 |
#' | `nuts3` | 1,477 | NUTS3 -- the atom layer |
#'
#' The single-member `europe` root exists so a **continental** commodity balance
#' has a region to live at — one Europe-wide CO2 allowance or gas market rather
#' than 36 national ones. Without it the coarsest balance available is per
#' country.
#'
#' Nesting is exact and is asserted at build time: every finer code maps to
#' exactly one coarser code. That is what lets a commodity declare
#' `@geoframe = "nuts1"` and have its balance roll up correctly from the atoms.
#'
#' @section Data carried per region:
#' The leaftable holds two families of per-region data, and the distinction
#' between them decides what each column can be used for.
#'
#' **Geographic**, from the region shapes, defined for all 1,477 atoms:
#'
#' | column | unit | kind |
#' |---|---|---|
#' | `km2` | km2, EPSG:3035 | extensive |
#' | `pop` | thousands | extensive |
#' | `gdp` | EUR per capita | **intensive** |
#' | `gdp_total` | thousand EUR | extensive |
#'
#' **Model**, from the NUTS3 network, located at substation buses:
#'
#' | column | unit | kind |
#' |---|---|---|
#' | `load_twh` | TWh per year | extensive |
#' | `peak_mw` | MW, coincident | **not additive** |
#' | `n_buses` | count of substations | extensive |
#' | `cap_mw` | MW of generation built today | extensive |
#' | `hydro_mw` | MW of that which is hydro | extensive |
#' | `pot_onwind`, `pot_solar`, `pot_solar_hsat` | MW | extensive |
#' | `pot_offwind_ac`, `pot_offwind_dc`, `pot_offwind_float` | MW | extensive |
#'
#' `gdp` looks like a total and is not: summing it gives Germany "15.6
#' million", while a population-weighted mean recovers its real ~41,800 EUR per
#' capita. `gdp_total = gdp * pop` is carried so an extensive money weight
#' exists. `peak_mw` is the maximum of the *summed* hourly series and falls
#' below the sum of its parts wherever demand is diverse; see [nuts_load].
#'
#' Seven columns are declared **weights** -- `km2`, `pop`, `gdp_total`,
#' `load_twh`, `cap_mw`, `pot_onwind`, `pot_solar` -- and `km2` is the default.
#' A weight splits a coarse quantity across atoms and averages an intensive one
#' back up, so the choice is a modelling decision: national demand should be
#' split by `load_twh` or `pop`, not by area, and a wind target by `pot_onwind`.
#' See [geoscales::recast_geoscale()].
#'
#' @section The potentials overlap and must not be summed:
#' `pot_solar` and `pot_solar_hsat` are fixed-tilt and single-axis-tracking
#' photovoltaics **on the same land**, and 313 of the 314 offshore regions carry
#' more than one `pot_offwind_*` type on the same sea area. Adding them counts
#' the same hectare twice. They are kept as separate columns so that no summing
#' rule is imposed here; the three offshore columns are excluded from the weight
#' set for a second reason -- they are zero for every landlocked country.
#'
#' @section 442 regions carry no model data:
#' PyPSA-Eur places demand, plant and potential at substation buses, and 442 of
#' the 1,477 NUTS3 regions contain none. Every model column is zero there. That
#' is the model's own allocation -- a busless region's land and load were folded
#' into the neighbour it clusters with -- and not a statement about the region.
#' The geographic columns are unaffected.
#'
#' The effect propagates upward exactly as far as the node counts do: **7 NUTS2
#' groups and 3 NUTS1 groups** contain no substation at all, and these are
#' precisely the regions lost when 296 NUTS2 become 289 nodes and 109 NUTS1
#' become 106.
#'
#' A weight summing to zero over a group divides by zero when averaging an
#' intensive quantity into it. Those groups are recorded rather than patched:
#'
#' ```r
#' attr(nuts_gs, "weight_degeneracy")
#' ```
#'
#' Two entries are degenerate for a reason other than a missing substation, and
#' both are real: `GBI3` (Inner London) has no generation and no land the
#' availability rules admit for wind, and `NO07` (Nord-Norge) has no solar
#' potential, lying above the Arctic Circle.
#'
#' @section Four countries have no NUTS:
#' **BA, MD, UA and XK** are outside the NUTS system entirely -- the same four
#' PyPSA-Eur caps at administrative level 1. They are filled from OpenStreetMap
#' `adm1` boundaries (3, 37, 27 and 7 regions respectively), which become
#' `nuts3` atoms, and the levels above them are **padded**: `MD0` at `nuts1`,
#' `MD00` at `nuts2`.
#'
#' Padding rather than repeating matters. PyPSA-Eur repeats the adm1 code at
#' every level, which makes each of those regions **its own parent**: the
#' derived region hierarchy then carries identity pairs like `(MD-BA, MD-BA)`,
#' and energyRt's spatial roll-up degenerates to
#' `vOutTot[MD-BA] = ... + vOutTot[MD-BA]`, silently forcing everything else to
#' zero.
#'
#' The padding follows Eurostat's own convention for identical geography --
#' Luxembourg is `LU -> LU0 -> LU00 -> LU000` -- and no NUTS country produces a
#' single identity pair. The honest caveat remains that "NUTS1"/"NUTS2" for
#' those four is a stand-in, not a real administrative level.
#'
#' @section A known gap in the gdp weight:
#' One region, `MD-BD` (Bender), carries `gdp = 0` in the source, and it is left
#' uncorrected -- substituting a plausible number would hide a real gap.
#'
#' It no longer breaks anything: with the levels padded, `MD-BD` sits inside
#' `MD0`/`MD00` rather than being its own parent, so no group sums to zero and
#' every weight now passes the build script's checks cleanly.
#'
#' @section The geometry is simplified:
#' Reduced from 37 MB of source GeoJSON with
#' `rmapshaper::ms_simplify(keep = 0.02, keep_shapes = TRUE)`; the build refuses
#' to save if a region is lost. It is a **display** geometry -- the `km2` weight
#' was computed from the *unsimplified* polygons in EPSG:3035, so use that
#' rather than measuring the shipped shapes.
#'
#' @format A [geoscales::geoscales] `Geoscale` with 1,477 atoms, five geoframes,
#'   14 data columns and attached geometry.
#' @source
#' Built from PyPSA-Eur's own `resources/<run>/nuts3_shapes.geojson` rather than
#' from raw Eurostat files, so the regions match the networks this package
#' converts exactly. That layer combines **Eurostat NUTS 2021** (© European
#' Union, reuse permitted with attribution) with **OpenStreetMap** adm1
#' boundaries (ODbL-1.0) for the four countries NUTS does not reach.
#'
#' The model layer comes from the NUTS3 network `base_s_1035_elec.nc` of the
#' same build, whose AC bus names are NUTS3 codes.
#'
#' See `system.file("LICENSE.note", package = "reneuro")`. Regenerated by
#' `data-raw/nuts_gs.R`.
#' @examples
#' # The hierarchy, coarsest first
#' geoscales::geoscale_geoframes(nuts_gs)
#'
#' # How many regions at each level
#' vapply(geoscales::geoscale_geoframes(nuts_gs),
#'        function(f) length(geoscales::geoscale_regions(nuts_gs, f)), 0L)
#'
#' # Demand and wind potential by country, from the atom layer
#' geoscales::geoscale_leaftable(nuts_gs) |>
#'   as.data.frame() |>
#'   dplyr::group_by(nuts0) |>
#'   dplyr::summarise(twh = sum(load_twh), wind_gw = sum(pot_onwind) / 1e3) |>
#'   dplyr::arrange(dplyr::desc(twh)) |>
#'   head()
#' @seealso [nuts_load], [pypsa_eur_41_gs], [geoscales::recast_geoscale()]
"nuts_gs"


#' Electricity demand per NUTS region
#'
#' Annual energy and coincident peak for every region of [nuts_gs], at all four
#' levels plus a Europe-wide row.
#'
#' @details
#' | column | meaning |
#' |---|---|
#' | `level` | `europe`, `nuts0`, `nuts1`, `nuts2`, `nuts3` |
#' | `region` | region code at that level |
#' | `load_twh` | annual energy, TWh — **extensive**, sums up the hierarchy |
#' | `peak_gw` | max of the **summed** hourly series, GW — *not* extensive |
#' | `n_buses` | substation buses in the region; `0` means no demand at all |
#'
#' Total across all regions is 3,356 TWh at every level.
#'
#' @section Peak diversity is zero below the country:
#' In general `peak(parent) <= sum(peak(children))`, the gap being load
#' diversity. Here it is **exactly zero within every country**, and appears only
#' across Europe (580 GW summed against 543 GW coincident, 6.8%).
#'
#' That is a property of the data, not of European demand. PyPSA-Eur builds
#' per-bus load as a static fraction times the *national* hourly series, so
#' every bus in a country carries an identical normalised shape. Going finer
#' than a country adds spatial detail to the **level** of demand and none to its
#' **shape**: at NUTS3, 1,477 regions share 36 distinct profiles.
#'
#' @section 442 regions carry no demand:
#' `load.substation_only: true` places demand only on substation buses, and 442
#' of the 1,477 NUTS3 regions contain none — Germany alone has 182. They are
#' present with `load_twh = 0` and `n_buses = 0` rather than omitted, so the gap
#' shows on a map instead of vanishing. It is a real ceiling on useful
#' resolution.
#'
#' @format A `data.frame` of 2,059 rows and 5 columns.
#' @source
#' Aggregated from PyPSA-Eur's `electricity_demand_base_s.nc` (4,356 buses ×
#' 8,760 hours). Buses are located against the **unsimplified** upstream
#' `nuts3_shapes.geojson`. Same data licence as [pypsa_eur_models].
#' Regenerated by `data-raw/make_nuts_load.R`.
#' @examples
#' # energy is extensive: every level sums to the same total
#' tapply(nuts_load$load_twh, nuts_load$level, sum)
#' @seealso [nuts_gs], [nuts_lines]
"nuts_load"

#' Transmission lines with NUTS3 endpoints
#'
#' Every AC line of PyPSA-Eur's simplified network whose two ends fall in
#' *different* NUTS3 regions, with the parameters needed to aggregate it to any
#' coarser level.
#'
#' @details
#' | column | meaning |
#' |---|---|
#' | `from`, `to` | NUTS3 codes, ordered so `from < to` |
#' | `s_nom` | thermal rating, MW — **extensive**, sums |
#' | `length_km`, `x`, `r` | as built; length and impedance are *recomputed* on aggregation |
#' | `v_nom`, `num_parallel` | voltage and circuit count |
#'
#' Deliberately **not** pre-aggregated, not even to NUTS3, so one routine can be
#' applied at all four levels and NUTS3 is not a privileged case.
#'
#' @section Over half the grid is already gone:
#' Lines with both ends in one NUTS3 region are dropped, exactly as
#' `pypsa.clustering.spatial.aggregatelines()` drops intra-cluster lines. That
#' is **4,218 of 7,360 lines (57%), carrying 53% of capacity** — discarded at
#' the *finest* level available. Coarsening further only removes more.
#'
#' @section Aggregating correctly:
#' Three different rules, none of them a plain average:
#'
#' * `s_nom`, `num_parallel` — **sum**;
#' * `length` — **recomputed** as the great-circle distance between the two
#'   region centroids times `line_length_factor` (1.25). It is not inherited, and
#'   it *grows*: median corridor length rises from 85 km at NUTS3 to 459 km at
#'   NUTS0;
#' * `x`, `r` — rescaled by the length ratio, then **parallel-combined** as
#'   `1 / sum(1/x)`.
#'
#' Because impedance follows length, losses are **overestimated** at coarse
#' levels; because `s_nom` is a plain thermal sum ignoring N-1 and loop flows,
#' capacity is **overestimated** too. The two do not cancel.
#'
#' @format A `data.frame` of 3,142 rows and 8 columns.
#' @source
#' PyPSA-Eur `base_s.nc` (7,360 lines, 4,382 buses), endpoints located against
#' the unsimplified `nuts3_shapes.geojson`. Same data licence as
#' [pypsa_eur_models]. Regenerated by `data-raw/make_nuts_lines.R`.
#' @examples
#' # how much of the network never crosses a NUTS3 boundary
#' p <- attr(nuts_lines, "reneuro_provenance")
#' c(total = p$lines_total, dropped = p$lines_intra_dropped)
#' @seealso [nuts_gs], [nuts_load]
"nuts_lines"

#' Hourly weather profiles for the full-year NUTS3 model
#'
#' One `weather` object per renewable resource, holding availability by region
#' and hour for the 1,035 regions of [pypsa_eur_nuts3] over 8,760 snapshots.
#'
#' They ship apart from the model because together they are 987 MB in memory
#' and most of its saved size; split, no file passes GitHub's 100 MB limit and
#' a study loads only the resources it uses. [attach_weather()] puts them back.
#'
#' `wx_nuts3_solar` and `wx_nuts3_solar_hsat` cover the same land, as do the
#' three offshore profiles over the same sea area: they are alternative ways to
#' use one site, so their potentials are never summed.
#'
#' @format An [energyRt] `weather` object.
#' @source Same provenance and ODbL-1.0 data licence as [pypsa_eur_models].
#'   Regenerated by `data-raw/pypsa_eur_nuts3.R`.
#' @seealso [attach_weather()], [weather_resources()], [pypsa_eur_nuts3]
#' @name wx_nuts3
#' @aliases wx_nuts3_onwind wx_nuts3_offwind_ac wx_nuts3_offwind_dc
#'   wx_nuts3_offwind_float wx_nuts3_solar wx_nuts3_solar_hsat wx_nuts3_ror
NULL

#' @rdname wx_nuts3
"wx_nuts3_onwind"

#' @rdname wx_nuts3
"wx_nuts3_offwind_ac"

#' @rdname wx_nuts3
"wx_nuts3_offwind_dc"

#' @rdname wx_nuts3
"wx_nuts3_offwind_float"

#' @rdname wx_nuts3
"wx_nuts3_solar"

#' @rdname wx_nuts3
"wx_nuts3_solar_hsat"

#' @rdname wx_nuts3
"wx_nuts3_ror"

#' TYNDP 2024 electricity-demand growth factors
#'
#' Growth factors for electricity demand by country, scenario and
#' milestone year (2025-2050, 5-year steps), anchored at 2025 = 1 --
#' the measured ENTSO-E load keeps the level, TYNDP 2024 moves it.
#' Scenarios: `"NT"` (National Trends+, from the market-modelling
#' outputs' native demand; extrapolated beyond 2040), `"DE"`
#' (Distributed Energy) and `"GA"` (Global Ambition), which follow the
#' NT path to 2030 and then their own trajectories. `method` records
#' whether a value comes from the source series, an extrapolation, or
#' the perimeter-average fill for countries the sources lack.
#' Apply with [scale_demand()].
#'
#' @format A data frame: `scenario`, `country`, `year`, `factor`,
#'   `method`.
#' @source TYNDP 2024 Scenarios (ENTSO-E/ENTSOG), CC-BY 4.0;
#'   \url{https://2024.entsos-tyndp-scenarios.eu/download/}. Built by
#'   `data-raw/tyndp_demand.R`.
"tyndp_demand"

#' Power-sector CO2 cap trajectories
#'
#' Three cap paths as factors relative to 2025 emissions, for building
#' carbon-cap scenarios (see the Scenarios article): `ets_cap`
#' (the EU ETS cap shape under the Fit-for-55 linear reduction factors,
#' zero around 2039 -- deliberately the tightest of the three; note the
#' cap is bankable, so it is not a hard annual emissions ceiling), `ndc`
#' (the EU's economy-wide pledges -- -55% 2030,
#' the 2035 NDC midpoint, -90% 2040, neutrality 2050 -- mapped to
#' 2025-relative factors) and `nz2050` (linear to zero at 2050).
#' Multiply by a base-year emission level (the model's own solved 2025
#' emissions) to obtain cap right-hand sides.
#'
#' @format A data frame: `scenario`, `year`, `factor`, `method`.
#' @source Directive (EU) 2023/959; the EU NDC (Nov 2025) and 2040
#'   target; EEA GHG inventory. Built by `data-raw/policy_paths.R`.
"policy_paths"
