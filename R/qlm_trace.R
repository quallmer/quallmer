#' Extract provenance trace from quallmer objects
#'
#' Extracts and displays the provenance chain from one or more `qlm_coded`,
#' `qlm_comparison`, or `qlm_validation` objects. When multiple objects are
#' provided, attempts to reconstruct the full lineage by matching parent-child
#' relationships. Optionally saves, exports, or generates reports in one call.
#'
#' @param ... One or more quallmer objects (`qlm_coded`, `qlm_comparison`, or
#'   `qlm_validation`). When multiple objects are provided, they will be used
#'   to reconstruct the complete provenance chain.
#' @param include_data Logical. If `TRUE`, stores the actual coded data alongside
#'   the metadata. This allows you to archive complete results. Default is `FALSE`
#'   to keep trace objects lightweight.
#' @param save Optional file path to save the trace as an RDS file. If provided,
#'   automatically calls `qlm_trace_save()`.
#' @param export Optional file path to export the trace as JSON. If provided,
#'   automatically calls `qlm_trace_export()`.
#' @param report Optional file path (`.qmd` or `.Rmd`) to generate a report.
#'   If provided, automatically calls `qlm_trace_report()`.
#' @param include_comparisons Logical. If `TRUE` and `report` is specified,
#'   include comparison metrics in the report. Default is `FALSE`.
#' @param include_validations Logical. If `TRUE` and `report` is specified,
#'   include validation metrics in the report. Default is `FALSE`.
#' @param robustness Optional. A `qlm_robustness` object to include in the report.
#'   Only used if `report` is specified.
#'
#' @return A `qlm_trace` object containing:
#'   \describe{
#'     \item{runs}{List of run information, ordered from oldest to newest}
#'     \item{complete}{Logical indicating whether all parent references were resolved}
#'   }
#'
#' @details
#' The provenance trace shows the history of coding runs, including:
#' - Run name and parent relationship
#' - Model and parameters used
#' - Timestamp
#' - Call that created the run
#'
#' When a single object is provided, only its immediate lineage (name, parent,
#' timestamp) is shown. To see the full chain, provide all ancestor objects.
#'
#' For branching workflows (e.g., when multiple coded objects are compared),
#' the trace captures all input runs as parents of the comparison.
#'
#' @examples
#' \dontrun{
#' # Single run shows immediate info
#' coded1 <- qlm_code(reviews, codebook, model = "openai/gpt-4o")
#' qlm_trace(coded1)
#'
#' # Create replication chain
#' coded2 <- qlm_replicate(coded1, model = "openai/gpt-4o-mini")
#' coded3 <- qlm_replicate(coded2, temperature = 0.7)
#'
#' # Reconstruct full chain
#' trace <- qlm_trace(coded3, coded2, coded1)
#' print(trace)
#'
#' # Convenience: save and export in one call
#' qlm_trace(coded3, coded2, coded1,
#'           save = "trace.rds",
#'           export = "trace.json")
#'
#' # Generate complete report with all metrics
#' qlm_trace(coded3, coded2, coded1,
#'           report = "trace.qmd",
#'           include_comparisons = TRUE,
#'           include_validations = TRUE)
#'
#' # Or use separate functions for more control
#' trace <- qlm_trace(coded3, coded2, coded1, include_data = TRUE)
#' qlm_trace_save(trace, "trace_complete.rds")
#' qlm_trace_export(trace, "trace.json")
#' }
#'
#' @seealso [qlm_replicate()], [qlm_code()], [qlm_compare()], [qlm_validate()],
#'   [qlm_trace_save()], [qlm_trace_export()], [qlm_trace_report()]
#' @export
qlm_trace <- function(..., include_data = FALSE, save = NULL, export = NULL,
                      report = NULL, include_comparisons = FALSE,
                      include_validations = FALSE, robustness = NULL) {
  objects <- list(...)

  if (length(objects) == 0) {
    cli::cli_abort("At least one object must be provided.")
  }

  # Extract runs from all objects
  runs <- list()
  for (i in seq_along(objects)) {
    obj <- objects[[i]]

    # Check if it's a quallmer object with run attribute
    if (!inherits(obj, c("qlm_coded", "qlm_comparison", "qlm_validation"))) {
      cli::cli_abort(c(
        "All objects must be quallmer objects.",
        "x" = "Object {i} has class {.cls {class(obj)}}.",
        "i" = "Expected {.cls qlm_coded}, {.cls qlm_comparison}, or {.cls qlm_validation}."
      ))
    }

    run <- attr(obj, "run")
    if (is.null(run)) {
      cli::cli_abort(c(
        "Object {i} does not have a {.field run} attribute.",
        "i" = "This object may have been created with an older version of quallmer."
      ))
    }

    # Store comparison/validation data if this is a comparison or validation object
    if (inherits(obj, "qlm_comparison")) {
      # Extract all measures from the comparison object
      # Different measures exist depending on the level (nominal/ordinal/interval/ratio)
      run$comparison_data <- list(
        level = obj$level,
        subjects = obj$subjects,
        raters = obj$raters,
        # Nominal measures
        alpha_nominal = obj$alpha_nominal,
        kappa = obj$kappa,
        kappa_type = obj$kappa_type,
        # Ordinal measures
        alpha_ordinal = obj$alpha_ordinal,
        kappa_weighted = obj$kappa_weighted,
        w = obj$w,
        rho = obj$rho,
        # Interval/ratio measures
        alpha_interval = obj$alpha_interval,
        icc = obj$icc,
        r = obj$r,
        # Shared across all levels
        percent_agreement = obj$percent_agreement
      )
    } else if (inherits(obj, "qlm_validation")) {
      # Extract all validation metrics across all measurement levels
      run$validation_data <- list(
        level = obj$level,
        n = obj$n,
        classes = obj$classes,
        average = obj$average,
        # Nominal metrics
        accuracy = obj$accuracy,
        precision = obj$precision,
        recall = obj$recall,
        f1 = obj$f1,
        kappa = obj$kappa,
        # Ordinal metrics
        rho = obj$rho,
        tau = obj$tau,
        # Interval metrics
        r = obj$r,
        icc = obj$icc,
        # Shared metrics (ordinal/interval)
        mae = obj$mae,
        rmse = obj$rmse
      )
    }

    # Store data if requested
    if (include_data) {
      # For qlm_coded objects, store the data frame
      if (inherits(obj, "qlm_coded")) {
        run$data <- as.data.frame(obj)
      }
      # For comparisons and validations, we already stored the relevant summary data
      # The actual underlying coded data would be in their parent runs
    }

    # Store run with its index for ordering
    run$object_index <- i
    runs[[run$name]] <- run
  }

  # Build complete chain by following parent relationships
  chain <- list()
  complete <- TRUE

  # Find all runs and their parents
  all_names <- names(runs)
  all_parents <- unique(unlist(lapply(runs, function(r) r$parent)))
  all_parents <- all_parents[!sapply(all_parents, is.null)]

  # Check if all parents are resolved
  missing_parents <- setdiff(all_parents, all_names)
  if (length(missing_parents) > 0) {
    complete <- FALSE
  }

  # Order runs by following parent chain
  # Start with runs that have no parent or parent not in set
  roots <- runs[sapply(runs, function(r) {
    is.null(r$parent) || !any(r$parent %in% all_names)
  })]

  # Build chain from roots
  visited <- character(0)
  queue <- names(roots)

  while (length(queue) > 0) {
    current <- queue[1]
    queue <- queue[-1]

    if (current %in% visited) next

    visited <- c(visited, current)
    chain[[current]] <- runs[[current]]

    # Find children
    children <- names(runs)[sapply(runs, function(r) {
      !is.null(r$parent) && current %in% r$parent
    })]

    queue <- c(queue, children)
  }

  trace <- structure(
    list(
      runs = chain,
      complete = complete,
      include_data = include_data
    ),
    class = "qlm_trace"
  )

  # Convenience wrappers: apply save/export/report if specified
  if (!is.null(save)) {
    qlm_trace_save(trace, save)
  }

  if (!is.null(export)) {
    qlm_trace_export(trace, export)
  }

  if (!is.null(report)) {
    qlm_trace_report(trace, report,
                     include_comparisons = include_comparisons,
                     include_validations = include_validations,
                     robustness = robustness)
  }

  trace
}


