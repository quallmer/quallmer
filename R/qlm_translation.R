new_qlm_translation <- function(text, provenance) {
  if (length(text) != nrow(provenance)) {
    cli::cli_abort("Translation text and provenance have different lengths.", .internal = TRUE)
  }
  check_ids(provenance$.id, what = "Translation identifiers")
  rownames(provenance) <- NULL
  text <- as.vector(text, "character")
  names(text) <- provenance$.id
  structure(text, provenance = provenance,
            class = c("qlm_translation", "qlm_preprocessed", "character"))
}

#' @export
`[.qlm_translation` <- function(x, i, ...) {
  if (missing(i)) return(x)
  pos <- stats::setNames(seq_along(x), names(x))[i]
  text <- as.character(x)[i]
  check_ids(names(text), what = "The names of the subset")
  new_qlm_translation(text, attr(x, "provenance")[pos, , drop = FALSE])
}

#' @export
`names<-.qlm_translation` <- function(x, value) {
  if (length(value) != length(x)) {
    cli::cli_abort("Supply one name per translation.")
  }
  check_ids(value, what = "The names of the translations")
  provenance <- attr(x, "provenance")
  provenance$.id <- as.character(value)
  new_qlm_translation(as.character(x), provenance)
}

#' @export
c.qlm_translation <- function(...) {
  parts <- list(...)
  if (!all(vapply(parts, inherits, logical(1), "qlm_translation"))) {
    cli::cli_abort("Every argument must be a {.cls qlm_translation}; use {.fn as.character} to drop provenance.")
  }
  text <- unlist(unname(lapply(parts, as.character)), use.names = TRUE)
  provenance <- do.call(rbind, unname(lapply(parts, attr, "provenance")))
  new_qlm_translation(text, provenance)
}

#' @export
as.character.qlm_translation <- function(x, ...) {
  out <- unclass(x)
  attr(out, "provenance") <- NULL
  out
}

#' @export
`[<-.qlm_translation` <- function(x, i, value) {
  pos <- if (missing(i)) seq_along(x) else stats::setNames(seq_along(x), names(x))[i]
  if (anyNA(pos)) cli::cli_abort("A translation vector cannot be extended by assignment.")
  if (!length(pos)) return(x)
  if (length(value) != 1L && length(value) != length(pos)) {
    cli::cli_abort("Supply one replacement, or one per position replaced.")
  }
  text <- as.character(x)
  provenance <- attr(x, "provenance")
  take <- rep_len(seq_along(value), length(pos))
  text[pos] <- as.character(value)[take]
  if (inherits(value, "qlm_translation")) {
    rows <- attr(value, "provenance")[take, , drop = FALSE]
    rows$.id <- provenance$.id[pos]
    provenance[pos, ] <- rows
  } else {
    provenance$status[pos] <- ifelse(is.na(text[pos]), "failed", "edited")
    provenance$.error[pos] <- ifelse(is.na(text[pos]), "set to NA by assignment", NA_character_)
    provenance$output_hash[pos] <- vapply(text[pos], translation_hash, "")
    provenance$timestamp[pos] <- Sys.time()
  }
  new_qlm_translation(text, provenance)
}

#' @export
`[[<-.qlm_translation` <- function(x, i, value) {
  if (length(i) != 1L || length(value) != 1L) {
    cli::cli_abort("{.code [[<-} replaces one translation with one value.")
  }
  x[i] <- value
  x
}

#' @export
print.qlm_translation <- function(x, n = 10, width = getOption("width", 80), ...) {
  provenance <- attr(x, "provenance")
  cat(sprintf("<qlm_translation: %d texts; %d failed; %s>\n", length(x),
    sum(provenance$status %in% c("failed", "unsubmitted")),
    paste(unique(provenance$model), collapse = ", ")))
  shown <- seq_len(min(n, length(x)))
  for (i in shown) {
    value <- if (is.na(x[[i]])) paste0("<NA: ", provenance$.error[i], ">") else x[[i]]
    line <- paste0(names(x)[i], ": ", sub("[\r\n].*$", "", value))
    if (nchar(line) > width) line <- paste0(substr(line, 1L, max(1L, width - 3L)), "...")
    cat(line, "\n", sep = "")
  }
  if (length(x) > length(shown)) cat("# ... with", length(x) - length(shown), "more\n")
  invisible(x)
}

# Histories are per document so that subsetting, concatenation and retries
# can combine documents with different preprocessing chains safely.
preprocessing_history <- function(x, compact = FALSE) {
  if (!is_qlm_preprocessed(x)) return(rep(list(list()), length(x)))
  provenance <- attr(x, "provenance")
  stage <- if (inherits(x, "qlm_translation")) "translation" else "transcription"
  lapply(seq_along(x), function(i) {
    row <- provenance[i, , drop = FALSE]
    history <- if ("history" %in% names(row)) row$history[[1]] else list()
    row$history <- NULL
    row$source_text <- NULL
    steps <- c(history, list(list(stage = stage, provenance = row)))
    if (compact) lapply(steps, compact_preprocessing_step) else steps
  })
}

is_qlm_preprocessed <- function(x) {
  # Saved transcript vectors made before the shared parent existed still
  # carry valid provenance and must keep it when they are translated.
  inherits(x, "qlm_preprocessed") || inherits(x, "qlm_transcript")
}

compact_preprocessing_step <- function(step) {
  row <- step$provenance
  row$source_text <- NULL
  if ("attempts" %in% names(row)) {
    row$attempts[[1]] <- lapply(row$attempts[[1]], compact_translation_attempt)
  }
  step$provenance <- row
  step
}

compact_translation_attempt <- function(attempt) {
  context <- attempt[["neighbouring_context", exact = TRUE]]
  if (!is.null(context)) {
    attempt$neighbouring_context_hash <- translation_hash(context)
  }
  attempt$neighbouring_context <- NULL
  attempt$markers <- NULL
  attempt
}

preprocessing_record <- function(x) {
  stats::setNames(preprocessing_history(x, compact = TRUE), names(x))
}

preprocessing_lines <- function(records) {
  if (!length(records)) return(character())
  lines <- c("**Text preprocessing:**", "")
  for (id in names(records)) {
    for (step in records[[id]]) {
      row <- step$provenance
      if (step$stage == "translation") {
        lines <- c(lines, paste0("- `", id, "`: translated with `", row$model,
          "` (", row$adapter, ") to ", row$target_lang, "; status: ", row$status,
          "; source SHA-256: `", row$source_hash, "`; output SHA-256: `", row$output_hash, "`."))
      } else {
        lines <- c(lines, paste0("- `", id, "`: transcribed with `", row$model,
          "`; source SHA-256: `", row$sha256, "`; status: ", row$status, "."))
      }
    }
  }
  c(lines, "")
}
