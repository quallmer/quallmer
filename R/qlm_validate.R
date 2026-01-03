# Declare global variables used in yardstick functions to avoid R CMD check NOTEs
utils::globalVariables(c("truth", "estimate"))

#' Validate coded results against gold standard
#'
#' Validates LLM-coded results from a `qlm_coded` object against a gold standard
#' (typically human annotations) using appropriate metrics based on measurement
#' level. For nominal data, computes accuracy, precision, recall, F1-score, and
#' Cohen's kappa. For ordinal data, computes accuracy and weighted kappa (linear
#' weighting), which accounts for the ordering and distance between categories.
#'
#' @param x A `qlm_coded` object containing LLM predictions to validate.
#' @param gold A data frame containing gold standard annotations. Must include
#'   a `.id` column for joining with `x` and the variable specified in `by`.
#'   (Can also be a qlm_coded object.)
#' @param by Character scalar. Name of the variable to validate. Must be present
#'   in both `x` and `gold`.
#' @param level Character scalar. Measurement level of the variable: `"nominal"`,
#'   `"ordinal"`, or `"interval"`. Default is `"nominal"`. Determines which
#'   validation metrics are computed.
#' @param average Character scalar. Averaging method for multiclass metrics
#'   (nominal level only):
#'   \describe{
#'     \item{`"macro"`}{Unweighted mean across classes (default)}
#'     \item{`"micro"`}{Aggregate contributions globally (sum TP, FP, FN)}
#'     \item{`"weighted"`}{Weighted mean by class prevalence}
#'     \item{`"none"`}{Return per-class metrics in addition to global metrics}
#'   }
#' @return A `qlm_validation` object containing:
#'   \describe{
#'     \item{`accuracy`}{Overall accuracy (nominal only)}
#'     \item{`precision`}{Precision (nominal only)}
#'     \item{`recall`}{Recall (nominal only)}
#'     \item{`f1`}{F1-score (nominal only)}
#'     \item{`kappa`}{Cohen's kappa (nominal only)}
#'     \item{`rho`}{Spearman's rho rank correlation (ordinal only)}
#'     \item{`tau`}{Kendall's tau rank correlation (ordinal only)}
#'     \item{`r`}{Pearson's r correlation (interval only)}
#'     \item{`icc`}{Intraclass correlation coefficient (interval only)}
#'     \item{`mae`}{Mean absolute error (ordinal/interval)}
#'     \item{`rmse`}{Root mean squared error (interval only)}
#'     \item{`by_class`}{Per-class metrics (nominal with `average = "none"` only)}
#'     \item{`confusion`}{Confusion matrix (nominal only)}
#'     \item{`n`}{Number of units compared}
#'     \item{`classes`}{Class/level labels}
#'     \item{`average`}{Averaging method used}
#'     \item{`level`}{Measurement level}
#'     \item{`variable`}{Variable name validated}
#'     \item{`call`}{Function call}
#'   }
#'
#' @details
#' The function performs an inner join between `x` and `gold` using the `.id`
#' column, so only units present in both datasets are included in validation.
#' Missing values (NA) in either predictions or gold standard are excluded with
#' a warning.
#'
#' **Measurement levels:**
#' - **Nominal**: Categories with no inherent ordering (e.g., topics, sentiment
#'   polarity). Metrics: accuracy, precision, recall, F1-score, Cohen's kappa
#'   (unweighted).
#' - **Ordinal**: Categories with meaningful ordering but unequal intervals
#'   (e.g., ratings 1-5, Likert scales). Metrics: Spearman's rho (`rho`, rank
#'   correlation), Kendall's tau (`tau`, rank correlation), and MAE (`mae`, mean
#'   absolute error). These measures account for the ordering of categories
#'   without assuming equal intervals.
#' - **Interval/Ratio**: Numeric data with equal intervals (e.g., counts,
#'   continuous measurements). Metrics: ICC (intraclass correlation), Pearson's r
#'   (linear correlation), MAE (mean absolute error), and RMSE (root mean squared
#'   error).
#'
#' For multiclass problems with nominal data, the `average` parameter controls
#' how per-class metrics are aggregated:
#' - **Macro averaging** computes metrics for each class independently and takes
#'   the unweighted mean. This treats all classes equally regardless of size.
#' - **Micro averaging** aggregates all true positives, false positives, and
#'   false negatives globally before computing metrics. This weights classes by
#'   their prevalence.
#' - **Weighted averaging** computes metrics for each class and takes the mean
#'   weighted by class size.
#' - **No averaging** (`average = "none"`) returns global macro-averaged metrics
#'   plus per-class breakdown.
#'
#' Note: The `average` parameter only affects precision, recall, and F1 for
#' nominal data. For ordinal data, these metrics are not computed.
#'
#' @seealso
#' [qlm_compare()] for inter-rater reliability between coded objects,
#' [qlm_code()] for creating coded objects,
#' [yardstick::accuracy()], [yardstick::precision()], [yardstick::recall()],
#' [yardstick::f_meas()], [yardstick::kap()], [yardstick::conf_mat()]
#'
#' @examples
#' \dontrun{
#' # Basic validation against gold standard
#'
#' set.seed(24)
#' reviews <- data_corpus_LMRDsample[sample(length(data_corpus_LMRDsample), size = 20)]
#'
#' # Code movie reviews
#' coded <- qlm_code(
#'   reviews,
#'   data_codebook_sentiment,
#'   model = "openai/gpt-4o"
#' )
#'
#' # Create gold standard from corpus metadata
#' gold <- data.frame(
#'   .id = coded$.id,
#'   polarity = quanteda::docvars(reviews, "polarity")
#' )
#'
#' # Validate polarity (nominal data)
#' validation <- qlm_validate(coded, gold, by = "polarity", level = "nominal")
#' print(validation)
#'
#' # Validate ratings (ordinal data)
#' gold_ratings <- data.frame(
#'   .id = coded$.id,
#'   rating = quanteda::docvars(reviews, "rating")
#' )
#' validation_ordinal <- qlm_validate(coded, gold_ratings, by = "rating", level = "ordinal")
#' print(validation_ordinal)
#'
#' # Use micro-averaging (nominal level only)
#' qlm_validate(coded, gold, by = "polarity", level = "nominal", average = "micro")
#'
#' # Get per-class breakdown (for nominal data only)
#' validation_detailed <- qlm_validate(coded, gold, by = "polarity",
#'                                     level = "nominal", average = "none")
#' print(validation_detailed)
#' validation_detailed$by_class$precision
#' }
#'
#' @export
qlm_validate <- function(
    x,
    gold,
    by,
    level = c("nominal", "ordinal", "interval"),
    average = c("macro", "micro", "weighted", "none")
) {

  # Match arguments
  level <- match.arg(level)

  # Check if average was explicitly provided before match.arg() assigns default
  average_was_supplied <- !missing(average)
  average <- match.arg(average)

  # Warn if average is specified for non-nominal data
  if (level != "nominal" && average_was_supplied) {
    cli::cli_warn(c(
      "The {.arg average} parameter only applies to nominal (multiclass) data.",
      "i" = "For {.val {level}} data, this parameter is ignored."
    ))
  }

  # Validate inputs
  if (!inherits(x, "qlm_coded")) {
    cli::cli_abort(c(
      "{.arg x} must be a {.cls qlm_coded} object.",
      "i" = "Use {.fn qlm_code} to create coded results."
    ))
  }

  if (!is.data.frame(gold)) {
    cli::cli_abort("{.arg gold} must be a data frame or {.cls qlm_coded} object.")
  }

  if (!".id" %in% names(x)) {
    cli::cli_abort(c(
      "{.arg x} must contain a {.var .id} column.",
      "i" = "This should be created automatically by {.fn qlm_code}."
    ))
  }

  if (!".id" %in% names(gold)) {
    cli::cli_abort(c(
      "{.arg gold} must contain a {.var .id} column for joining.",
      "i" = "Add a {.var .id} column matching the identifiers in {.arg x}."
    ))
  }

  # Check that 'by' variable exists in both objects
  validate_by_variable(by, list(x = x, gold = gold))

  # Extract relevant columns
  x_data <- data.frame(
    .id = x[[".id"]],
    estimate = x[[by]],
    stringsAsFactors = FALSE
  )

  gold_data <- data.frame(
    .id = gold[[".id"]],
    truth = gold[[by]],
    stringsAsFactors = FALSE
  )

  # Inner join by .id
  merged <- merge(x_data, gold_data, by = ".id", all = FALSE, sort = TRUE)

  # Check for empty result
  if (nrow(merged) == 0) {
    cli::cli_abort(c(
      "No matching units found between {.arg x} and {.arg gold}.",
      "i" = "Ensure {.var .id} values overlap between the two datasets."
    ))
  }

  # Check for NA values and warn
  na_estimate <- sum(is.na(merged$estimate))
  na_truth <- sum(is.na(merged$truth))

  if (na_estimate > 0 || na_truth > 0) {
    cli::cli_warn(c(
      "Missing values detected and will be excluded:",
      "i" = "{na_estimate} missing value{?s} in predictions",
      "i" = "{na_truth} missing value{?s} in gold standard"
    ))
  }

  # Remove rows with any NA
  merged <- merged[stats::complete.cases(merged), ]

  # Check for remaining data
  if (nrow(merged) == 0) {
    cli::cli_abort(c(
      "No complete cases found after removing missing values.",
      "i" = "All units have at least one missing value."
    ))
  }

  # Get unique levels from both columns
  all_levels <- sort(unique(c(
    as.character(merged$estimate),
    as.character(merged$truth)
  )))

  # Convert both to factors with shared levels
  # For ordinal data, use ordered factors for proper weighted kappa
  if (level == "ordinal") {
    merged$estimate <- factor(merged$estimate, levels = all_levels, ordered = TRUE)
    merged$truth <- factor(merged$truth, levels = all_levels, ordered = TRUE)
  } else {
    merged$estimate <- factor(merged$estimate, levels = all_levels)
    merged$truth <- factor(merged$truth, levels = all_levels)
  }

  # Map average to yardstick estimator
  estimator <- switch(average,
    "macro" = "macro",
    "micro" = "micro",
    "weighted" = "macro_weighted",
    "none" = "macro"  # Use macro for global metrics when average = "none"
  )

  # Determine which metrics to compute based on level
  if (level == "nominal") {
    metrics_to_compute <- c("accuracy", "precision", "recall", "f1", "kappa")
  } else if (level == "ordinal") {
    metrics_to_compute <- c("rho", "tau", "mae")
  } else if (level == "interval") {
    metrics_to_compute <- c("icc", "r", "mae", "rmse")
  }

  # Initialize results list
  results <- list()

  # Compute accuracy (no estimator parameter)
  if ("accuracy" %in% metrics_to_compute) {
    acc <- yardstick::accuracy(merged, truth = truth, estimate = estimate)
    results$accuracy <- acc$.estimate
  } else {
    results$accuracy <- NULL
  }

  # Compute precision
  if ("precision" %in% metrics_to_compute) {
    prec <- yardstick::precision(merged, truth = truth, estimate = estimate,
                                  estimator = estimator)
    results$precision <- prec$.estimate
  } else {
    results$precision <- NULL
  }

  # Compute recall
  if ("recall" %in% metrics_to_compute) {
    rec <- yardstick::recall(merged, truth = truth, estimate = estimate,
                             estimator = estimator)
    results$recall <- rec$.estimate
  } else {
    results$recall <- NULL
  }

  # Compute F1
  if ("f1" %in% metrics_to_compute) {
    f1 <- yardstick::f_meas(merged, truth = truth, estimate = estimate,
                            estimator = estimator)
    results$f1 <- f1$.estimate
  } else {
    results$f1 <- NULL
  }

  # Compute kappa (only for nominal data)
  if ("kappa" %in% metrics_to_compute) {
    kap <- yardstick::kap(merged, truth = truth, estimate = estimate,
                          weighting = "none")
    results$kappa <- kap$.estimate
  } else {
    results$kappa <- NULL
  }

  # Ordinal measures (require numeric conversion)
  if (level == "ordinal") {
    # Convert ordered factors to numeric for correlation and distance measures
    estimate_num <- as.numeric(merged$estimate)
    truth_num <- as.numeric(merged$truth)

    # Spearman's rho (rank correlation)
    if ("rho" %in% metrics_to_compute) {
      results$rho <- stats::cor(truth_num, estimate_num, method = "spearman")
    } else {
      results$rho <- NULL
    }

    # Kendall's tau (rank correlation)
    if ("tau" %in% metrics_to_compute) {
      results$tau <- stats::cor(truth_num, estimate_num, method = "kendall")
    } else {
      results$tau <- NULL
    }

    # Mean Absolute Error
    if ("mae" %in% metrics_to_compute) {
      results$mae <- mean(abs(estimate_num - truth_num))
    } else {
      results$mae <- NULL
    }
  }

  # Interval measures (require numeric conversion)
  if (level == "interval") {
    # For interval data, convert to numeric
    estimate_num <- as.numeric(as.character(merged$estimate))
    truth_num <- as.numeric(as.character(merged$truth))

    # Create data frame for yardstick functions
    numeric_data <- data.frame(
      truth = truth_num,
      estimate = estimate_num
    )

    # Pearson's r (linear correlation)
    if ("r" %in% metrics_to_compute) {
      results$r <- stats::cor(truth_num, estimate_num, method = "pearson")
    } else {
      results$r <- NULL
    }

    # Mean Absolute Error (using yardstick)
    if ("mae" %in% metrics_to_compute) {
      mae_result <- yardstick::mae(numeric_data, truth = truth, estimate = estimate)
      results$mae <- mae_result$.estimate
    } else {
      results$mae <- NULL
    }

    # Root Mean Squared Error (using yardstick)
    if ("rmse" %in% metrics_to_compute) {
      rmse_result <- yardstick::rmse(numeric_data, truth = truth, estimate = estimate)
      results$rmse <- rmse_result$.estimate
    } else {
      results$rmse <- NULL
    }

    # Intraclass Correlation Coefficient (using irr package)
    if ("icc" %in% metrics_to_compute) {
      if (requireNamespace("irr", quietly = TRUE)) {
        # ICC for two-rater agreement (model = "twoway", type = "agreement")
        icc_data <- data.frame(truth = truth_num, estimate = estimate_num)
        icc_result <- irr::icc(icc_data, model = "twoway", type = "agreement", unit = "single")
        results$icc <- icc_result$value
      } else {
        cli::cli_warn(c(
          "Package {.pkg irr} is required for ICC computation but is not installed.",
          "i" = "Install it with: {.code install.packages('irr')}"
        ))
        results$icc <- NA_real_
      }
    } else {
      results$icc <- NULL
    }
  }

  # Compute confusion matrix (only for nominal data)
  if (level == "nominal") {
    conf_mat <- yardstick::conf_mat(merged, truth = truth, estimate = estimate)
  } else {
    conf_mat <- NULL
  }

  # Compute per-class metrics if average = "none"
  by_class <- NULL
  if (average == "none" && any(c("precision", "recall", "f1") %in% metrics_to_compute)) {
    # Extract confusion matrix table
    cm_table <- conf_mat$table
    classes <- rownames(cm_table)

    # Initialize per-class metrics
    prec_by_class <- rep(NA_real_, length(classes))
    rec_by_class <- rep(NA_real_, length(classes))
    f1_by_class <- rep(NA_real_, length(classes))
    names(prec_by_class) <- classes
    names(rec_by_class) <- classes
    names(f1_by_class) <- classes

    # Compute per-class metrics
    for (i in seq_along(classes)) {
      class_label <- classes[i]

      # Extract TP, FP, FN for this class
      TP <- cm_table[class_label, class_label]
      FP <- sum(cm_table[, class_label]) - TP
      FN <- sum(cm_table[class_label, ]) - TP

      # Compute precision
      if ("precision" %in% metrics_to_compute) {
        prec_by_class[i] <- if (TP + FP == 0) NA_real_ else TP / (TP + FP)
      }

      # Compute recall
      if ("recall" %in% metrics_to_compute) {
        rec_by_class[i] <- if (TP + FN == 0) NA_real_ else TP / (TP + FN)
      }

      # Compute F1
      if ("f1" %in% metrics_to_compute) {
        prec <- if (TP + FP == 0) NA_real_ else TP / (TP + FP)
        rec <- if (TP + FN == 0) NA_real_ else TP / (TP + FN)
        if (is.na(prec) || is.na(rec) || (prec + rec) == 0) {
          f1_by_class[i] <- NA_real_
        } else {
          f1_by_class[i] <- 2 * prec * rec / (prec + rec)
        }
      }
    }

    # Build by_class tibble
    by_class_data <- data.frame(class = classes, stringsAsFactors = FALSE)
    if ("precision" %in% metrics_to_compute) {
      by_class_data$precision <- prec_by_class
    }
    if ("recall" %in% metrics_to_compute) {
      by_class_data$recall <- rec_by_class
    }
    if ("f1" %in% metrics_to_compute) {
      by_class_data$f1 <- f1_by_class
    }

    by_class <- tibble::as_tibble(by_class_data)
  }

  # Extract parent run name from coded object
  parent_name <- NA_character_
  if (inherits(x, "qlm_coded")) {
    run <- attr(x, "run")
    if (!is.null(run) && !is.null(run$name)) {
      parent_name <- run$name
    }
  }

  # Extract gold run name if it's a qlm_coded object
  gold_name <- NA_character_
  if (inherits(gold, "qlm_coded")) {
    gold_run <- attr(gold, "run")
    if (!is.null(gold_run) && !is.null(gold_run$name)) {
      gold_name <- gold_run$name
    }
  }

  # Build return object with run attribute
  result <- list(
    # Nominal metrics
    accuracy = results$accuracy,
    precision = results$precision,
    recall = results$recall,
    f1 = results$f1,
    kappa = results$kappa,
    # Ordinal metrics
    rho = results$rho,
    tau = results$tau,
    # Interval metrics
    r = results$r,
    icc = results$icc,
    # Shared metrics (ordinal/interval)
    mae = results$mae,
    rmse = results$rmse,
    # Additional info
    by_class = by_class,
    confusion = conf_mat,
    n = nrow(merged),
    classes = all_levels,
    average = average,
    level = level,
    variable = by,
    call = match.call()
  )

  # Set class and add run attribute
  structure(
    result,
    class = "qlm_validation",
    run = list(
      name = paste0("validation_", substr(digest::digest(list(parent_name, gold_name)), 1, 8)),
      call = match.call(),
      parent = c(parent_name, gold_name)[!is.na(c(parent_name, gold_name))],  # Parent(s)
      metadata = list(
        timestamp = Sys.time(),
        n_subjects = nrow(merged),
        n_classes = length(all_levels),
        measure = paste(measure, collapse = ","),
        average = average,
        quallmer_version = tryCatch(as.character(utils::packageVersion("quallmer")), error = function(e) NA_character_),
        R_version = paste(R.version$major, R.version$minor, sep = ".")
      )
    )
  )
}


