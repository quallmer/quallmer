#' Compare coded results for inter-rater reliability
#'
#' Compares two or more `qlm_coded` objects to assess inter-rater reliability
#' or agreement. This function extracts a specified variable from each coded
#' result and computes reliability statistics using the irr package.
#'
#' @param ... Two or more `qlm_coded` objects to compare. These represent
#'   different "raters" (e.g., different LLM runs, different models, or
#'   human vs. LLM coding). Objects should have the same units (matching `.id`
#'   values).
#' @param by Character scalar. Name of the variable to compare across raters.
#'   Must be present in all `qlm_coded` objects.
#' @param measure Character scalar. The reliability/agreement measure to compute:
#'   \describe{
#'     \item{`"alpha"`}{Krippendorff's alpha (default)}
#'     \item{`"kappa"`}{Fleiss' kappa (for 3+ raters) or Cohen's kappa (for 2 raters)}
#'     \item{`"kendall"`}{Kendall's W coefficient of concordance}
#'     \item{`"agreement"`}{Simple percent agreement}
#'   }
#' @param level Character scalar. Measurement level of the variable:
#'   `"nominal"`, `"ordinal"`, `"interval"`, or `"ratio"`. Default is `"nominal"`.
#' @param tolerance Numeric. Tolerance for agreement with numeric data.
#'   Default is 0 (exact agreement required).
#'
#' @return A `qlm_comparison` object containing:
#'   \describe{
#'     \item{`measure`}{The reliability measure used}
#'     \item{`value`}{The computed reliability/agreement value}
#'     \item{`subjects`}{Number of units compared}
#'     \item{`raters`}{Number of raters}
#'     \item{`level`}{Measurement level}
#'     \item{`detail`}{Original output from the irr package function}
#'     \item{`call`}{The function call}
#'   }
#'
#' @details
#' The function merges the coded objects by their `.id` column and only includes
#' units that are present in all objects. Missing values in any rater will
#' exclude that unit from analysis.
#'
#' @seealso [validate()] for validation of coding against gold standards.
#'
#' @examples
#' \dontrun{
#' # Compare two LLM coding runs on movie reviews
#' set.seed(42)
#' reviews <- data_corpus_LMRDsample[sample(length(data_corpus_LMRDsample), size = 20)]
#' coded1 <- qlm_code(reviews, data_codebook_sentiment, model = "openai/gpt-4o-mini")
#' coded2 <- qlm_code(reviews, data_codebook_sentiment, model = "openai/gpt-4o")
#'
#' # Compute agreement for the polarity variable
#' qlm_compare(coded1, coded2, by = "polarity", measure = "agreement")
#' qlm_compare(coded1, coded2, by = "polarity", measure = "alpha")
#'
#' # Compute Krippendorf's alpha for the rating variable
#' qlm_compare(coded1, coded2, by = "rating", measure = "alpha", level = "ordinal")
#'
#' # Compare three raters using Fleiss' kappa on polarity
#' coded3 <- qlm_replicate(coded1, temperature = 0.5)
#' qlm_compare(coded1, coded2, coded3, by = "polarity", measure = "kappa", level = "nominal")
#' }
#'
#' @export
qlm_compare <- function(...,
                        by,
                        measure = c("alpha", "kappa", "kendall", "agreement"),
                        level = c("nominal", "ordinal", "interval", "ratio"),
                        tolerance = 0) {

  measure <- match.arg(measure)
  level <- match.arg(level)

  # Capture coded objects
  coded_list <- list(...)

  # Validate inputs
  if (length(coded_list) < 2) {
    cli::cli_abort("At least two {.cls qlm_coded} objects are required for comparison.")
  }

  # Check all objects are qlm_coded
  not_coded <- !vapply(coded_list, inherits, logical(1), "qlm_coded")
  if (any(not_coded)) {
    cli::cli_abort(c(
      "All arguments in {.arg ...} must be {.cls qlm_coded} objects.",
      "x" = "Argument{?s} {which(not_coded)} {?is/are} not {.cls qlm_coded} object{?s}."
    ))
  }

  # Check 'by' variable exists in all objects
  named_list <- coded_list
  names(named_list) <- paste("object", seq_along(coded_list))
  validate_by_variable(by, named_list)

  # Extract data and merge by .id
  n_raters <- length(coded_list)

  # Create names for raters
  rater_names <- names(coded_list)
  if (is.null(rater_names)) {
    rater_names <- paste0("rater", seq_len(n_raters))
  } else {
    # Replace empty names with default
    empty <- rater_names == ""
    rater_names[empty] <- paste0("rater", seq_len(n_raters))[empty]
  }

  # Extract relevant columns and rename
  data_list <- lapply(seq_along(coded_list), function(i) {
    obj <- coded_list[[i]]
    df <- data.frame(
      .id = obj[[".id"]],
      value = obj[[by]],
      stringsAsFactors = FALSE
    )
    names(df)[2] <- rater_names[i]
    df
  })

  # Merge all data frames
  merged <- data_list[[1]]
  for (i in seq(2, length(data_list))) {
    merged <- merge(merged, data_list[[i]], by = ".id", all = FALSE)
  }

  if (nrow(merged) == 0) {
    cli::cli_abort(c(
      "No common units (matching {.var .id} values) found across all {.cls qlm_coded} objects.",
      "i" = "Objects must have overlapping {.var .id} values for comparison."
    ))
  }

  # Extract rating matrix (exclude .id column)
  ratings <- as.matrix(merged[, -1, drop = FALSE])
  n_subjects <- nrow(ratings)

  # Remove rows with any NA values
  complete_rows <- stats::complete.cases(ratings)
  if (!any(complete_rows)) {
    cli::cli_abort(c(
      "No complete cases found after merging.",
      "i" = "All units have at least one missing value in variable {.var {by}}."
    ))
  }

  ratings <- ratings[complete_rows, , drop = FALSE]
  n_subjects <- nrow(ratings)

  # Compute reliability measure
  result <- compute_reliability(ratings, measure, level, tolerance)

  # Extract parent run names from coded objects
  parent_names <- vapply(coded_list, function(obj) {
    run <- attr(obj, "run")
    if (!is.null(run) && !is.null(run$name)) {
      run$name
    } else {
      NA_character_
    }
  }, character(1))

  # Build qlm_comparison object with run attribute
  structure(
    list(
      measure = measure,
      value = result$value,
      subjects = n_subjects,
      raters = n_raters,
      level = level,
      detail = result$detail,
      call = match.call()
    ),
    class = "qlm_comparison",
    run = list(
      name = paste0("comparison_", substr(digest::digest(parent_names), 1, 8)),
      call = match.call(),
      parent = parent_names[!is.na(parent_names)],  # Multiple parents
      metadata = list(
        timestamp = Sys.time(),
        n_subjects = n_subjects,
        n_raters = n_raters,
        measure = measure,
        quallmer_version = tryCatch(as.character(utils::packageVersion("quallmer")), error = function(e) NA_character_),
        R_version = paste(R.version$major, R.version$minor, sep = ".")
      )
    )
  )
}