#' Print a quallmer trace
#'
#' @param x A qlm_trace object.
#' @param ... Additional arguments (currently unused).
#'
#' @return Invisibly returns the input object \code{x}. Called for side effects (printing to console).
#' @keywords internal
#' @export
print.qlm_trace <- function(x, ...) {
  n_runs <- length(x$runs)

  if (n_runs == 0) {
    cat("Empty trace\n")
    return(invisible(x))
  }

  # Header
  if (n_runs == 1) {
    cat("# quallmer trace")
    if (x$include_data) {
      cat(" [with data]")
    }
    cat("\n")
    run <- x$runs[[1]]
    cat("Run:     ", run$name, "\n", sep = "")
    if (!is.null(run$parent)) {
      if (length(run$parent) == 1) {
        cat("Parent:  ", run$parent, "\n", sep = "")
      } else {
        cat("Parents: ", paste(run$parent, collapse = ", "), "\n", sep = "")
      }
    }
    if (!is.null(run$metadata$timestamp)) {
      cat("Created: ", format(run$metadata$timestamp, '%Y-%m-%d %H:%M:%S'), "\n", sep = "")
    }
    if (!is.null(run$chat_args$name)) {
      cat("Model:   ", run$chat_args$name, "\n", sep = "")
    }

    # Show comparison info if available
    if (!is.null(run$comparison_data)) {
      comp <- run$comparison_data
      cat("\nComparison (", comp$level %||% "unknown", " level):\n", sep = "")
      cat("  Subjects: ", comp$subjects %||% "?", "\n", sep = "")
      cat("  Raters:   ", comp$raters %||% "?", "\n", sep = "")
    }

    # Show validation info if available
    if (!is.null(run$validation_data)) {
      val <- run$validation_data
      cat("\nValidation (", val$level %||% "unknown", " level):\n", sep = "")
      cat("  N:        ", val$n %||% "?", "\n", sep = "")
      if (!is.null(val$average)) {
        cat("  Average:  ", val$average, "\n", sep = "")
      }
    }

    cat("\n")
    if (!x$complete) {
      cat("To see full chain, provide ancestor objects.\n")
    }
  } else {
    # Plural handling
    runs_text <- if (n_runs == 1) "run" else "runs"
    cat("# quallmer trace (", n_runs, " ", runs_text, ")", sep = "")
    if (x$include_data) {
      cat(" [with data]")
    }
    cat("\n\n")

    for (i in seq_along(x$runs)) {
      run <- x$runs[[i]]

      # Format timestamp
      ts <- if (!is.null(run$metadata$timestamp)) {
        format(run$metadata$timestamp, "%Y-%m-%d %H:%M")
      } else {
        "unknown"
      }

      # Format model
      model <- if (!is.null(run$chat_args$name)) {
        run$chat_args$name
      } else {
        "unknown"
      }

      # Format parent
      parent_str <- if (!is.null(run$parent)) {
        if (length(run$parent) == 1) {
          paste0(" (parent: ", run$parent, ")")
        } else {
          paste0(" (parents: ", paste(run$parent, collapse = ", "), ")")
        }
      } else {
        " (original)"
      }

      cat(i, ". ", run$name, parent_str, "\n", sep = "")
      cat("   ", ts, " | ", model, "\n", sep = "")

      # Show codebook name if available
      if (!is.null(run$codebook$name)) {
        cat("   Codebook: ", run$codebook$name, "\n", sep = "")
      }

      # Show comparison summary if available
      if (!is.null(run$comparison_data)) {
        comp <- run$comparison_data
        cat("   Comparison: ", comp$level %||% "unknown", " level | ",
            comp$subjects %||% "?", " subjects | ",
            comp$raters %||% "?", " raters\n", sep = "")
      }

      # Show validation summary if available
      if (!is.null(run$validation_data)) {
        val <- run$validation_data
        cat("   Validation: ", val$level %||% "unknown", " level | ",
            "n=", val$n %||% "?", sep = "")
        if (!is.null(val$average)) {
          cat(" | ", val$average, " avg", sep = "")
        }
        cat("\n")
      }

      if (i < length(x$runs)) {
        cat("\n")
      }
    }

    if (!x$complete) {
      cat("\n")
      cat("! Trace is incomplete. Some parent runs are missing.\n")
    }
  }

  invisible(x)
}


