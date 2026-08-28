# Example files shipped with the package --------------------------------------
#
# The 5-node Belgium network and its GeoJSON sidecars live in inst/extdata so
# examples, tests and vignettes have something to read without a PyPSA-Eur
# clone. They are the SAME inputs the shipped `pypsa_eur_5` model was converted
# from, which is what makes the round trip demonstrable rather than asserted.

#' Path to an example PyPSA-Eur file shipped with reneuro
#'
#' @param file file name. If `NULL` (the default), the available files are
#'   listed instead.
#' @return a file path, or a character vector of available names when
#'   `file = NULL`.
#' @examples
#' reneuro_example()
#' reneuro_example("BE_base_s_5_elec.nc")
#' @export
reneuro_example <- function(file = NULL) {
  root <- system.file("extdata", package = "reneuro")
  if (is.null(file)) {
    return(list.files(root, recursive = TRUE))
  }
  p <- file.path(root, file)
  if (!file.exists(p)) {
    stop("no example file '", file, "'. Available: ",
         paste(list.files(root, recursive = TRUE), collapse = ", "))
  }
  p
}

#' Directory holding the example GeoJSON region layers
#'
#' `pypsa_geo_layers()` takes a directory rather than individual files, so the
#' shipped sidecars are reached through this rather than [reneuro_example()].
#'
#' @return path to the directory of example GeoJSON layers
#' @examples
#' list.files(reneuro_example_geo())
#' @export
reneuro_example_geo <- function() {
  system.file("extdata", "geo", package = "reneuro")
}
