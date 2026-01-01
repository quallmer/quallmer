# Declare global variables to avoid R CMD check notes
utils::globalVariables(c("unit_id", "coder_id", "code", "coder"))

# Null-coalescing operator (used throughout package)
#' @noRd
`%||%` <- function(x, y) if (length(x) == 0) y else x

# Validate that a 'by' variable exists in all provided objects
#' @param by Character string naming the variable to check for
#' @param objects Named list of data frames to check
#' @noRd
validate_by_variable <- function(by, objects) {
  # Check which objects are missing the variable
  has_var <- vapply(objects, function(x) by %in% names(x), logical(1))

  if (!all(has_var)) {
    missing_names <- names(objects)[!has_var]

    # Build informative error message
    msg <- c(
      "Variable {.var {by}} not found in {cli::qty(length(missing_names))} object{?s}.",
      "x" = "Missing in: {.arg {missing_names}}"
    )

    # Add available variables for each missing object
    for (obj_name in missing_names) {
      obj <- objects[[obj_name]]
      available <- setdiff(names(obj), ".id")
      if (length(available) > 0) {
        msg <- c(msg, "i" = "Available in {.arg {obj_name}}: {.val {available}}")
      } else {
        msg <- c(msg, "i" = "No variables available in {.arg {obj_name}}")
      }
    }

    cli::cli_abort(msg)
  }

  invisible(TRUE)
}
