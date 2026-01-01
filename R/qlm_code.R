#' Code qualitative data with an LLM
#'
#' Applies a codebook to input data using a large language model, returning
#' a rich object that includes the codebook, execution settings, results, and
#' metadata for reproducibility.
#'
#' Arguments in `...` are dynamically routed to either [ellmer::chat()] or to
#' [ellmer::parallel_chat_structured()] based on their names.
#'
#' @param x Input data: a character vector of texts (for text codebooks) or
#'   file paths to images (for image codebooks). Named vectors will use names
#'   as identifiers in the output; unnamed vectors will use sequential integers.
#' @param codebook A codebook object created with [qlm_codebook()] or one of
#'   the predefined codebook functions ([task_sentiment()], [task_stance()],
#'   [task_ideology()], [task_salience()], [task_fact()]). Also accepts
#'   deprecated [task()] objects for backward compatibility.
#' @param model Provider (and optionally model) name in the form
#'   `"provider/model"` or `"provider"` (which will use the default model for
#'   that provider). Passed to the `name` argument of [ellmer::chat()].
#'   Examples: `"openai/gpt-4o-mini"`, `"anthropic/claude-3-5-sonnet-20241022"`,
#'   `"ollama/llama3.2"`, `"openai"` (uses default OpenAI model).
#' @param ... Additional arguments passed to either [ellmer::chat()] or to
#'   [ellmer::parallel_chat_structured()], based on argument name.
#'   Arguments not recognized by either function will generate a warning.
#' @param name Character string identifying this coding run. Default is `"original"`.
#'
#' @details
#' Progress indicators and error handling are provided by the underlying
#' [ellmer::parallel_chat_structured()] function. Set `verbose = TRUE` to see
#' progress messages during batch coding. Retry logic for API failures
#' should be configured through ellmer's options.
#'
#' @return A `qlm_coded` object (a tibble with additional attributes):
#'   \describe{
#'     \item{Data columns}{The coded results with a `.id` column for identifiers.}
#'     \item{Attributes}{`data`, `input_type`, and `run` (list containing name, call, codebook, chat_args, pcs_args, metadata, parent).}
#'   }
#'   The object prints as a tibble and can be used directly in data manipulation workflows.
#'
#' @seealso
#' [qlm_codebook()] for creating codebooks,
#' [task_sentiment()], [task_stance()], [task_ideology()], [task_salience()],
#' [task_fact()] for predefined codebooks, [annotate()] for the deprecated function.
#'
#' @examples
#' \dontrun{
#' # Basic sentiment analysis
#' texts <- c("I love this product!", "This is terrible.")
#' coded <- qlm_code(texts, task_sentiment(), model = "openai")
#' coded  # Print results as tibble
#'
#' # With named inputs (names become IDs in output)
#' texts <- c(doc1 = "Great service!", doc2 = "Very disappointing.")
#' coded <- qlm_code(texts, task_sentiment(), model = "openai")
#'
#' # Specify provider and model
#' coded <- qlm_code(texts, task_sentiment(), model = "openai/gpt-4o-mini")
#'
#' # With execution control
#' coded <- qlm_code(texts, task_sentiment(),
#'                   model = "openai/gpt-4o-mini",
#'                   max_active = 5)
#'
#' # Include token usage
#' coded <- qlm_code(texts, task_sentiment(),
#'                   model = "openai",
#'                   include_tokens = TRUE)
#'
#' # Inspect run information
#' print(coded)
#' attr(coded, "run")$name
#' attr(coded, "run")$metadata
#' }
#'
#' @export
qlm_code <- function(x, codebook, model, ..., name = "original") {
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
  if (codebook$input_type == "text" && !is.character(x)) {
    cli::cli_abort("This codebook expects text input (a character vector).")
  }
  if (codebook$input_type == "image" && !is.character(x)) {
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

  # Build system prompt from role and instructions
  system_prompt <- if (!is.null(codebook$role)) {
    paste(codebook$role, codebook$instructions, sep = "\n\n")
  } else {
    codebook$instructions
  }

  # Build chat object using ellmer::chat()
  chat <- do.call(ellmer::chat, c(
    list(
      name = model,
      system_prompt = system_prompt
    ),
    chat_args
  ))

  # Prepare prompts based on input type
  if (codebook$input_type == "image") {
    prompts <- lapply(x, ellmer::content_image_file)
  } else {
    prompts <- as.list(x)
  }

  # Execute with parallel_chat_structured
  results <- do.call(ellmer::parallel_chat_structured, c(
    list(
      chat = chat,
      prompts = prompts,
      type = codebook$schema
    ),
    pcs_args
  ))

  # Add ID column from input names or sequence
  results$id <- names(x) %||% seq_along(x)

  # Build metadata list
  metadata <- list(
    timestamp = Sys.time(),
    n_units = length(x),
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

  # Add model to chat_args for easy access
  chat_args$name <- model

  # Create and return qlm_coded object
  new_qlm_coded(
    results = results,
    codebook = codebook,
    data = x,
    input_type = codebook$input_type,
    chat_args = chat_args,
    pcs_args = pcs_args,
    metadata = metadata,
    name = name,
    call = match.call(),
    parent = NULL
  )
}

#' Create a qlm_coded object (internal)
#'
#' Low-level constructor for qlm_coded objects. This function is not exported
#' and is intended for internal use by [qlm_code()] and [qlm_replicate()].
#'
#' The object is a tibble with additional qlm_coded class and attributes.
#'
#' @param results Data frame of coded results with id column.
#' @param codebook A qlm_codebook object.
#' @param data The original input data (x from qlm_code).
#' @param input_type Type of input ("text" or "image").
#' @param chat_args List of arguments passed to ellmer::chat().
#' @param pcs_args List of arguments passed to ellmer::parallel_chat_structured().
#' @param metadata List of metadata (timestamp, versions, etc.).
#' @param name Character string identifying this run.
#' @param call The call that created this object.
#' @param parent Character string identifying parent run (NULL for originals).
#'
#' @return A qlm_coded object (tibble with attributes).
#' @importFrom utils head
#' @keywords internal
#' @noRd
new_qlm_coded <- function(results, codebook, data, input_type, chat_args,
                           pcs_args, metadata, name, call, parent = NULL) {
  # Rename id column to .id
  names(results)[names(results) == "id"] <- ".id"

  # Reorder columns to put .id first
  results <- results[, c(".id", setdiff(names(results), ".id"))]

  # Convert to tibble (always available via ellmer)
  results <- tibble::as_tibble(results)

  # Add qlm_coded class and attributes with hierarchical structure
  structure(
    results,
    class = c("qlm_coded", class(results)),
    data = data,
    input_type = input_type,
    run = list(
      name = name,
      call = call,
      codebook = codebook,
      chat_args = chat_args,
      pcs_args = pcs_args,
      metadata = metadata,
      parent = parent
    )
  )
}


#' Print a qlm_coded object
#'
#' @param x A qlm_coded object.
#' @param ... Additional arguments passed to print methods.
#'
#' @return Invisibly returns the input object \code{x}. Called for side effects (printing to console).
#' @keywords internal
#' @export
print.qlm_coded <- function(x, ...) {
  run <- attr(x, "run")

  # Print header
  cat("# quallmer coded object\n")
  cat("# Run:      ", run$name, "\n", sep = "")
  cat("# Codebook: ", run$codebook$name, "\n", sep = "")
  cat("# Model:    ", run$chat_args$name %||% "unknown", "\n", sep = "")
  cat("# Units:    ", run$metadata$n_units, "\n", sep = "")

  if (!is.null(run$parent)) {
    cat("# Parent:   ", run$parent, "\n", sep = "")
  }

  cat("\n")

  # Print data using parent class method
  NextMethod()
}

