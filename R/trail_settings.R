#' Trail settings specification
#'
#' Define a reproducible specification of an LLM setting for use with
#' quallmer Trail. This object captures the provider, model name,
#' temperature, and any optional extra arguments.
#'
#' @param provider Character. Backend provider, e.g. "openai", "ollama",
#'   "azure".
#' @param model Character. Model identifier, e.g. "gpt-4.1-mini",
#'   "gpt-4o-mini", "llama3.1:8b".
#' @param temperature Numeric scalar. Sampling temperature (default 0).
#' @param extra Named list of additional model arguments passed to
#'   `annotate()` via `api_args` if needed (e.g. penalties or safety flags).
#'
#' @return An object of class \code{"trail_setting"}.
#' @export
trail_settings <- function(
    provider    = "openai",
    model       = "gpt-4.1-mini",
    temperature = 0,
    extra       = list()
) {
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

#' Print method for trail_setting
#'
#' @param x A \code{trail_setting} object.
#' @param ... Ignored.
#' @export
print.trail_settings <- function(x, ...) {
  cat("Trail setting\n")
  cat("  Provider:   ", x$provider,    "\n", sep = "")
  cat("  Model:      ", x$model,       "\n", sep = "")
  cat("  Temp:       ", x$temperature, "\n", sep = "")
  if (length(x$extra)) {
    cat("  Extra:      ", paste(names(x$extra), collapse = ", "), "\n", sep = "")
  }
  invisible(x)
}
