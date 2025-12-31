#' Create a qlm_coded object (internal)
#'
#' Low-level constructor for qlm_coded objects. This function is not exported
#' and is intended for internal use by [qlm_code()].
#'
#' @param codebook A qlm_codebook object.
#' @param settings List of execution settings (model_name, extra args).
#' @param results Data frame of coded results.
#' @param metadata List of metadata (timestamp, versions, etc.).
#'
#' @return A qlm_coded object.
#' @keywords internal
#' @noRd
new_qlm_coded <- function(codebook, settings, results, metadata) {
  structure(
    list(
      codebook = codebook,
      settings = settings,
      results = results,
      metadata = metadata
    ),
    class = "qlm_coded"
  )
}


#' Print a qlm_coded object
#'
#' @param x A qlm_coded object.
#' @param ... Additional arguments (currently unused).
#'
#' @return Invisibly returns the input object \code{x}. Called for side effects (printing to console).
#' @export
print.qlm_coded <- function(x, ...) {
  cat("Quallmer coded object\n")
  cat("  Codebook:  ", x$codebook$name, "\n", sep = "")
  cat("  Model:     ", x$settings$model_name, "\n", sep = "")
  cat("  Units:     ", x$metadata$n_units, "\n", sep = "")
  cat("  Timestamp: ", format(x$metadata$timestamp, "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
  cat("\n")
  cat("Use qlm_results() to extract coded data.\n")
  invisible(x)
}
