#' Code qualitative data with an LLM
#'
#' Applies a codebook to input data using a large language model, returning
#' a rich object that includes the codebook, execution settings, results, and
#' metadata for reproducibility.
#'
#' Arguments in `...` are dynamically routed to either [ellmer::chat()] or to
#' [ellmer::parallel_chat_structured()] based on their names.
#'
#' @param .data Input data: a character vector of texts (for text codebooks) or
#'   file paths to images (for image codebooks). Named vectors will use names
#'   as identifiers in the output; unnamed vectors will use sequential integers.
#' @param codebook A codebook object created with [qlm_codebook()] or one of
#'   the predefined codebook functions ([task_sentiment()], [task_stance()],
#'   [task_ideology()], [task_salience()], [task_fact()]). Also accepts
#'   deprecated [task()] objects for backward compatibility.
#' @param model_name Provider (and optionally model) name in the form
#'   `"provider/model"` or `"provider"` (which will use the default model for
#'   that provider). Passed to the `name` argument of [ellmer::chat()].
#'   Examples: `"openai/gpt-4o-mini"`, `"anthropic/claude-3-5-sonnet-20241022"`,
#'   `"ollama/llama3.2"`, `"openai"` (uses default OpenAI model).
#' @param ... Additional arguments passed to either [ellmer::chat()] or to
#'   [ellmer::parallel_chat_structured()], based on argument name.
#'   Arguments not recognized by either function will generate a warning.
#'
#' @details
#' Progress indicators and error handling are provided by the underlying
#' [ellmer::parallel_chat_structured()] function. Set `verbose = TRUE` to see
#' progress messages during batch coding. Retry logic for API failures
#' should be configured through ellmer's options.
#'
#' @return A `qlm_coded` object containing:
#'   \describe{
#'     \item{`codebook`}{The codebook used for coding.}
#'     \item{`settings`}{Execution settings (model, additional parameters).}
#'     \item{`results`}{Data frame with coded results (extract with [qlm_results()]).}
#'     \item{`metadata`}{Metadata including timestamp, versions, number of units.}
#'   }
#'
#' @seealso
#' [qlm_codebook()] for creating codebooks, [qlm_results()] for extracting results,
#' [task_sentiment()], [task_stance()], [task_ideology()], [task_salience()],
#' [task_fact()] for predefined codebooks, [annotate()] for the deprecated function.
#'
#' @examples
#' \dontrun{
#' # Basic sentiment analysis
#' texts <- c("I love this product!", "This is terrible.")
#' coded <- qlm_code(texts, task_sentiment(), model_name = "openai")
#' qlm_results(coded)
#'
#' # With named inputs (names become IDs in output)
#' texts <- c(doc1 = "Great service!", doc2 = "Very disappointing.")
#' coded <- qlm_code(texts, task_sentiment(), model_name = "openai")
#'
#' # Specify provider and model
#' coded <- qlm_code(texts, task_sentiment(), model_name = "openai/gpt-4o-mini")
#'
#' # With execution control
#' coded <- qlm_code(texts, task_sentiment(),
#'                   model_name = "openai/gpt-4o-mini",
#'                   max_active = 5)
#'
#' # Include token usage
#' coded <- qlm_code(texts, task_sentiment(),
#'                   model_name = "openai",
#'                   include_tokens = TRUE)
#'
#' # Inspect metadata
#' print(coded)
#' coded$settings
#' coded$metadata
#' }
#'
#' @export
qlm_code <- function(.data, codebook, model_name, ...) {
  # Accept both qlm_codebook and task objects, converting if needed
  if (inherits(codebook, "task") && !inherits(codebook, "qlm_codebook")) {
    codebook <- as_qlm_codebook(codebook)
  }

  if (!inherits(codebook, "qlm_codebook")) {
    cli::cli_abort(c(
      "{.arg codebook} must be created using {.fn qlm_codebook}.",
      "i" = "Use {.fn qlm_codebook} or one of the predefined codebook functions."
    ))
  }

  # Input validation
  if (codebook$input_type == "text" && !is.character(.data)) {
    cli::cli_abort("This codebook expects text input (a character vector).")
  }
  if (codebook$input_type == "image" && !is.character(.data)) {
    cli::cli_abort("This codebook expects image file paths (a character vector).")
  }

  # Get valid argument names from ellmer functions
  chat_arg_names <- names(formals(ellmer::chat))
  pcs_arg_names <- names(formals(ellmer::parallel_chat_structured))

  # Route ... arguments
  dots <- list(...)
  dot_names <- names(dots)

  chat_args <- dots[dot_names %in% chat_arg_names]
  pcs_args <- dots[dot_names %in% pcs_arg_names]

  # Warn about unrecognized arguments
  all_valid_names <- unique(c(chat_arg_names, pcs_arg_names))
  unknown_names <- setdiff(dot_names, all_valid_names)
  if (length(unknown_names) > 0) {
    cli::cli_warn(c(
      "The following argument{?s} {?was/were} not recognized and {?has/have} been ignored:",
      "x" = "{.arg {unknown_names}}"
    ))
  }

  # Build chat object using ellmer::chat()
  chat <- do.call(ellmer::chat, c(
    list(
      name = model_name,
      system_prompt = codebook$system_prompt
    ),
    chat_args
  ))

  # Prepare prompts based on input type
  if (codebook$input_type == "image") {
    prompts <- lapply(.data, ellmer::content_image_file)
  } else {
    prompts <- as.list(.data)
  }

  # Execute with parallel_chat_structured
  results <- do.call(ellmer::parallel_chat_structured, c(
    list(
      chat = chat,
      prompts = prompts,
      type = codebook$type_def
    ),
    pcs_args
  ))

  # Add ID and reorder columns
  results$id <- names(.data) %||% seq_along(.data)
  results <- results[, c("id", setdiff(names(results), "id"))]

  # Build settings list (capture key parameters)
  settings <- list(
    model_name = model_name,
    extra = chat_args
  )

  # Build metadata list
  metadata <- list(
    timestamp = Sys.time(),
    n_units = length(.data),
    ellmer_version = tryCatch(
      as.character(utils::packageVersion("ellmer")),
      error = function(e) NA_character_
    ),
    quallmer_version = tryCatch(
      as.character(utils::packageVersion("quallmer")),
      error = function(e) NA_character_
    ),
    R_version = paste(R.version$major, R.version$minor, sep = ".")
  )

  # Create and return qlm_coded object
  new_qlm_coded(
    codebook = codebook,
    settings = settings,
    results = results,
    metadata = metadata
  )
}
