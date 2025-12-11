#' Apply an annotation task to input data
#'
#' Applies an annotation task to input data, automatically detecting the
#' input type based on the task definition. Delegates processing to the
#' task's internal `run()` method.
#'
#' @param .data Input data: a character vector of texts (for text tasks) or
#'   file paths to images (for image tasks). Named vectors will use names
#'   as identifiers in the output; unnamed vectors will use sequential integers.
#' @param task A task object created with [task()]
#' @param ... Additional arguments passed to the task's `run()` method:
#'   \describe{
#'     \item{`chat_fn`}{Chat function to use (default: [ellmer::chat_openai()]).
#'       Other options include [ellmer::chat_ollama()], [ellmer::chat_google_gemini()], etc.}
#'     \item{`model`}{Model identifier string (default: `"gpt-4o"`).}
#'     \item{`verbose`}{Logical; whether to print progress messages
#'       (default: `TRUE`).}
#'   }
#'   Any additional arguments are passed to `chat_fn()`, such as
#'   `temperature`, `seed`, or other provider-specific options.
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
#' [task()] for creating custom tasks, [task_sentiment()], [task_stance()],
#' [task_ideology()], [task_salience()], [task_fact()] for predefined tasks,
#' [validate()] for computing agreement metrics on annotations.
#'
#' @examples
#' \dontrun{
#' # Basic sentiment analysis
#' texts <- c("I love this product!", "This is terrible.")
#' result <- annotate(texts, task_sentiment())
#'
#' # With named inputs (names become IDs in output)
#' texts <- c(doc1 = "Great service!", doc2 = "Very disappointing.")
#' result <- annotate(texts, task_sentiment())
#'
#' # Using a different model
#' result <- annotate(texts, task_sentiment(), model = "gpt-4o-mini")
#'
#' # With temperature setting (passed to chat_fn)
#' result <- annotate(texts, task_sentiment(), temperature = 0)
#'
#' # Using Ollama locally
#' result <- annotate(texts, task_sentiment(),
#'                    chat_fn = ellmer::chat_ollama,
#'                    model = "llama3.2:3b")
#' }
#'
#' @export
annotate <- function(.data, task, ...) {
  if (!inherits(task, "task")) {
    stop("`task` must be created using task().")
  }

  input_type <- task$input_type

  # Simple validation
  if (input_type == "text" && !is.character(.data)) {
    stop("This task expects text input.")
  }
  if (input_type == "image" && !is.character(.data)) {
    stop("This task expects image file paths (a character vector).")
  }

  task$run(.data, ...)
}
