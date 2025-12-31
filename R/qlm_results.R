#' Extract results from a qlm_coded object
#'
#' Extracts the coded results data frame from a `qlm_coded` object returned by
#' [qlm_code()].
#'
#' @param x A `qlm_coded` object.
#' @param format Output format: `"data.frame"` (default) or `"tibble"`.
#'
#' @return A data frame (or tibble) containing the coded results, with an `id`
#'   column and additional columns as defined by the codebook's type definition.
#'
#' @seealso [qlm_code()] for coding data, [qlm_codebook()] for creating codebooks.
#'
#' @examples
#' \dontrun{
#' # Code some texts
#' texts <- c("I love this!", "This is terrible.")
#' coded <- qlm_code(texts, task_sentiment(), model_name = "openai")
#'
#' # Extract results as data frame (default)
#' results <- qlm_results(coded)
#' print(results)
#'
#' # Extract as tibble
#' results_tbl <- qlm_results(coded, format = "tibble")
#' }
#'
#' @export
qlm_results <- function(x, format = c("data.frame", "tibble")) {
  format <- match.arg(format)

  if (!inherits(x, "qlm_coded")) {
    cli::cli_abort(c(
      "{.arg x} must be a {.cls qlm_coded} object.",
      "i" = "Create a {.cls qlm_coded} object with {.fn qlm_code}."
    ))
  }

  results <- x$results

  if (format == "tibble") {
    if (!requireNamespace("tibble", quietly = TRUE)) {
      cli::cli_abort(c(
        "Package {.pkg tibble} is required for tibble output.",
        "i" = "Install it with {.code install.packages(\"tibble\")} or use {.code format = \"data.frame\"}."
      ))
    }
    results <- tibble::as_tibble(results)
  }

  results
}