#' Convert ratings to numeric format
#'
#' Converts categorical (character/factor) ratings to numeric format for irr package.
#' If data is already numeric, returns as-is.
#'
#' @param ratings Matrix of ratings
#' @return Numeric matrix
#' @keywords internal
#' @noRd
convert_to_numeric <- function(ratings) {
  # If already numeric, return as-is
  if (is.numeric(ratings)) {
    return(ratings)
  }

  # Get unique levels across all raters
  all_values <- unique(as.vector(ratings))
  all_levels <- sort(all_values[!is.na(all_values)])

  # Convert each column to factor with common levels, then to integer
  ratings_numeric <- apply(ratings, 2, function(col) {
    as.integer(factor(col, levels = all_levels))
  })

  # Preserve dimension names
  dimnames(ratings_numeric) <- dimnames(ratings)

  ratings_numeric
}


#' Compute reliability statistic
#'
#' @param ratings Matrix where rows are subjects and columns are raters
#' @param measure Reliability measure
#' @param level Measurement level
#' @param tolerance Tolerance for agreement
#'
#' @return List with value and detail
#' @keywords internal
#' @noRd
compute_reliability <- function(ratings, measure, level, tolerance) {

  if (measure == "alpha") {
    # Krippendorff's alpha - needs raters as rows
    # Convert to numeric for irr package
    ratings_numeric <- convert_to_numeric(ratings)
    ratings_t <- t(ratings_numeric)

    irr_result <- tryCatch({
      irr::kripp.alpha(ratings_t, method = level)
    }, error = function(e) {
      cli::cli_abort(c(
        "Failed to compute Krippendorff's alpha.",
        "x" = conditionMessage(e)
      ))
    })

    list(value = irr_result$value, detail = irr_result)

  } else if (measure == "kappa") {
    # Choose kappa based on number of raters
    # Convert to numeric for irr package
    ratings_numeric <- convert_to_numeric(ratings)
    n_raters <- ncol(ratings_numeric)

    if (n_raters == 2) {
      # Cohen's kappa for 2 raters
      irr_result <- tryCatch({
        irr::kappa2(ratings_numeric)
      }, error = function(e) {
        cli::cli_abort(c(
          "Failed to compute Cohen's kappa.",
          "x" = conditionMessage(e)
        ))
      })
    } else {
      # Fleiss' kappa for 3+ raters
      irr_result <- tryCatch({
        irr::kappam.fleiss(ratings_numeric)
      }, error = function(e) {
        cli::cli_abort(c(
          "Failed to compute Fleiss' kappa.",
          "x" = conditionMessage(e)
        ))
      })
    }

    list(value = irr_result$value, detail = irr_result)

  } else if (measure == "kendall") {
    # Kendall's W
    irr_result <- tryCatch({
      irr::kendall(ratings)
    }, error = function(e) {
      cli::cli_abort(c(
        "Failed to compute Kendall's W.",
        "x" = conditionMessage(e)
      ))
    })

    list(value = irr_result$value, detail = irr_result)

  } else if (measure == "agreement") {
    # Simple percent agreement
    # For each subject, check if all raters agree (within tolerance)
    agrees <- apply(ratings, 1, function(row) {
      if (is.numeric(row)) {
        max(row) - min(row) <= tolerance
      } else {
        length(unique(as.character(row))) == 1
      }
    })

    pct_agree <- mean(agrees)

    list(
      value = pct_agree,
      detail = list(
        subjects = nrow(ratings),
        raters = ncol(ratings),
        agreement = pct_agree,
        method = "percent agreement"
      )
    )

  } else {
    cli::cli_abort("Unknown measure: {.val {measure}}")
  }
}


