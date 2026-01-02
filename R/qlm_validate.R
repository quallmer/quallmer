# Declare global variables used in yardstick functions to avoid R CMD check NOTEs
utils::globalVariables(c("truth", "estimate"))

#' Validate coded results against gold standard
#'
#' Validates LLM-coded results from a `qlm_coded` object against a gold standard
#' (typically human annotations) using classification metrics from the yardstick
#' package. Computes accuracy, precision, recall, F1-score, and Cohen's kappa.
#'
#' @param x A `qlm_coded` object containing LLM predictions to validate.
#' @param gold A data frame containing gold standard annotations. Must include
#'   a `.id` column for joining with `x` and the variable specified in `by`.
#'   (Can also be a qlm_coded object.)
#' @param by Character scalar. Name of the variable to validate. Must be present
#'   in both `x` and `gold`.
#' @param measure Character scalar. Which metrics to compute:
#'   \describe{
#'     \item{`"all"`}{Compute all metrics (default)}
#'     \item{`"accuracy"`}{Overall accuracy only}
#'     \item{`"precision"`}{Precision only}
#'     \item{`"recall"`}{Recall only}
#'     \item{`"f1"`}{F1-score only}
#'     \item{`"kappa"`}{Cohen's kappa only}
#'   }
#' @param average Character scalar. Averaging method for multiclass metrics:
#'   \describe{
#'     \item{`"macro"`}{Unweighted mean across classes (default)}
#'     \item{`"micro"`}{Aggregate contributions globally (sum TP, FP, FN)}
#'     \item{`"weighted"`}{Weighted mean by class prevalence}
#'     \item{`"none"`}{Return per-class metrics in addition to global metrics}
#'   }
#' @inheritParams qlm_compare
#' @return A `qlm_validation` object containing:
#'   \describe{
#'     \item{`accuracy`}{Overall accuracy (if computed)}
#'     \item{`precision`}{Precision (if computed)}
#'     \item{`recall`}{Recall (if computed)}
#'     \item{`f1`}{F1-score (if computed)}
#'     \item{`kappa`}{Cohen's kappa (if computed)}
#'     \item{`by_class`}{Per-class metrics (only when `average = "none"`)}
#'     \item{`confusion`}{Confusion matrix (yardstick conf_mat object)}
#'     \item{`n`}{Number of units compared}
#'     \item{`classes`}{Class labels}
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
#' For multiclass problems, the `average` parameter controls how per-class
#' metrics are aggregated:
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
#'   model = "google_gemini/gemini-2.5-flash"
#' )
#'
#' # Create gold standard from corpus metadata
#' gold <- data.frame(
#'   .id = coded$.id,
#'   polarity = quanteda::docvars(reviews, "polarity")
#' )
#'
#' # Validate
#' validation <- qlm_validate(coded, gold, by = "polarity")
#' print(validation)
#'
#' # Compute only specific metrics
#' qlm_validate(coded, gold, by = "polarity", measure = "f1")
#'
#' # Use micro-averaging
#' qlm_validate(coded, gold, by = "polarity", average = "micro")
#'
#' # Get per-class breakdown
#' validation_detailed <- qlm_validate(coded, gold, by = "polarity", average = "none")
#' print(validation_detailed)
#' validation_detailed$by_class$precision
#' }
#'
#' @export
qlm_validate <- function(
    x,
    gold,
    by,
    measure = c("all", "accuracy", "precision", "recall", "f1", "kappa"),
    average = c("macro", "micro", "weighted", "none"),
    level = c("nominal", "ordinal", "interval")
) {

  # Match arguments
  measure <- match.arg(measure)
  average <- match.arg(average)
  level <- match.arg(level)

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
  merged$estimate <- factor(merged$estimate, levels = all_levels)
  merged$truth <- factor(merged$truth, levels = all_levels)

  # Map average to yardstick estimator
  estimator <- switch(average,
    "macro" = "macro",
    "micro" = "micro",
    "weighted" = "macro_weighted",
    "none" = "macro"  # Use macro for global metrics when average = "none"
  )

  # Determine which metrics to compute
  compute_all <- measure == "all"
  metrics_to_compute <- if (compute_all) {
    c("accuracy", "precision", "recall", "f1", "kappa")
  } else {
    measure
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

  # Compute kappa (no estimator parameter)
  if ("kappa" %in% metrics_to_compute) {
    kap <- yardstick::kap(merged, truth = truth, estimate = estimate)
    results$kappa <- kap$.estimate
  } else {
    results$kappa <- NULL
  }

  # Compute confusion matrix (always included)
  conf_mat <- yardstick::conf_mat(merged, truth = truth, estimate = estimate)

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
    accuracy = results$accuracy,
    precision = results$precision,
    recall = results$recall,
    f1 = results$f1,
    kappa = results$kappa,
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
  cat("classes: ", length(x$classes), " | ", sep = "")
  cat("average: ", x$average, "\n\n", sep = "")

  # Print metrics
  if (x$average == "none") {
    # Global metrics
    cat("Global:\n")
    if (!is.null(x$accuracy)) {
      cat("  accuracy: ", sprintf("%.4f", x$accuracy), "\n", sep = "")
    }
    if (!is.null(x$kappa)) {
      cat("  kappa:    ", sprintf("%.4f", x$kappa), "\n", sep = "")
    }
    cat("\n")

    # Per-class metrics
    if (!is.null(x$by_class)) {
      cat("By class:\n")
      print(x$by_class, n = Inf)
    }
  } else {
    # Aggregated metrics only
    if (!is.null(x$accuracy)) {
      cat("accuracy:  ", sprintf("%.4f", x$accuracy), "\n", sep = "")
    }
    if (!is.null(x$precision)) {
      cat("precision: ", sprintf("%.4f", x$precision), "\n", sep = "")
    }
    if (!is.null(x$recall)) {
      cat("recall:    ", sprintf("%.4f", x$recall), "\n", sep = "")
    }
    if (!is.null(x$f1)) {
      cat("f1:        ", sprintf("%.4f", x$f1), "\n", sep = "")
    }
    if (!is.null(x$kappa)) {
      cat("kappa:     ", sprintf("%.4f", x$kappa), "\n", sep = "")
    }
  }

  invisible(x)
}
