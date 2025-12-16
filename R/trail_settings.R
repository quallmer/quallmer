#' Trail settings specification
#'
#' Simple description of an LLM configuration for use with quallmer Trails.
#'
#' @param provider Character. Backend provider identifier supported by ellmer,
#'   e.g. "openai", "ollama", "anthropic". See
#'   \href{https://ellmer.tidyverse.org/}{ellmer documentation} for all supported providers.
#' @param model Character. Model identifier, e.g. "gpt-4o-mini",
#'   "llama3.2:1b", "claude-3-5-sonnet-20241022".
#' @param temperature Numeric scalar. Sampling temperature (default 0).
#'   Valid range depends on provider: OpenAI (0-2), Anthropic (0-1), etc.
#' @param extra Named list of extra arguments merged into `api_args`.
#'
#' @return An object of class \code{"trail_setting"}.
#' @export
trail_settings <- function(
    provider    = "openai",
    model       = "gpt-4o-mini",
    temperature = 0,
    extra       = list()
) {
  if (!is.character(provider) || length(provider) != 1L || !nzchar(provider)) {
    stop("`provider` must be a non-empty character scalar.")
  }
  if (!is.character(model) || length(model) != 1L || !nzchar(model)) {
    stop("`model` must be a non-empty character scalar.")
  }
  if (!is.numeric(temperature) || length(temperature) != 1L) {
    stop("`temperature` must be a numeric scalar.")
  }
  if (!is.list(extra)) {
    stop("`extra` must be a list.")
  }

  structure(
    list(
      provider    = provider,
      model       = model,
      temperature = temperature,
      extra       = extra
    ),
    class = "trail_setting"
  )
}

#' @export
#' @return Invisibly returns the input object \code{x}. Called for side effects (printing to console).
print.trail_setting <- function(x, ...) {
  cat("Trail setting\n")
  cat("  Provider:   ", x$provider, "\n", sep = "")
  cat("  Model:      ", x$model,    "\n", sep = "")
  cat("  Temp:       ", x$temperature, "\n", sep = "")
  if (length(x$extra)) {
    cat("  Extra:      ", paste(names(x$extra), collapse = ", "), "\n", sep = "")
  }
  invisible(x)
}