#' Save trace to RDS file
#'
#' Saves a provenance trace to an RDS file for archival purposes. If the trace
#' was created with `include_data = TRUE`, the actual coded data will also be
#' saved, creating a complete archive of your analysis.
#'
#' @param trace A `qlm_trace` object from [qlm_trace()].
#' @param file Path to save the RDS file.
#'
#' @return Invisibly returns the file path.
#'
#' @examples
#' \dontrun{
#' # Save metadata only (lightweight)
#' trace <- qlm_trace(coded1, coded2, coded3)
#' qlm_trace_save(trace, "analysis_trace.rds")
#'
#' # Save complete archive with coded data
#' trace_complete <- qlm_trace(coded1, coded2, coded3, include_data = TRUE)
#' qlm_trace_save(trace_complete, "analysis_trace_complete.rds")
#' }
#'
#' @seealso [qlm_trace()]
#' @export
qlm_trace_save <- function(trace, file) {
  if (!inherits(trace, "qlm_trace")) {
    cli::cli_abort(c(
      "{.arg trace} must be a {.cls qlm_trace} object.",
      "i" = "Create one with {.fn qlm_trace}."
    ))
  }

  saveRDS(trace, file)
  cli::cli_alert_success("Trace saved to {.path {file}}")

  invisible(file)
}


