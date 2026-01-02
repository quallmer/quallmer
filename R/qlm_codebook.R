#' Define a qualitative codebook
#'
#' Creates a codebook definition for use with [qlm_code()]. A codebook specifies
#' what information to extract from input data, including the instructions
#' that guide the LLM and the structured output schema.
#'
#' This function replaces [task()], which is now deprecated. The returned object
#' has dual class inheritance (`c("qlm_codebook", "task")`) to maintain
#' backward compatibility with existing code using [annotate()].
#'
#' @param name Name of the codebook (character).
#' @param instructions Instructions to guide the model in performing the coding task.
#' @param schema Structured output definition, e.g., created by
#'   [type_object()], [type_array()], or [type_enum()].
#' @param role Optional role description for the model (e.g., "You are an expert
#'   annotator"). If provided, this will be prepended to the instructions when
#'   creating the system prompt.
#' @param input_type Type of input data: `"text"` (default) or `"image"`.
#'
#' @return A codebook object (a list with class `c("qlm_codebook", "task")`)
#'   containing the codebook definition. Use with [qlm_code()] to apply the
#'   codebook to data.
#'
#' @seealso [qlm_code()] for applying codebooks to data,
#'   [data_codebook_sentiment], [data_codebook_stance], [data_codebook_ideology],
#'   [data_codebook_salience], [data_codebook_fact] for predefined codebooks,
#'   [task()] for the deprecated function.
#'
#' @examples
#' \dontrun{
#' # Define a custom codebook
#' my_codebook <- qlm_codebook(
#'   name = "Sentiment",
#'   instructions = "Rate the sentiment from -1 (negative) to 1 (positive).",
#'   schema = type_object(
#'     score = type_number("Sentiment score from -1 to 1"),
#'     explanation = type_string("Brief explanation")
#'   )
#' )
#'
#' # With a role
#' my_codebook <- qlm_codebook(
#'   name = "Sentiment",
#'   instructions = "Rate the sentiment from -1 (negative) to 1 (positive).",
#'   schema = type_object(
#'     score = type_number("Sentiment score from -1 to 1"),
#'     explanation = type_string("Brief explanation")
#'   ),
#'   role = "You are an expert sentiment analyst."
#' )
#'
#' # Use with qlm_code()
#' texts <- c("I love this!", "This is terrible.")
#' coded <- qlm_code(texts, my_codebook, model = "openai/gpt-4o-mini")
#' coded  # Print results as tibble
#' }
#'
#' @export
qlm_codebook <- function(name, instructions, schema, role = NULL, input_type = c("text", "image")) {
  input_type <- match.arg(input_type)

  structure(
    list(
      name = name,
      instructions = instructions,
      schema = schema,
      role = role,
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
  cat("quallmer codebook:", x$name, "\n")
  cat("  Input type:   ", x$input_type, "\n", sep = "")
  if (!is.null(x$role)) {
    cat("  Role:         ", substr(x$role, 1, 60),
        if (nchar(x$role) > 60) "..." else "", "\n", sep = "")
  }
  cat("  Instructions: ", substr(x$instructions, 1, 60),
      if (nchar(x$instructions) > 60) "..." else "", "\n", sep = "")
  cat("  Output schema:", class(x$schema)[1], "\n", sep = "")
  invisible(x)
}