#' Print a qlm_validation object
#'
#' @param x A qlm_validation object.
#' @param ... Additional arguments (currently unused).
#'
#' @return Invisibly returns the input object.
#' @keywords internal
#' @export
print.qlm_validation <- function(x, ...) {
  cat("# quallmer validation\n")
  cat("# n: ", x$n, " | ", sep = "")

  # Use "levels" for ordinal data, "classes" for nominal data
  if (x$level == "ordinal") {
    cat("levels: ", length(x$classes), "\n\n", sep = "")
  } else {
    cat("classes: ", length(x$classes), " | ", sep = "")
    cat("average: ", x$average, "\n\n", sep = "")
  }

  # Print metrics based on level
  if (x$level == "nominal" && x$average == "none") {
    # Global metrics
    cat("Global:\n")
    if (!is.null(x$accuracy)) {
      cat("  accuracy:      ", sprintf("%.4f", x$accuracy), "\n", sep = "")
    }
    if (!is.null(x$kappa)) {
      cat("  Cohen's kappa: ", sprintf("%.4f", x$kappa), "\n", sep = "")
    }
    cat("\n")

    # Per-class metrics
    if (!is.null(x$by_class)) {
      cat("By class:\n")
      print(x$by_class, n = Inf)
    }
  } else {
    # Aggregated metrics
    # Nominal metrics
    if (!is.null(x$accuracy)) {
      cat("accuracy:      ", sprintf("%.4f", x$accuracy), "\n", sep = "")
    }
    if (!is.null(x$precision)) {
      cat("precision:     ", sprintf("%.4f", x$precision), "\n", sep = "")
    }
    if (!is.null(x$recall)) {
      cat("recall:        ", sprintf("%.4f", x$recall), "\n", sep = "")
    }
    if (!is.null(x$f1)) {
      cat("f1:            ", sprintf("%.4f", x$f1), "\n", sep = "")
    }
    if (!is.null(x$kappa)) {
      cat("Cohen's kappa: ", sprintf("%.4f", x$kappa), "\n", sep = "")
    }

    # Ordinal metrics
    if (!is.null(x$rho)) {
      cat("Spearman's rho:", sprintf("%.4f", x$rho), "\n", sep = "")
    }
    if (!is.null(x$tau)) {
      cat("Kendall's tau: ", sprintf("%.4f", x$tau), "\n", sep = "")
    }

    # Interval metrics
    if (!is.null(x$r)) {
      cat("Pearson's r:   ", sprintf("%.4f", x$r), "\n", sep = "")
    }
    if (!is.null(x$icc)) {
      cat("ICC:           ", sprintf("%.4f", x$icc), "\n", sep = "")
    }

    # Shared metrics (ordinal/interval)
    if (!is.null(x$mae)) {
      cat("MAE:           ", sprintf("%.4f", x$mae), "\n", sep = "")
    }
    if (!is.null(x$rmse)) {
      cat("RMSE:          ", sprintf("%.4f", x$rmse), "\n", sep = "")
    }
  }

  invisible(x)
}