#' Export trace to JSON
#'
#' Exports a provenance trace to JSON format for portability and archival.
#'
#' @param trace A `qlm_trace` object from [qlm_trace()].
#' @param file Path to save the JSON file.
#'
#' @return Invisibly returns the file path.
#'
#' @details
#' The JSON export includes:
#' - Run names and parent relationships
#' - Timestamps
#' - Model names and parameters
#' - Codebook names
#' - Call information (as text)
#'
#' Large objects like the full codebook schema and data are not included
#' to keep file sizes manageable.
#'
#' @examples
#' \dontrun{
#' trace <- qlm_trace(coded1, coded2, coded3)
#' qlm_trace_export(trace, "analysis_trace.json")
#' }
#'
#' @seealso [qlm_trace()]
#' @export
qlm_trace_export <- function(trace, file) {
  if (!inherits(trace, "qlm_trace")) {
    cli::cli_abort(c(
      "{.arg trace} must be a {.cls qlm_trace} object.",
      "i" = "Create one with {.fn qlm_trace}."
    ))
  }

  # Convert trace to JSON-friendly format
  export_data <- list(
    complete = trace$complete,
    n_runs = length(trace$runs),
    runs = lapply(trace$runs, function(run) {
      list(
        name = run$name,
        parent = run$parent,
        timestamp = if (!is.null(run$metadata$timestamp)) {
          format(run$metadata$timestamp, "%Y-%m-%d %H:%M:%S %Z")
        } else {
          NULL
        },
        model = run$chat_args$name,
        temperature = run$chat_args$temperature,
        codebook_name = run$codebook$name,
        call = deparse(run$call),
        metadata = list(
          n_units = run$metadata$n_units,
          quallmer_version = run$metadata$quallmer_version,
          ellmer_version = run$metadata$ellmer_version,
          R_version = run$metadata$R_version
        )
      )
    })
  )

  # Write JSON
  json_text <- jsonlite::toJSON(export_data, pretty = TRUE, auto_unbox = TRUE)
  writeLines(json_text, file)

  cli::cli_alert_success("Trace exported to {.path {file}}")

  invisible(file)
}


