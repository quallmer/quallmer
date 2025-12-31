#' Define a qualitative codebook
#'
#' Creates a codebook definition for use with [qlm_code()]. A codebook specifies
#' what information to extract from input data, including the system prompt
#' that guides the LLM and the structured output definition.
#'
#' This function replaces [task()], which is now deprecated. The returned object
#' has dual class inheritance (`c("qlm_codebook", "task")`) to maintain
#' backward compatibility with existing code using [annotate()].
#'
#' @param name Name of the codebook (character).
#' @param system_prompt System prompt to guide the model.
#' @param type_def Structured output definition, e.g., created by
#'   [ellmer::type_object()], [ellmer::type_array()], or [ellmer::type_enum()].
#' @param input_type Type of input data: `"text"` or `"image"`.
#'
#' @return A codebook object (a list with class `c("qlm_codebook", "task")`)
#'   containing the codebook definition. Use with [qlm_code()] to apply the
#'   codebook to data.
#'
#' @seealso [qlm_code()] for applying codebooks to data, [task_sentiment()],
#'   [task_stance()], [task_ideology()], [task_salience()], [task_fact()]
#'   for predefined codebooks, [task()] for the deprecated function.
#'
#' @examples
#' \dontrun{
#' # Define a custom codebook
#' my_codebook <- qlm_codebook(
#'   name = "Sentiment",
#'   system_prompt = "Rate the sentiment from -1 (negative) to 1 (positive).",
#'   type_def = ellmer::type_object(
#'     score = ellmer::type_number("Sentiment score from -1 to 1"),
#'     explanation = ellmer::type_string("Brief explanation")
#'   )
#' )
#'
#' # Use with qlm_code()
#' texts <- c("I love this!", "This is terrible.")
#' coded <- qlm_code(texts, my_codebook, model_name = "openai/gpt-4o-mini")
#' qlm_results(coded)
#' }
#'
#' @export
qlm_codebook <- function(name, system_prompt, type_def, input_type = c("text", "image")) {
  input_type <- match.arg(input_type)

  structure(
    list(
      name = name,
      system_prompt = system_prompt,
      type_def = type_def,
      input_type = input_type
    ),
    class = c("qlm_codebook", "task")  # Dual class for backward compatibility
  )
}


#' Convert objects to qlm_codebook
#'
#' Generic function to convert objects to qlm_codebook class.
#'
#' @param x An object to convert to qlm_codebook.
#' @param ... Additional arguments passed to methods.
#'
#' @return A qlm_codebook object.
#' @keywords internal
#' @export
as_qlm_codebook <- function(x, ...) {
  UseMethod("as_qlm_codebook")
}


#' @rdname as_qlm_codebook
#' @keywords internal
#' @export
as_qlm_codebook.task <- function(x, ...) {
  # If already a qlm_codebook, return as-is
  if (inherits(x, "qlm_codebook")) {
    return(x)
  }

  # Convert task to qlm_codebook by adding the class
  structure(
    x,
    class = c("qlm_codebook", "task")
  )
}


#' @rdname as_qlm_codebook
#' @keywords internal
#' @export
as_qlm_codebook.qlm_codebook <- function(x, ...) {
  x
}


#' @export
#' @keywords internal
#' @return Invisibly returns the input object \code{x}. Called for side effects (printing to console).
print.qlm_codebook <- function(x, ...) {
  cat("Quallmer codebook:", x$name, "\n")
  cat("  Input type: ", x$input_type, "\n", sep = "")
  cat("  Prompt:     ", substr(x$system_prompt, 1, 60),
      if (nchar(x$system_prompt) > 60) "..." else "", "\n", sep = "")
  cat("  Output:     ", class(x$type_def)[1], "\n", sep = "")
  invisible(x)
}
