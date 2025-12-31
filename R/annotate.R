#' Apply an annotation task to input data (deprecated)
#'
#' `r lifecycle::badge("deprecated")`
#'
#' `annotate()` has been deprecated in favor of [qlm_code()]. The new function
#' returns a richer object that includes metadata and settings for reproducibility.
#'
#' @inheritParams qlm_code
#' @param task A task object created with [task()] or [qlm_codebook()]. Also
#'   accepts predefined task functions ([task_sentiment()], [task_stance()],
#'   [task_ideology()], [task_salience()], [task_fact()]).
#'
#' @return A data frame with one row per input element, containing:
#'   \describe{
#'     \item{`id`}{Identifier for each input (from names or sequential integers).}
#'     \item{...}{Additional columns as defined by the task's `type_def`.
#'       For example, [task_sentiment()] returns `score` and `explanation`;
#'       [task_stance()] returns `stance` and `explanation`.}
#'   }
#'
#' @seealso
#' [qlm_code()] for the replacement function, [qlm_results()] for extracting results.
#'
#' @examples
#' \dontrun{
#' # Deprecated usage
#' texts <- c("I love this product!", "This is terrible.")
#' annotate(texts, task_sentiment(), model_name = "openai")
#'
#' # New recommended usage
#' coded <- qlm_code(texts, task_sentiment(), model_name = "openai")
#' qlm_results(coded)
#' }
#'
#' @keywords internal
#' @export
annotate <- function(.data, task, model_name, ...) {
  lifecycle::deprecate_warn("0.2.0", "annotate()", "qlm_code()")

  # Call qlm_code() and extract results
  coded <- qlm_code(.data, codebook = task, model_name = model_name, ...)
  qlm_results(coded)
}