#' Generate trace report
#'
#' Generates a human-readable Quarto/RMarkdown document summarizing the
#' provenance trace, optionally including assessment metrics across runs.
#'
#' @param trace A `qlm_trace` object from [qlm_trace()].
#' @param file Path to save the report file (`.qmd` or `.Rmd`).
#' @param include_comparisons Logical. If `TRUE`, include comparison metrics
#'   in the report (if any comparisons are in the trace). Default is `FALSE`.
#' @param include_validations Logical. If `TRUE`, include validation metrics
#'   in the report (if any validations are in the trace). Default is `FALSE`.
#' @param robustness Optional. A `qlm_robustness` object from [qlm_trace_robustness()]
#'   containing downstream analysis robustness metrics to include in the report.
#'
#' @return Invisibly returns the file path.
#'
#' @details
#' Creates a formatted document showing:
#' - Trace summary and completeness
#' - Timeline of runs
#' - Model parameters and settings for each run
#' - Parent-child relationships
#' - Assessment metrics (if requested):
#'   - Inter-rater reliability comparisons
#'   - Validation results against gold standards
#'   - Downstream analysis robustness
#'
#' The generated file can be rendered to HTML, PDF, or other formats using
#' Quarto or RMarkdown.
#'
#' @examples
#' \dontrun{
#' # Basic trace report
#' trace <- qlm_trace(coded1, coded2, coded3)
#' qlm_trace_report(trace, "analysis_trace.qmd")
#'
#' # Include comparison and validation metrics
#' trace <- qlm_trace(coded1, coded2, comparison, validation)
#' qlm_trace_report(trace, "full_report.qmd",
#'                  include_comparisons = TRUE,
#'                  include_validations = TRUE)
#'
#' # Include robustness assessment
#' robustness <- qlm_trace_robustness(coded1, coded2, coded3,
#'                                    reference = "run1",
#'                                    analysis_fn = my_analysis)
#' qlm_trace_report(trace, "full_report.qmd", robustness = robustness)
#'
#' # Render to HTML
#' quarto::quarto_render("full_report.qmd")
#' }
#'
#' @seealso [qlm_trace()], [qlm_trace_robustness()]
#' @export
qlm_trace_report <- function(trace, file, include_comparisons = FALSE,
                              include_validations = FALSE, robustness = NULL) {
  if (!inherits(trace, "qlm_trace")) {
    cli::cli_abort(c(
      "{.arg trace} must be a {.cls qlm_trace} object.",
      "i" = "Create one with {.fn qlm_trace}."
    ))
  }

  # Validate robustness if provided
  if (!is.null(robustness) && !inherits(robustness, "qlm_robustness")) {
    cli::cli_abort(c(
      "{.arg robustness} must be a {.cls qlm_robustness} object.",
      "i" = "Create one with {.fn qlm_trace_robustness}."
    ))
  }

  # Determine format from extension
  ext <- tools::file_ext(file)
  if (!ext %in% c("qmd", "Rmd")) {
    cli::cli_abort(c(
      "File must have {.file .qmd} or {.file .Rmd} extension.",
      "x" = "Got {.file .{ext}}"
    ))
  }

  # Generate report content
  lines <- character()

  # YAML header
  lines <- c(lines, "---")
  lines <- c(lines, "title: \"quallmer trace\"")
  lines <- c(lines, paste0("date: \"", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\""))
  if (ext == "qmd") {
    lines <- c(lines, "format: html")
  } else {
    lines <- c(lines, "output: html_document")
  }
  lines <- c(lines, "---")
  lines <- c(lines, "")

  # Summary
  lines <- c(lines, "## Trace Summary")
  lines <- c(lines, "")
  lines <- c(lines, paste("- **Number of runs:**", length(trace$runs)))
  lines <- c(lines, paste("- **Complete:**", if (trace$complete) "Yes" else "No (missing parent runs)"))
  lines <- c(lines, "")

  # Timeline
  lines <- c(lines, "## Timeline")
  lines <- c(lines, "")

  for (i in seq_along(trace$runs)) {
    run <- trace$runs[[i]]

    lines <- c(lines, paste0("### ", i, ". ", run$name))
    lines <- c(lines, "")

    if (!is.null(run$parent)) {
      lines <- c(lines, paste("**Parent run:**", run$parent))
    } else {
      lines <- c(lines, "**Parent run:** None (original)")
    }

    if (!is.null(run$metadata$timestamp)) {
      lines <- c(lines, paste("**Timestamp:**", format(run$metadata$timestamp, "%Y-%m-%d %H:%M:%S")))
    }

    if (!is.null(run$chat_args$name)) {
      lines <- c(lines, paste("**Model:**", run$chat_args$name))
    }

    if (!is.null(run$chat_args$temperature)) {
      lines <- c(lines, paste("**Temperature:**", run$chat_args$temperature))
    }

    if (!is.null(run$codebook$name)) {
      lines <- c(lines, paste("**Codebook:**", run$codebook$name))
    }

    if (!is.null(run$metadata$n_units)) {
      lines <- c(lines, paste("**Units coded:**", run$metadata$n_units))
    }

    lines <- c(lines, "")
    lines <- c(lines, "**Call:**")
    lines <- c(lines, "```r")
    lines <- c(lines, deparse(run$call))
    lines <- c(lines, "```")
    lines <- c(lines, "")
  }

  # Extract comparisons and validations from trace if requested
  comparisons_list <- list()
  validations_list <- list()

  if (include_comparisons || include_validations) {
    for (run_name in names(trace$runs)) {
      run <- trace$runs[[run_name]]

      # Check if this run is from a comparison object
      if (include_comparisons && !is.null(run$comparison_data)) {
        comp_data <- run$comparison_data
        parents_str <- if (is.null(run$parent) || length(run$parent) == 0) {
          ""
        } else {
          paste(run$parent, collapse = ", ")
        }

        # Collect relevant measures based on level
        measures <- list()
        if (!is.null(comp_data$level)) {
          if (comp_data$level == "nominal") {
            measures$alpha_nominal <- comp_data$alpha_nominal
            measures$kappa <- comp_data$kappa
            measures$kappa_type <- comp_data$kappa_type
          } else if (comp_data$level == "ordinal") {
            measures$alpha_ordinal <- comp_data$alpha_ordinal
            measures$kappa_weighted <- comp_data$kappa_weighted
            measures$w <- comp_data$w
            measures$rho <- comp_data$rho
          } else if (comp_data$level %in% c("interval", "ratio")) {
            measures$alpha_interval <- comp_data$alpha_interval
            measures$icc <- comp_data$icc
            measures$r <- comp_data$r
          }
          measures$percent_agreement <- comp_data$percent_agreement
        }

        comparisons_list[[length(comparisons_list) + 1]] <- list(
          run = run$name,
          parents = parents_str,
          level = comp_data$level %||% "unknown",
          subjects = comp_data$subjects %||% NA_integer_,
          raters = comp_data$raters %||% NA_integer_,
          measures = measures
        )
      }

      # Check if this run is from a validation object
      if (include_validations && !is.null(run$validation_data)) {
        val_data <- run$validation_data
        parents_str <- if (is.null(run$parent) || length(run$parent) == 0) {
          ""
        } else {
          paste(run$parent, collapse = ", ")
        }

        # Collect relevant metrics based on level
        metrics <- list()
        if (!is.null(val_data$level)) {
          if (val_data$level == "nominal") {
            metrics$accuracy <- val_data$accuracy
            metrics$precision <- val_data$precision
            metrics$recall <- val_data$recall
            metrics$f1 <- val_data$f1
            metrics$kappa <- val_data$kappa
          } else if (val_data$level == "ordinal") {
            metrics$rho <- val_data$rho
            metrics$tau <- val_data$tau
            metrics$mae <- val_data$mae
          } else if (val_data$level == "interval") {
            metrics$r <- val_data$r
            metrics$icc <- val_data$icc
            metrics$mae <- val_data$mae
            metrics$rmse <- val_data$rmse
          }
        }

        validations_list[[length(validations_list) + 1]] <- list(
          run = run$name,
          parents = parents_str,
          level = val_data$level %||% "unknown",
          n = val_data$n %||% NA_integer_,
          average = val_data$average,
          metrics = metrics
        )
      }
    }
  }

  # Assessment Metrics
  has_metrics <- length(comparisons_list) > 0 || length(validations_list) > 0 || !is.null(robustness)

  if (has_metrics) {
    lines <- c(lines, "## Assessment Metrics")
    lines <- c(lines, "")

    # Comparisons
    if (length(comparisons_list) > 0) {
      lines <- c(lines, "### Inter-rater Reliability Comparisons")
      lines <- c(lines, "")
      lines <- c(lines, "The following comparisons were performed to assess agreement between runs:")
      lines <- c(lines, "")

      for (comp in comparisons_list) {
        lines <- c(lines, sprintf("#### %s", comp$run))
        lines <- c(lines, "")
        lines <- c(lines, paste("- **Compared runs:**", comp$parents))
        lines <- c(lines, paste("- **Level:**", comp$level))
        lines <- c(lines, paste("- **Subjects:**", comp$subjects))
        lines <- c(lines, paste("- **Raters:**", comp$raters))
        lines <- c(lines, "")

        # Display measures
        if (length(comp$measures) > 0) {
          lines <- c(lines, "**Measures:**")
          lines <- c(lines, "")
          for (measure_name in names(comp$measures)) {
            measure_value <- comp$measures[[measure_name]]
            if (!is.null(measure_value) && !is.na(measure_value)) {
              # Format measure name nicely
              display_name <- switch(measure_name,
                "alpha_nominal" = "Krippendorff's alpha (nominal)",
                "alpha_ordinal" = "Krippendorff's alpha (ordinal)",
                "alpha_interval" = "Krippendorff's alpha (interval)",
                "kappa" = paste0(comp$measures$kappa_type %||% "Cohen's", " kappa"),
                "kappa_weighted" = "Weighted kappa",
                "kappa_type" = NULL,  # Skip this, shown with kappa
                "w" = "Kendall's W",
                "rho" = "Spearman's rho",
                "icc" = "ICC",
                "r" = "Pearson's r",
                "percent_agreement" = "Percent agreement",
                measure_name
              )
              if (!is.null(display_name)) {
                if (is.numeric(measure_value)) {
                  lines <- c(lines, sprintf("- %s: %.4f", display_name, measure_value))
                } else {
                  lines <- c(lines, sprintf("- %s: %s", display_name, measure_value))
                }
              }
            }
          }
          lines <- c(lines, "")
        }
      }
    }

    # Validations
    if (length(validations_list) > 0) {
      lines <- c(lines, "### Validation Against Gold Standard")
      lines <- c(lines, "")
      lines <- c(lines, "The following runs were validated against gold standard annotations:")
      lines <- c(lines, "")

      for (val in validations_list) {
        lines <- c(lines, sprintf("#### %s", val$run))
        lines <- c(lines, "")
        lines <- c(lines, paste("- **Compared runs:**", val$parents))
        lines <- c(lines, paste("- **Level:**", val$level))
        lines <- c(lines, paste("- **N:**", val$n))
        if (!is.null(val$average)) {
          lines <- c(lines, paste("- **Average:**", val$average))
        }
        lines <- c(lines, "")

        # Display metrics
        if (length(val$metrics) > 0) {
          lines <- c(lines, "**Metrics:**")
          lines <- c(lines, "")
          for (metric_name in names(val$metrics)) {
            metric_value <- val$metrics[[metric_name]]
            if (!is.null(metric_value) && !is.na(metric_value)) {
              # Format metric name nicely
              display_name <- switch(metric_name,
                "accuracy" = "Accuracy",
                "precision" = "Precision",
                "recall" = "Recall",
                "f1" = "F1-score",
                "kappa" = "Cohen's kappa",
                "rho" = "Spearman's rho",
                "tau" = "Kendall's tau",
                "r" = "Pearson's r",
                "icc" = "ICC",
                "mae" = "MAE",
                "rmse" = "RMSE",
                metric_name
              )
              lines <- c(lines, sprintf("- %s: %.4f", display_name, metric_value))
            }
          }
          lines <- c(lines, "")
        }
      }
    }

    # Robustness
    if (!is.null(robustness) && nrow(robustness) > 0) {
      ref <- attr(robustness, "reference")
      lines <- c(lines, "### Downstream Analysis Robustness")
      lines <- c(lines, "")
      lines <- c(lines, paste("Reference run:", ref))
      lines <- c(lines, "")
      lines <- c(lines, "The following table shows how downstream analysis results differ from the reference run:")
      lines <- c(lines, "")

      # Create markdown table
      lines <- c(lines, "| Run | Statistic | Value | Reference Value | Absolute Difference | Percent Change |")
      lines <- c(lines, "|-----|-----------|-------|-----------------|---------------------|----------------|")

      for (i in seq_len(nrow(robustness))) {
        pct_str <- if (is.na(robustness$pct_diff[i])) "NA" else sprintf("%.2f%%", robustness$pct_diff[i])
        lines <- c(lines, sprintf("| %s | %s | %.4f | %.4f | %.4f | %s |",
                                  robustness$run[i],
                                  robustness$statistic[i],
                                  robustness$value[i],
                                  robustness$reference_value[i],
                                  robustness$abs_diff[i],
                                  pct_str))
      }
      lines <- c(lines, "")
      lines <- c(lines, "**Note:** Smaller differences indicate more robust findings. Percent change is positive for increases and negative for decreases.")
      lines <- c(lines, "")
    }
  }

  # Metadata
  lines <- c(lines, "## System Information")
  lines <- c(lines, "")

  # Get from most recent run
  if (length(trace$runs) > 0) {
    last_run <- trace$runs[[length(trace$runs)]]
    if (!is.null(last_run$metadata)) {
      lines <- c(lines, paste("- **quallmer version:**", last_run$metadata$quallmer_version %||% "unknown"))
      lines <- c(lines, paste("- **ellmer version:**", last_run$metadata$ellmer_version %||% "unknown"))
      lines <- c(lines, paste("- **R version:**", last_run$metadata$R_version %||% "unknown"))
    }
  }

  # Write file
  writeLines(lines, file)

  cli::cli_alert_success("Trace report saved to {.path {file}}")
  cli::cli_alert_info("Render with {.code quarto::quarto_render(\"{file}\")} or {.code rmarkdown::render(\"{file}\")}")

  invisible(file)
}