#' Print a qlm_comparison object
#'
#' @param x A qlm_comparison object
#' @param ... Additional arguments (currently unused)
#'
#' @return Invisibly returns the input object
#' @keywords internal
#' @export
print.qlm_comparison <- function(x, ...) {
  cat("# Inter-rater reliability comparison\n")
  cat("# Measure:", x$measure, "\n")
  cat("# Value:  ", sprintf("%.4f", x$value), "\n")
  cat("# Subjects:", x$subjects, "\n")
  cat("# Raters:  ", x$raters, "\n")
  cat("# Level:   ", x$level, "\n")
  cat("\n")

  # Interpretation
  if (x$measure == "alpha" || x$measure == "kappa") {
    cat("Interpretation:\n")
    if (x$value < 0) {
      cat("  Poor agreement (systematic disagreement)\n")
    } else if (x$value < 0.20) {
      cat("  Slight agreement\n")
    } else if (x$value < 0.40) {
      cat("  Fair agreement\n")
    } else if (x$value < 0.60) {
      cat("  Moderate agreement\n")
    } else if (x$value < 0.80) {
      cat("  Substantial agreement\n")
    } else {
      cat("  Almost perfect agreement\n")
    }
  } else if (x$measure == "agreement") {
    cat(sprintf("Percent agreement: %.1f%%\n", x$value * 100))
  }

  invisible(x)
}
