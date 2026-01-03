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
#' @param level Character scalar. Measurement level of the variable:
#'   `"nominal"`, `"ordinal"`, `"interval"`, or `"ratio"`. Default is `"nominal"`.
#'   Different sets of agreement statistics are computed for each level.
#' @param tolerance Numeric. Tolerance for agreement with numeric data.
#'   Default is 0 (exact agreement required). Used for percent agreement calculation.
#'
#' @return A `qlm_comparison` object containing agreement statistics appropriate
#'   for the measurement level:
#'   \describe{
#'     \item{**Nominal level:**}{
#'       \itemize{
#'         \item `alpha_nominal`: Krippendorff's alpha
#'         \item `kappa`: Cohen's kappa (2 raters) or Fleiss' kappa (3+ raters)
#'         \item `kappa_type`: Character indicating "Cohen's" or "Fleiss'"
#'         \item `percent_agreement`: Simple percent agreement
#'       }
#'     }
#'     \item{**Ordinal level:**}{
#'       \itemize{
#'         \item `alpha_ordinal`: Krippendorff's alpha (ordinal)
#'         \item `kappa_weighted`: Weighted kappa (2 raters only)
#'         \item `w`: Kendall's W coefficient of concordance
#'         \item `rho`: Spearman's rho (average pairwise correlation)
#'       }
#'     }
#'     \item{**Interval/Ratio level:**}{
#'       \itemize{
#'         \item `alpha_interval`: Krippendorff's alpha (interval/ratio)
#'         \item `icc`: Intraclass correlation coefficient
#'         \item `r`: Pearson's r (average pairwise correlation)
#'       }
#'     }
#'     \item{`subjects`}{Number of units compared}
#'     \item{`raters`}{Number of raters}
#'     \item{`level`}{Measurement level}
#'     \item{`call`}{The function call}
#'   }
#'
#' @details
#' The function merges the coded objects by their `.id` column and only includes
#' units that are present in all objects. Missing values in any rater will
#' exclude that unit from analysis.
#'
#' **Measurement levels and statistics:**
#' - **Nominal**: For unordered categories. Computes Krippendorff's alpha,
#'   Cohen's/Fleiss' kappa, and percent agreement.
#' - **Ordinal**: For ordered categories. Computes Krippendorff's alpha (ordinal),
#'   weighted kappa (2 raters only), Kendall's W, and Spearman's rho.
#' - **Interval/Ratio**: For continuous data. Computes Krippendorff's alpha
#'   (interval/ratio), ICC, and Pearson's r.
#'
#' @seealso [qlm_validate()] for validation of coding against gold standards.
#'
#' @examples
#' \dontrun{
#' # Compare two LLM coding runs on movie reviews
#' set.seed(42)
#' reviews <- data_corpus_LMRDsample[sample(length(data_corpus_LMRDsample), size = 20)]
#' coded1 <- qlm_code(reviews, data_codebook_sentiment, model = "openai/gpt-4o-mini")
#' coded2 <- qlm_code(reviews, data_codebook_sentiment, model = "openai/gpt-4o")
#'
#' # Compare nominal data (polarity: neg/pos)
#' qlm_compare(coded1, coded2, by = "polarity", level = "nominal")
#'
#' # Compare ordinal data (rating: 1-10)
#' qlm_compare(coded1, coded2, by = "rating", level = "ordinal")
#'
#' # Compare three raters using Fleiss' kappa on polarity
#' coded3 <- qlm_replicate(coded1, params = params(temperature = 0.5))
#' qlm_compare(coded1, coded2, coded3, by = "polarity", measure = "kappa", level = "nominal")
#' }
#'
#' @export
qlm_compare <- function(...,
                        by,
                        level = c("nominal", "ordinal", "interval", "ratio"),
                        tolerance = 0) {

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

  # Compute all reliability measures appropriate for this level
  results <- compute_reliability_by_level(ratings, n_raters, level, tolerance)

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
    c(
      results,
      list(
        subjects = n_subjects,
        raters = n_raters,
        level = level,
        call = match.call()
      )
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
        level = level,
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


#' Compute all reliability statistics for a given level
#'
#' @param ratings Matrix where rows are subjects and columns are raters
#' @param n_raters Number of raters
#' @param level Measurement level
#' @param tolerance Tolerance for agreement
#'
#' @return List with all computed measures
#' @keywords internal
#' @noRd
compute_reliability_by_level <- function(ratings, n_raters, level, tolerance) {

  results <- list()

  # Percent agreement (computed for all levels)
  # For nominal data: exact agreement (tolerance is ignored)
  # For ordinal/interval/ratio: agreement within tolerance
  agrees <- apply(ratings, 1, function(row) {
    if (is.numeric(row)) {
      max(row) - min(row) <= tolerance
    } else {
      length(unique(as.character(row))) == 1
    }
  })
  results$percent_agreement <- mean(agrees)

  if (level == "nominal") {
    # Nominal measures: alpha, kappa

    # Krippendorff's alpha (nominal)
    ratings_numeric <- convert_to_numeric(ratings)
    ratings_t <- t(ratings_numeric)

    alpha_result <- tryCatch({
      irr::kripp.alpha(ratings_t, method = "nominal")
    }, error = function(e) {
      cli::cli_warn(c(
        "Failed to compute Krippendorff's alpha.",
        "x" = conditionMessage(e)
      ))
      list(value = NA_real_)
    })
    results$alpha_nominal <- alpha_result$value

    # Cohen's/Fleiss' kappa
    kappa_result <- tryCatch({
      if (n_raters == 2) {
        irr::kappa2(ratings_numeric)
      } else {
        irr::kappam.fleiss(ratings_numeric)
      }
    }, error = function(e) {
      cli::cli_warn(c(
        "Failed to compute kappa.",
        "x" = conditionMessage(e)
      ))
      list(value = NA_real_)
    })
    results$kappa <- kappa_result$value
    results$kappa_type <- if (n_raters == 2) "Cohen's" else "Fleiss'"

  } else if (level == "ordinal") {
    # Ordinal measures: alpha_ordinal, kappa_weighted, w, rho

    # Krippendorff's alpha (ordinal)
    ratings_numeric <- convert_to_numeric(ratings)
    ratings_t <- t(ratings_numeric)

    alpha_result <- tryCatch({
      irr::kripp.alpha(ratings_t, method = "ordinal")
    }, error = function(e) {
      cli::cli_warn(c(
        "Failed to compute Krippendorff's alpha (ordinal).",
        "x" = conditionMessage(e)
      ))
      list(value = NA_real_)
    })
    results$alpha_ordinal <- alpha_result$value

    # Weighted kappa (only for 2 raters)
    if (n_raters == 2) {
      kappa_weighted_result <- tryCatch({
        irr::kappa2(ratings_numeric, weight = "squared")
      }, error = function(e) {
        cli::cli_warn(c(
          "Failed to compute weighted kappa.",
          "x" = conditionMessage(e)
        ))
        list(value = NA_real_)
      })
      results$kappa_weighted <- kappa_weighted_result$value
    } else {
      results$kappa_weighted <- NULL
    }

    # Kendall's W
    kendall_result <- tryCatch({
      irr::kendall(ratings_numeric)
    }, error = function(e) {
      cli::cli_warn(c(
        "Failed to compute Kendall's W.",
        "x" = conditionMessage(e)
      ))
      list(value = NA_real_)
    })
    results$w <- kendall_result$value

    # Spearman's rho (average pairwise correlation)
    if (n_raters >= 2) {
      rho_values <- c()
      for (i in 1:(n_raters - 1)) {
        for (j in (i + 1):n_raters) {
          rho_values <- c(rho_values,
                          stats::cor(ratings_numeric[, i],
                                     ratings_numeric[, j],
                                     method = "spearman"))
        }
      }
      results$rho <- mean(rho_values)
    } else {
      results$rho <- NA_real_
    }

  } else if (level == "interval" || level == "ratio") {
    # Interval measures: alpha_interval, icc, r

    # Krippendorff's alpha (interval/ratio)
    ratings_numeric <- convert_to_numeric(ratings)
    ratings_t <- t(ratings_numeric)

    alpha_result <- tryCatch({
      irr::kripp.alpha(ratings_t, method = if (level == "interval") "interval" else "ratio")
    }, error = function(e) {
      cli::cli_warn(c(
        "Failed to compute Krippendorff's alpha (interval/ratio).",
        "x" = conditionMessage(e)
      ))
      list(value = NA_real_)
    })
    results$alpha_interval <- alpha_result$value

    # ICC
    icc_result <- tryCatch({
      irr::icc(ratings_numeric, model = "twoway", type = "agreement", unit = "single")
    }, error = function(e) {
      cli::cli_warn(c(
        "Failed to compute ICC.",
        "x" = conditionMessage(e)
      ))
      list(value = NA_real_)
    })
    results$icc <- icc_result$value

    # Pearson's r (average pairwise correlation)
    if (n_raters >= 2) {
      r_values <- c()
      for (i in 1:(n_raters - 1)) {
        for (j in (i + 1):n_raters) {
          r_values <- c(r_values,
                        stats::cor(ratings_numeric[, i],
                                   ratings_numeric[, j],
                                   method = "pearson"))
        }
      }
      results$r <- mean(r_values)
    } else {
      results$r <- NA_real_
    }
  }

  results
}

#' Compute reliability statistic (deprecated, kept for backward compatibility)
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
  cat("# Inter-rater reliability\n")
  cat("# Subjects:", x$subjects, "\n")
  cat("# Raters:  ", x$raters, "\n")
  cat("# Level:   ", x$level, "\n\n")

  # Print measures based on level
  if (x$level == "nominal") {
    # Nominal measures
    if (!is.null(x$alpha_nominal) && !is.na(x$alpha_nominal)) {
      cat("Krippendorff's alpha: ", sprintf("%.4f", x$alpha_nominal), "\n", sep = "")
    }
    if (!is.null(x$kappa) && !is.na(x$kappa)) {
      kappa_label <- paste0(x$kappa_type, " kappa:")
      cat(sprintf("%-22s", kappa_label), sprintf("%.4f", x$kappa), "\n", sep = "")
    }
    if (!is.null(x$percent_agreement) && !is.na(x$percent_agreement)) {
      cat("Percent agreement:    ", sprintf("%.4f", x$percent_agreement), "\n", sep = "")
    }

  } else if (x$level == "ordinal") {
    # Ordinal measures
    if (!is.null(x$alpha_ordinal) && !is.na(x$alpha_ordinal)) {
      cat("Krippendorff's alpha: ", sprintf("%.4f", x$alpha_ordinal), "\n", sep = "")
    }
    if (!is.null(x$kappa_weighted) && !is.na(x$kappa_weighted)) {
      cat("Weighted kappa:       ", sprintf("%.4f", x$kappa_weighted), "\n", sep = "")
    }
    if (!is.null(x$w) && !is.na(x$w)) {
      cat("Kendall's W:          ", sprintf("%.4f", x$w), "\n", sep = "")
    }
    if (!is.null(x$rho) && !is.na(x$rho)) {
      cat("Spearman's rho:       ", sprintf("%.4f", x$rho), "\n", sep = "")
    }
    if (!is.null(x$percent_agreement) && !is.na(x$percent_agreement)) {
      cat("Percent agreement:    ", sprintf("%.4f", x$percent_agreement), "\n", sep = "")
    }

  } else if (x$level == "interval" || x$level == "ratio") {
    # Interval measures
    if (!is.null(x$alpha_interval) && !is.na(x$alpha_interval)) {
      cat("Krippendorff's alpha: ", sprintf("%.4f", x$alpha_interval), "\n", sep = "")
    }
    if (!is.null(x$icc) && !is.na(x$icc)) {
      cat("ICC:                  ", sprintf("%.4f", x$icc), "\n", sep = "")
    }
    if (!is.null(x$r) && !is.na(x$r)) {
      cat("Pearson's r:          ", sprintf("%.4f", x$r), "\n", sep = "")
    }
    if (!is.null(x$percent_agreement) && !is.na(x$percent_agreement)) {
      cat("Percent agreement:    ", sprintf("%.4f", x$percent_agreement), "\n", sep = "")
    }
  }

  invisible(x)
}
