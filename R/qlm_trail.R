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
#' provenance trail.
#'
#' @param trail A `qlm_trail` object from [qlm_trail()].
#' @param file Path to save the report file (`.qmd` or `.Rmd`).
#'
#' @return Invisibly returns the file path.
#'
#' @details
#' Creates a formatted document showing:
#' - Trail summary and completeness
#' - Timeline of runs
#' - Model parameters and settings for each run
#' - Parent-child relationships
#'
#' The generated file can be rendered to HTML, PDF, or other formats using
#' Quarto or RMarkdown.
#'
#' @examples
#' \dontrun{
#' trail <- qlm_trail(coded1, coded2, coded3)
#' qlm_trail_report(trail, "analysis_trail.qmd")
#'
#' # Render to HTML
#' quarto::quarto_render("analysis_trail.qmd")
#' }
#'
#' @seealso [qlm_trail()]
#' @export
qlm_trail_report <- function(trail, file) {
  if (!inherits(trail, "qlm_trail")) {
    cli::cli_abort(c(
      "{.arg trail} must be a {.cls qlm_trail} object.",
      "i" = "Create one with {.fn qlm_trail}."
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
  lines <- c(lines, "title: \"quallmer Provenance Trail\"")
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
