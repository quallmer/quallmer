#' Define an annotation task (deprecated)
#'
#' `r lifecycle::badge("deprecated")`
#'
#' `task()` has been deprecated in favor of [qlm_codebook()]. The new function
#' returns an object with dual class inheritance that works with both the old
#' and new APIs.
#'
#' @inheritParams qlm_codebook
#'
#' @return A task object (a list with class `"task"`) containing the task
#'   definition.
#'
#' @seealso [qlm_codebook()] for the replacement function.
#'
#' @examples
#' \dontrun{
#' # Deprecated usage
#' my_task <- task(
#'   name = "Sentiment",
#'   system_prompt = "Rate the sentiment from -1 (negative) to 1 (positive).",
#'   type_def = type_object(
#'     score = type_number("Sentiment score from -1 to 1"),
#'     explanation = type_string("Brief explanation")
#'   )
#' )
#'
#' # New recommended usage
#' my_codebook <- qlm_codebook(
#'   name = "Sentiment",
#'   instructions = "Rate the sentiment from -1 (negative) to 1 (positive).",
#'   schema = type_object(
#'     score = type_number("Sentiment score from -1 to 1"),
#'     explanation = type_string("Brief explanation")
#'   )
#' )
#' }
#'
#' @keywords internal
#' @export
task <- function(name, system_prompt, type_def, input_type = c("text", "image")) {
  lifecycle::deprecate_warn("0.2.0", "task()", "qlm_codebook()")

  input_type <- match.arg(input_type)

  structure(
    list(
      name = name,
      system_prompt = system_prompt,
      type_def = type_def,
      input_type = input_type
    ),
    class = "task"
  )
}

#' @export
#' @return Invisibly returns the input object \code{x}. Called for side effects (printing to console).
print.task <- function(x, ...) {
  cat("Quallmer task:", x$name, "\n")
  cat("  Input type: ", x$input_type, "\n", sep = "")
  cat("  Prompt:     ", substr(x$system_prompt, 1, 60),
      if (nchar(x$system_prompt) > 60) "..." else "", "\n", sep = "")
  cat("  Output:     ", class(x$type_def)[1], "\n", sep = "")
  invisible(x)
}
