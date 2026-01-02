#' Extract provenance trail from quallmer objects
#'
#' Extracts and displays the provenance chain from one or more `qlm_coded`,
#' `qlm_comparison`, or `qlm_validation` objects. When multiple objects are
#' provided, attempts to reconstruct the full lineage by matching parent-child
#' relationships.
#'
#' @param ... One or more quallmer objects (`qlm_coded`, `qlm_comparison`, or
#'   `qlm_validation`). When multiple objects are provided, they will be used
#'   to reconstruct the complete provenance chain.
#'
#' @return A `qlm_trail` object containing:
#'   \describe{
#'     \item{runs}{List of run information, ordered from oldest to newest}
#'     \item{complete}{Logical indicating whether all parent references were resolved}
#'   }
#'
#' @details
#' The provenance trail shows the history of coding runs, including:
#' - Run name and parent relationship
#' - Model and parameters used
#' - Timestamp
#' - Call that created the run
#'
#' When a single object is provided, only its immediate lineage (name, parent,
#' timestamp) is shown. To see the full chain, provide all ancestor objects.
#'
#' For branching workflows (e.g., when multiple coded objects are compared),
#' the trail captures all input runs as parents of the comparison.
#'
#' @examples
#' \dontrun{
#' # Single run shows immediate info
#' coded1 <- qlm_code(reviews, codebook, model = "openai/gpt-4o")
#' qlm_trail(coded1)
#'
#' # Create replication chain
#' coded2 <- qlm_replicate(coded1, model = "openai/gpt-4o-mini")
#' coded3 <- qlm_replicate(coded2, temperature = 0.7)
#'
#' # Reconstruct full chain
#' trail <- qlm_trail(coded3, coded2, coded1)
#' print(trail)
#'
#' # Save for archival
#' qlm_trail_save(trail, "analysis_trail.rds")
#'
#' # Export to JSON
#' qlm_trail_export(trail, "analysis_trail.json")
#' }
#'
#' @seealso [qlm_replicate()], [qlm_code()], [qlm_compare()], [qlm_validate()]
#' @export
qlm_trail <- function(...) {
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

  structure(
    list(
      runs = chain,
      complete = complete
    ),
    class = "qlm_trail"
  )
}


#' Print a quallmer trail
#'
#' @param x A qlm_trail object.
#' @param ... Additional arguments (currently unused).
#'
#' @return Invisibly returns the input object \code{x}. Called for side effects (printing to console).
#' @export
print.qlm_trail <- function(x, ...) {
  n_runs <- length(x$runs)

  if (n_runs == 0) {
    cat("Empty trail\n")
    return(invisible(x))
  }

  # Header
  if (n_runs == 1) {
    cat("# quallmer trail\n")
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

    cat("\n")
    if (!x$complete) {
      cat("To see full chain, provide ancestor objects.\n")
    }
  } else {
    # Plural handling
    runs_text <- if (n_runs == 1) "run" else "runs"
    cat("# quallmer trail (", n_runs, " ", runs_text, ")\n\n", sep = "")

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

      if (i < length(x$runs)) {
        cat("\n")
      }
    }

    if (!x$complete) {
      cat("\n")
      cat("! Trail is incomplete. Some parent runs are missing.\n")
    }
  }

  invisible(x)
}


#' Save trail to RDS file
#'
#' Saves a provenance trail to an RDS file for archival purposes.
#'
#' @param trail A `qlm_trail` object from [qlm_trail()].
#' @param file Path to save the RDS file.
#'
#' @return Invisibly returns the file path.
#'
#' @examples
#' \dontrun{
#' trail <- qlm_trail(coded1, coded2, coded3)
#' qlm_trail_save(trail, "analysis_trail.rds")
#' }
#'
#' @seealso [qlm_trail()]
#' @export
qlm_trail_save <- function(trail, file) {
  if (!inherits(trail, "qlm_trail")) {
    cli::cli_abort(c(
      "{.arg trail} must be a {.cls qlm_trail} object.",
      "i" = "Create one with {.fn qlm_trail}."
    ))
  }

  saveRDS(trail, file)
  cli::cli_alert_success("Trail saved to {.path {file}}")

  invisible(file)
}


