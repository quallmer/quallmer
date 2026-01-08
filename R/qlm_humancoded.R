#' Convert human-coded data to qlm_coded format
#'
#' Converts a data frame of human-coded data into a `qlm_humancoded` object,
#' which inherits from `qlm_coded`. This enables provenance tracking and
#' integration with `qlm_compare()`, `qlm_validate()`, and `qlm_trace()` for
#' human-coded data alongside LLM-coded results.
#'
#' @param data A data frame containing human-coded data. Must include a `.id`
#'   column for unit identifiers and one or more coded variables.
#' @param name Character string identifying this coding run (e.g., "Coder_A",
#'   "expert_rater"). Default is "human_coder".
#' @param codebook Optional list containing coding instructions. Can include:
#'   \describe{
#'     \item{`name`}{Name of the coding scheme}
#'     \item{`instructions`}{Text describing coding instructions}
#'     \item{`schema`}{NULL (not used for human coding)}
#'   }
#'   If `NULL` (default), a minimal placeholder codebook is created.
#' @param texts Optional vector of original texts or data that were coded.
#'   Should correspond to the `.id` values in `data`. If provided, enables
#'   more complete provenance tracking.
#' @param metadata Optional list of metadata about the coding process. Can
#'   include any relevant information such as:
#'   \describe{
#'     \item{`coder_name`}{Name of the human coder}
#'     \item{`coder_id`}{Identifier for the coder}
#'     \item{`training`}{Description of coder training}
#'     \item{`date`}{Date of coding}
#'     \item{`notes`}{Any additional notes}
#'   }
#'   The function automatically adds `timestamp`, `n_units`, and
#'   `source = "human"`.
#'
#' @return A `qlm_humancoded` object (inherits from `qlm_coded`), which is a
#'   tibble with additional class and attributes for provenance tracking.
#'
#' @details
#' The resulting object has dual inheritance: `c("qlm_humancoded", "qlm_coded", ...)`
#' This allows it to work seamlessly with all quallmer functions while
#' maintaining a distinct identity in provenance trails.
#'
#' When printed, the object displays "Source: Human coder" instead of model
#' information, clearly distinguishing human from LLM coding in workflows.
#'
#' @seealso
#' [qlm_code()] for LLM coding, [qlm_compare()] for inter-rater reliability,
#' [qlm_validate()] for validation against gold standards, [qlm_trace()] for
#' provenance tracking.
#'
#' @examples
#' # Basic usage with minimal metadata
#' human_data <- data.frame(
#'   .id = 1:10,
#'   sentiment = sample(c("pos", "neg"), 10, replace = TRUE)
#' )
#'
#' human_coded <- qlm_humancoded(human_data, name = "Coder_A")
#' human_coded
#'
#' # With complete metadata
#' human_coded <- qlm_humancoded(
#'   human_data,
#'   name = "expert_rater",
#'   codebook = list(
#'     name = "Sentiment Analysis",
#'     instructions = "Code overall sentiment as positive or negative"
#'   ),
#'   metadata = list(
#'     coder_name = "Dr. Smith",
#'     coder_id = "EXP001",
#'     training = "5 years experience",
#'     date = "2024-01-15"
#'   )
#' )
#'
#' # Compare two human coders
#' human_coded_2 <- qlm_humancoded(
#'   data.frame(.id = 1:10, sentiment = sample(c("pos", "neg"), 10, replace = TRUE)),
#'   name = "Coder_B"
#' )
#'
#' qlm_compare(human_coded, human_coded_2, by = sentiment, level = "nominal")
#'
#' @export
qlm_humancoded <- function(
  data,
  name = "human_coder",
  codebook = NULL,
  texts = NULL,
  metadata = list()
) {
  # Validate inputs
  if (!is.data.frame(data)) {
    cli::cli_abort(c(
      "{.arg data} must be a data frame.",
      "i" = "Provide a data frame with a {.var .id} column and coded variables."
    ))
  }

  if (!".id" %in% names(data)) {
    cli::cli_abort(c(
      "{.arg data} must contain a {.var .id} column.",
      "i" = "Add a {.var .id} column with unique identifiers for each unit."
    ))
  }

  # Create minimal codebook if not provided
  if (is.null(codebook)) {
    codebook <- list(
      name = "Human-coded data",
      instructions = "Data coded by human annotator",
      schema = NULL
    )
  } else {
    # Ensure codebook has required structure
    if (!is.list(codebook)) {
      cli::cli_abort("{.arg codebook} must be a list or NULL.")
    }
    if (is.null(codebook$name)) {
      codebook$name <- "Human-coded data"
    }
    if (is.null(codebook$instructions)) {
      codebook$instructions <- "Data coded by human annotator"
    }
    codebook$schema <- NULL  # Always NULL for human coding
  }

  # Add qlm_codebook class
  class(codebook) <- c("qlm_codebook", "task")

  # Merge user metadata with defaults
  full_metadata <- c(
    list(
      timestamp = Sys.time(),
      n_units = nrow(data),
      source = "human"
    ),
    metadata
  )

  # Create qlm_coded object using the internal constructor
  result <- new_qlm_coded(
    results = data,
    codebook = codebook,
    data = texts,
    input_type = "human",
    chat_args = list(source = "human"),
    execution_args = list(),
    metadata = full_metadata,
    name = name,
    call = match.call(),
    parent = NULL
  )

  # Add qlm_humancoded class (dual inheritance)
  class(result) <- c("qlm_humancoded", class(result))

  result
}