#' Compute robustness scale showing downstream analysis changes
#'
#' Assesses how much downstream analysis results vary across different coding
#' runs. This helps determine whether substantive conclusions are robust to
#' different models, parameters, or codebook variations.
#'
#' @param ... One or more `qlm_coded` objects. The objects should be the actual
#'   coded results (not just the trace). Must include the reference run.
#' @param reference Character string naming the reference run to compare against.
#'   This should match the `name` attribute of one of the provided objects.
#' @param analysis_fn A function that takes a `qlm_coded` object and returns
#'   a named list or data frame of analysis results. The function will be applied
#'   to each coded object to compute downstream statistics.
#'
#' @return A data frame with robustness metrics:
#'   \describe{
#'     \item{run}{Name of the run}
#'     \item{statistic}{Name of the analysis statistic}
#'     \item{value}{Value from this run}
#'     \item{reference_value}{Value from reference run}
#'     \item{abs_diff}{Absolute difference from reference}
#'     \item{pct_diff}{Percent difference from reference (NULL if reference is 0)}
#'   }
#'
#' @details
#' Robustness is assessed by:
#' 1. Applying your analysis function to each coded object
#' 2. Comparing the resulting statistics to the reference run
#' 3. Computing absolute and percentage differences
#'
#' Smaller differences indicate more robust findings that don't depend heavily
#' on model choice. Large differences suggest your conclusions may be sensitive
#' to which model or settings you use.
#'
#' The `analysis_fn` should return a named list or data frame where each element
#' is a single numeric value representing a statistic of interest (e.g., mean,
#' proportion, correlation coefficient, regression coefficient).
#'
#' @examples
#' \dontrun{
#' # Create multiple coded versions
#' coded1 <- qlm_code(texts, codebook, model = "openai/gpt-4o",
#'                    name = "gpt4o_run")
#' coded2 <- qlm_replicate(coded1, model = "openai/gpt-4o-mini",
#'                         name = "mini_run")
#' coded3 <- qlm_replicate(coded1, temperature = 0.7,
#'                         name = "temp07_run")
#'
#' # Define downstream analysis function
#' my_analysis <- function(coded) {
#'   list(
#'     mean_score = mean(coded$score, na.rm = TRUE),
#'     prop_positive = mean(coded$sentiment == "positive", na.rm = TRUE),
#'     sd_score = sd(coded$score, na.rm = TRUE)
#'   )
#' }
#'
#' # Compute robustness
#' robustness <- qlm_trace_robustness(coded1, coded2, coded3,
#'                                    reference = "gpt4o_run",
#'                                    analysis_fn = my_analysis)
#' print(robustness)
#' }
#'
#' @seealso [qlm_trace()], [qlm_compare()]
#' @export
qlm_trace_robustness <- function(..., reference, analysis_fn) {
  # Collect objects
  objects <- list(...)

  if (length(objects) < 2) {
    cli::cli_abort(c(
      "At least two {.cls qlm_coded} objects are required.",
      "i" = "Provide the reference run and at least one comparison run."
    ))
  }

  # Validate all are qlm_coded
  for (i in seq_along(objects)) {
    if (!inherits(objects[[i]], "qlm_coded")) {
      cli::cli_abort(c(
        "All objects must be {.cls qlm_coded} objects.",
        "x" = "Object {i} has class {.cls {class(objects[[i]])}}."
      ))
    }
  }

  # Validate analysis_fn is a function
  if (!is.function(analysis_fn)) {
    cli::cli_abort(c(
      "{.arg analysis_fn} must be a function.",
      "i" = "Provide a function that takes a coded object and returns analysis results."
    ))
  }

  # Extract run names
  run_names <- sapply(objects, function(obj) {
    attr(obj, "run")$name
  })

  # Validate reference exists
  if (!reference %in% run_names) {
    cli::cli_abort(c(
      "Reference run {.val {reference}} not found.",
      "i" = "Available runs: {.val {run_names}}"
    ))
  }

  # Get reference object and compute reference analysis
  ref_idx <- which(run_names == reference)
  ref_obj <- objects[[ref_idx]]

  ref_results <- tryCatch(
    analysis_fn(ref_obj),
    error = function(e) {
      cli::cli_abort(c(
        "Error running {.arg analysis_fn} on reference run:",
        "x" = conditionMessage(e)
      ))
    }
  )

  # Convert to named list if data frame
  if (is.data.frame(ref_results)) {
    ref_results <- as.list(ref_results[1, , drop = FALSE])
  }

  # Validate analysis results
  if (!is.list(ref_results) || is.null(names(ref_results))) {
    cli::cli_abort(c(
      "{.arg analysis_fn} must return a named list or data frame.",
      "i" = "Example: {.code list(mean_score = 3.5, prop_positive = 0.7)}"
    ))
  }

  # Check all values are numeric
  if (!all(sapply(ref_results, function(x) is.numeric(x) && length(x) == 1))) {
    cli::cli_abort(c(
      "All values in {.arg analysis_fn} output must be single numeric values.",
      "i" = "Each statistic should be a single number."
    ))
  }

  # Compute analysis for all runs
  results <- list()

  for (i in seq_along(objects)) {
    obj <- objects[[i]]
    run_name <- run_names[i]

    # Run analysis
    run_results <- tryCatch(
      analysis_fn(obj),
      error = function(e) {
        cli::cli_warn(c(
          "Error running {.arg analysis_fn} on run {.val {run_name}}:",
          "x" = conditionMessage(e),
          "i" = "This run will be skipped."
        ))
        return(NULL)
      }
    )

    if (is.null(run_results)) next

    # Convert to named list if data frame
    if (is.data.frame(run_results)) {
      run_results <- as.list(run_results[1, , drop = FALSE])
    }

    # Compare to reference
    for (stat_name in names(ref_results)) {
      if (!stat_name %in% names(run_results)) {
        cli::cli_warn("Statistic {.val {stat_name}} not found in run {.val {run_name}}")
        next
      }

      ref_val <- ref_results[[stat_name]]
      run_val <- run_results[[stat_name]]

      abs_diff <- abs(run_val - ref_val)
      pct_diff <- if (ref_val == 0) {
        NA_real_
      } else {
        100 * (run_val - ref_val) / ref_val
      }

      results[[length(results) + 1]] <- data.frame(
        run = run_name,
        statistic = stat_name,
        value = run_val,
        reference_value = ref_val,
        abs_diff = abs_diff,
        pct_diff = pct_diff,
        stringsAsFactors = FALSE
      )
    }
  }

  # Combine results
  if (length(results) == 0) {
    cli::cli_abort("No valid analysis results were produced.")
  }

  result_df <- do.call(rbind, results)

  structure(
    result_df,
    class = c("qlm_robustness", "data.frame"),
    reference = reference
  )
}


#' Print robustness results
#'
#' @param x A qlm_robustness object.
#' @param ... Additional arguments (currently unused).
#'
#' @return Invisibly returns the input object \code{x}. Called for side effects (printing to console).
#' @keywords internal
#' @export
print.qlm_robustness <- function(x, ...) {
  if (nrow(x) == 0) {
    cat("Empty robustness scale\n")
    return(invisible(x))
  }

  ref <- attr(x, "reference")
  cat("# Downstream Analysis Robustness\n")
  cat("Reference run: ", ref, "\n\n", sep = "")

  # Print as data frame
  print(as.data.frame(x), row.names = FALSE, digits = 4)

  cat("\n")
  cat("abs_diff: Absolute difference from reference\n")
  cat("pct_diff: Percent change from reference (positive = increase)\n")
  cat("\nSmaller differences indicate more robust findings.\n")

  invisible(x)
}