#' Export trail to JSON
#'
#' Exports a provenance trail to JSON format for portability and archival.
#'
#' @param trail A `qlm_trail` object from [qlm_trail()].
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
#' trail <- qlm_trail(coded1, coded2, coded3)
#' qlm_trail_export(trail, "analysis_trail.json")
#' }
#'
#' @seealso [qlm_trail()]
#' @export
qlm_trail_export <- function(trail, file) {
  if (!inherits(trail, "qlm_trail")) {
    cli::cli_abort(c(
      "{.arg trail} must be a {.cls qlm_trail} object.",
      "i" = "Create one with {.fn qlm_trail}."
    ))
  }

  # Convert trail to JSON-friendly format
  export_data <- list(
    complete = trail$complete,
    n_runs = length(trail$runs),
    runs = lapply(trail$runs, function(run) {
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

  cli::cli_alert_success("Trail exported to {.path {file}}")

  invisible(file)
}


#' Generate trail report
#'
#' Generates a human-readable Quarto/RMarkdown document summarizing the
#' provenance trail, optionally including assessment metrics across runs.
#'
#' @param trail A `qlm_trail` object from [qlm_trail()].
#' @param file Path to save the report file (`.qmd` or `.Rmd`).
#' @param analyses Optional. A `qlm_trail_analyses` object from [qlm_trail_analyses()]
#'   containing comparison and validation metrics to include in the report.
#' @param robustness Optional. A `qlm_robustness` object from [qlm_trail_robustness()]
#'   containing downstream analysis robustness metrics to include in the report.
#'
#' @return Invisibly returns the file path.
#'
#' @details
#' Creates a formatted document showing:
#' - Trail summary and completeness
#' - Timeline of runs
#' - Model parameters and settings for each run
#' - Parent-child relationships
#' - Assessment metrics (if provided):
#'   - Inter-rater reliability comparisons
#'   - Validation results against gold standards
#'   - Downstream analysis robustness
#'
#' The generated file can be rendered to HTML, PDF, or other formats using
#' Quarto or RMarkdown.
#'
#' @examples
#' \dontrun{
#' # Basic trail report
#' trail <- qlm_trail(coded1, coded2, coded3)
#' qlm_trail_report(trail, "analysis_trail.qmd")
#'
#' # Include assessment metrics
#' analyses <- qlm_trail_analyses(coded1, coded2, comparison)
#' robustness <- qlm_trail_robustness(coded1, coded2, coded3,
#'                                    reference = "run1",
#'                                    analysis_fn = my_analysis)
#' qlm_trail_report(trail, "full_report.qmd",
#'                  analyses = analyses,
#'                  robustness = robustness)
#'
#' # Render to HTML
#' quarto::quarto_render("full_report.qmd")
#' }
#'
#' @seealso [qlm_trail()]
#' @export
qlm_trail_report <- function(trail, file, analyses = NULL, robustness = NULL) {
  if (!inherits(trail, "qlm_trail")) {
    cli::cli_abort(c(
      "{.arg trail} must be a {.cls qlm_trail} object.",
      "i" = "Create one with {.fn qlm_trail}."
    ))
  }

  # Validate analyses if provided
  if (!is.null(analyses) && !inherits(analyses, "qlm_trail_analyses")) {
    cli::cli_abort(c(
      "{.arg analyses} must be a {.cls qlm_trail_analyses} object.",
      "i" = "Create one with {.fn qlm_trail_analyses}."
    ))
  }

  # Validate robustness if provided
  if (!is.null(robustness) && !inherits(robustness, "qlm_robustness")) {
    cli::cli_abort(c(
      "{.arg robustness} must be a {.cls qlm_robustness} object.",
      "i" = "Create one with {.fn qlm_trail_robustness}."
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
  lines <- c(lines, "title: \"quallmer trail\"")
  lines <- c(lines, paste0("date: \"", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\""))
  if (ext == "qmd") {
    lines <- c(lines, "format: html")
  } else {
    lines <- c(lines, "output: html_document")
  }
  lines <- c(lines, "---")
  lines <- c(lines, "")

  # Summary
  lines <- c(lines, "## Trail Summary")
  lines <- c(lines, "")
  lines <- c(lines, paste("- **Number of runs:**", length(trail$runs)))
  lines <- c(lines, paste("- **Complete:**", if (trail$complete) "Yes" else "No (missing parent runs)"))
  lines <- c(lines, "")

  # Timeline
  lines <- c(lines, "## Timeline")
  lines <- c(lines, "")

  for (i in seq_along(trail$runs)) {
    run <- trail$runs[[i]]

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

  # Assessment Metrics
  if (!is.null(analyses) || !is.null(robustness)) {
    lines <- c(lines, "## Assessment Metrics")
    lines <- c(lines, "")

    # Comparisons
    if (!is.null(analyses) && !is.null(analyses$comparisons) && nrow(analyses$comparisons) > 0) {
      lines <- c(lines, "### Inter-rater Reliability Comparisons")
      lines <- c(lines, "")
      lines <- c(lines, "The following comparisons were performed to assess agreement between runs:")
      lines <- c(lines, "")

      # Create markdown table
      comp <- analyses$comparisons
      lines <- c(lines, "| Run | Compared Runs | Measure | Value | Subjects | Raters |")
      lines <- c(lines, "|-----|---------------|---------|-------|----------|--------|")

      for (i in seq_len(nrow(comp))) {
        lines <- c(lines, sprintf("| %s | %s | %s | %.4f | %d | %d |",
                                  comp$run[i],
                                  comp$parents[i],
                                  comp$measure[i],
                                  comp$value[i],
                                  comp$subjects[i],
                                  comp$raters[i]))
      }
      lines <- c(lines, "")
    }

    # Validations
    if (!is.null(analyses) && !is.null(analyses$validations) && nrow(analyses$validations) > 0) {
      lines <- c(lines, "### Validation Against Gold Standard")
      lines <- c(lines, "")
      lines <- c(lines, "The following runs were validated against gold standard annotations:")
      lines <- c(lines, "")

      # Create markdown table
      val <- analyses$validations
      lines <- c(lines, "| Run | Compared Runs | Accuracy | Precision | Recall | F1 | Kappa |")
      lines <- c(lines, "|-----|---------------|----------|-----------|--------|-----|-------|")

      for (i in seq_len(nrow(val))) {
        lines <- c(lines, sprintf("| %s | %s | %.4f | %.4f | %.4f | %.4f | %.4f |",
                                  val$run[i],
                                  val$parents[i],
                                  val$accuracy[i],
                                  val$precision[i],
                                  val$recall[i],
                                  val$f1[i],
                                  val$kappa[i]))
      }
      lines <- c(lines, "")
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
  if (length(trail$runs) > 0) {
    last_run <- trail$runs[[length(trail$runs)]]
    if (!is.null(last_run$metadata)) {
      lines <- c(lines, paste("- **quallmer version:**", last_run$metadata$quallmer_version %||% "unknown"))
      lines <- c(lines, paste("- **ellmer version:**", last_run$metadata$ellmer_version %||% "unknown"))
      lines <- c(lines, paste("- **R version:**", last_run$metadata$R_version %||% "unknown"))
    }
  }

  # Write file
  writeLines(lines, file)

  cli::cli_alert_success("Trail report saved to {.path {file}}")
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
#'   coded results (not just the trail). Must include the reference run.
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
#' robustness <- qlm_trail_robustness(coded1, coded2, coded3,
#'                                    reference = "gpt4o_run",
#'                                    analysis_fn = my_analysis)
#' print(robustness)
#' }
#'
#' @seealso [qlm_trail()], [qlm_compare()]
#' @export
qlm_trail_robustness <- function(..., reference, analysis_fn) {
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


#' Extract comparisons and validations from trail
#'
#' Retrieves all comparison and validation results from a set of quallmer objects,
#' showing how different runs were compared or validated.
#'
#' @param ... One or more quallmer objects (`qlm_coded`, `qlm_comparison`,
#'   `qlm_validation`). These are the objects that were part of your analysis
#'   workflow.
#'
#' @return A list with two elements:
#'   \describe{
#'     \item{comparisons}{Data frame of comparison results with columns: run,
#'       parents (comma-separated), measure, value, subjects, raters}
#'     \item{validations}{Data frame of validation results with columns: run,
#'       parents (comma-separated), accuracy, precision, recall, f1, kappa}
#'   }
#'
#' @details
#' This function helps you see all the reliability and validity assessments
#' that were performed on your coded data. It extracts the key metrics from
#' comparison and validation objects and presents them in a summary format.
#'
#' Use this to quickly review:
#' - Inter-rater reliability metrics across different model combinations
#' - Validation performance against gold standards
#' - Which runs were compared or validated together
#'
#' @examples
#' \dontrun{
#' # Create coded versions
#' coded1 <- qlm_code(texts, codebook, model = "openai/gpt-4o", name = "run1")
#' coded2 <- qlm_replicate(coded1, model = "openai/gpt-4o-mini", name = "run2")
#'
#' # Compare them
#' comparison <- qlm_compare(coded1, coded2, by = "sentiment")
#'
#' # Validate against gold standard
#' validation <- qlm_validate(coded1, gold = my_gold, by = "sentiment")
#'
#' # Extract all comparisons and validations
#' results <- qlm_trail_analyses(coded1, coded2, comparison, validation)
#' print(results$comparisons)
#' print(results$validations)
#' }
#'
#' @seealso [qlm_trail()], [qlm_compare()], [qlm_validate()]
#' @export
qlm_trail_analyses <- function(...) {
  objects <- list(...)

  if (length(objects) == 0) {
    cli::cli_abort("At least one object must be provided.")
  }

  # Extract comparisons and validations
  comparisons <- list()
  validations <- list()

  for (obj in objects) {
    if (inherits(obj, "qlm_comparison")) {
      run <- attr(obj, "run")
      comparisons[[length(comparisons) + 1]] <- data.frame(
        run = run$name %||% "unknown",
        parents = paste(run$parent %||% character(0), collapse = ", "),
        measure = obj$measure,
        value = obj$value,
        subjects = obj$subjects,
        raters = obj$raters,
        stringsAsFactors = FALSE
      )
    } else if (inherits(obj, "qlm_validation")) {
      run <- attr(obj, "run")
      validations[[length(validations) + 1]] <- data.frame(
        run = run$name %||% "unknown",
        parents = paste(run$parent %||% character(0), collapse = ", "),
        accuracy = obj$accuracy %||% NA_real_,
        precision = obj$precision %||% NA_real_,
        recall = obj$recall %||% NA_real_,
        f1 = obj$f1 %||% NA_real_,
        kappa = obj$kappa %||% NA_real_,
        stringsAsFactors = FALSE
      )
    }
  }

  # Combine into data frames
  comparisons_df <- if (length(comparisons) > 0) {
    do.call(rbind, comparisons)
  } else {
    data.frame(
      run = character(0),
      parents = character(0),
      measure = character(0),
      value = numeric(0),
      subjects = integer(0),
      raters = integer(0)
    )
  }

  validations_df <- if (length(validations) > 0) {
    do.call(rbind, validations)
  } else {
    data.frame(
      run = character(0),
      parents = character(0),
      accuracy = numeric(0),
      precision = numeric(0),
      recall = numeric(0),
      f1 = numeric(0),
      kappa = numeric(0)
    )
  }

  structure(
    list(
      comparisons = comparisons_df,
      validations = validations_df
    ),
    class = "qlm_trail_analyses"
  )
}


#' Print trail analyses
#'
#' @param x A qlm_trail_analyses object.
#' @param ... Additional arguments (currently unused).
#'
#' @return Invisibly returns the input object \code{x}. Called for side effects (printing to console).
#' @export
print.qlm_trail_analyses <- function(x, ...) {
  cat("# Trail Analyses Summary\n\n")

  # Print comparisons
  if (nrow(x$comparisons) > 0) {
    cat("## Comparisons (", nrow(x$comparisons), ")\n\n", sep = "")
    print(x$comparisons, row.names = FALSE)
    cat("\n")
  } else {
    cat("## Comparisons\nNo comparisons found\n\n")
  }

  # Print validations
  if (nrow(x$validations) > 0) {
    cat("## Validations (", nrow(x$validations), ")\n\n", sep = "")
    print(x$validations, row.names = FALSE, digits = 3)
    cat("\n")
  } else {
    cat("## Validations\nNo validations found\n\n")
  }

  invisible(x)
}
