# The translation object ------------------------------------------------------

#' The constructor: text and table of the same length, names from the table
#'
#' A translation is a named character vector, as a transcript is, with one
#' provenance row per text. A corpus input also leaves its document variables
#' and metadata in the `corpus` attribute, aligned with the texts, so that
#' `quanteda::corpus()` can restore them.
#'
#' @keywords internal
#' @noRd
new_qlm_translation <- function(text, provenance, corpus = NULL) {
  if (length(text) != nrow(provenance)) {
    cli::cli_abort(
      "A translation has {length(text)} element{?s} but its provenance {nrow(provenance)} row{?s}.",
      .internal = TRUE
    )
  }
  check_ids(provenance$.id, what = "Translation identifiers")
  rownames(provenance) <- NULL
  text <- as.vector(text, "character")
  names(text) <- provenance$.id
  if (!is.null(corpus) && !identical(corpus$docvars$docname_, names(text))) {
    cli::cli_abort("Translation document variables are misaligned.", .internal = TRUE)
  }
  structure(text, provenance = provenance, corpus = corpus,
            class = c("qlm_translation", "qlm_preprocessed", "character"))
}


# Methods ----------------------------------------------------------------------

#' Subset a translation vector
#'
#' The provenance rows, and any corpus document variables, follow the
#' elements by position. A subset that would repeat an identifier is refused.
#'
#' @param x A `qlm_translation`.
#' @param i An index: positions, names or a logical vector.
#' @param ... Ignored.
#'
#' @return A `qlm_translation`.
#' @keywords internal
#' @export
`[.qlm_translation` <- function(x, i, ...) {
  if (missing(i)) {
    return(x)
  }
  pos <- stats::setNames(seq_along(x), names(x))[i]
  text <- as.character(x)[i]
  check_ids(names(text), what = "The names of the subset")
  new_qlm_translation(text, attr(x, "provenance")[pos, , drop = FALSE],
                      translation_corpus_rows(attr(x, "corpus"), pos))
}

#' Replace translations, and their provenance with them
#'
#' Assigning a `qlm_translation` puts its rows in place of the old ones, so a
#' retried translation replaces the failure it retries, record and all; the
#' position keeps its name and corpus document variables. Assigning plain
#' text keeps the source and records that the translation was edited:
#' `status` becomes `"edited"`, the output hash is updated and the time is
#' now. Assigning `NA` records a failure set by hand. The vector cannot be
#' extended.
#'
#' @param x A `qlm_translation`.
#' @param i An index.
#' @param value A `qlm_translation`, or replacement text.
#'
#' @return A `qlm_translation`.
#' @keywords internal
#' @export
`[<-.qlm_translation` <- function(x, i, value) {
  provenance <- attr(x, "provenance")
  text <- as.character(x)
  pos <- if (missing(i)) seq_along(x) else stats::setNames(seq_along(x), names(x))[i]
  if (anyNA(pos) || any(pos > length(x))) {
    cli::cli_abort(c(
      "A {.cls qlm_translation} cannot be extended by assignment.",
      "i" = "Every element carries a provenance row; add translations with {.code c()} instead."
    ))
  }
  if (!length(pos)) {
    return(x)
  }
  if (length(value) != 1L && length(value) != length(pos)) {
    cli::cli_abort(
      "{.arg value} must have one element, or one per position replaced: {length(value)} for {length(pos)}."
    )
  }
  take <- rep_len(seq_along(value), length(pos))

  if (inherits(value, "qlm_translation")) {
    rows <- attr(value, "provenance")[take, , drop = FALSE]
    rows$.id <- provenance$.id[pos]
    provenance[pos, ] <- rows
    text[pos] <- as.character(value)[take]
  } else {
    value <- as.vector(value, "character")[take]
    text[pos] <- value
    provenance$status[pos] <- ifelse(is.na(value), "failed", "edited")
    provenance$.error[pos] <- ifelse(is.na(value), "set to NA by assignment", NA_character_)
    provenance$output_hash[pos] <- vapply(value, translation_hash, "", USE.NAMES = FALSE)
    provenance$timestamp[pos] <- Sys.time()
  }
  new_qlm_translation(text, provenance, attr(x, "corpus"))
}

#' Replace one translation, by the same rules as `[<-`
#'
#' @param x A `qlm_translation`.
#' @param i A single position or name.
#' @param value A `qlm_translation` of length one, or one string.
#'
#' @return A `qlm_translation`.
#' @keywords internal
#' @export
`[[<-.qlm_translation` <- function(x, i, value) {
  if (length(i) != 1L) {
    cli::cli_abort("{.code [[<-} replaces one translation; {.arg i} has length {length(i)}.")
  }
  if (length(value) != 1L) {
    cli::cli_abort("{.code [[<-} replaces one translation; {.arg value} has length {length(value)}.")
  }
  x[i] <- value
  x
}

#' Rename translations, keeping their provenance in step
#'
#' @param x A `qlm_translation`.
#' @param value The new names, one per element, unique and non-empty.
#'
#' @return A `qlm_translation`.
#' @keywords internal
#' @export
`names<-.qlm_translation` <- function(x, value) {
  if (length(value) != length(x)) {
    cli::cli_abort(c(
      "{.arg value} must have one name per translation: {length(value)} for {length(x)} element{?s}.",
      "i" = "A translation cannot be unnamed; its name is its {.field .id} when it is coded."
    ))
  }
  check_ids(value, what = "The names of a {.cls qlm_translation}")
  value <- as.character(value)
  provenance <- attr(x, "provenance")
  provenance$.id <- value
  corpus <- attr(x, "corpus")
  if (!is.null(corpus)) {
    corpus$docvars[c("docname_", "docid_", "segid_")] <- translation_docvars(value)
  }
  new_qlm_translation(as.character(x), provenance, corpus)
}

#' Combine translation vectors
#'
#' Joins independent runs, such as a run and the retry of its failures, into
#' one vector with the provenance rows of each; the names must not collide.
#' Translations of corpora combine only with translations of corpora that
#' share the same user metadata.
#'
#' @param ... `qlm_translation` objects.
#'
#' @return A `qlm_translation`.
#' @keywords internal
#' @export
c.qlm_translation <- function(...) {
  parts <- list(...)
  is_translation <- vapply(parts, inherits, logical(1), "qlm_translation")
  if (!all(is_translation)) {
    bad <- which(!is_translation)[1]
    cli::cli_abort(c(
      "Every argument must be a {.cls qlm_translation}; argument {bad} is {.cls {class(parts[[bad]])}}.",
      "i" = "Use {.code as.character()} on the translations to combine them with plain text, dropping their provenance."
    ))
  }
  text <- unlist(unname(lapply(parts, as.character)), use.names = TRUE)
  check_ids(names(text), what = "The names of the combined translations")
  provenance <- do.call(rbind, unname(lapply(parts, attr, "provenance")))
  corpora <- lapply(parts, attr, "corpus")
  from_corpus <- !vapply(corpora, is.null, logical(1))
  corpus <- NULL
  if (any(from_corpus)) {
    users <- lapply(corpora, function(corpus) corpus$meta$user)
    if (!all(from_corpus) || !all(vapply(users, identical, logical(1), users[[1]]))) {
      cli::cli_abort(c(
        "Cannot combine translations of corpora with different user metadata.",
        "i" = "Every argument must come from a corpus with the same {.code quanteda::meta()}."
      ))
    }
    docvars <- do.call(vctrs::vec_rbind, unname(lapply(corpora, `[[`, "docvars")))
    rownames(docvars) <- NULL
    corpus <- list(docvars = docvars, meta = corpora[[1]]$meta)
  }
  new_qlm_translation(text, provenance, corpus)
}

#' Drop the class and provenance, keeping the names
#'
#' @param x A `qlm_translation`.
#' @param ... Ignored.
#'
#' @return A named character vector.
#' @keywords internal
#' @export
as.character.qlm_translation <- function(x, ...) {
  translation_texts(x)
}

#' Print a translation vector
#'
#' @param x A `qlm_translation`.
#' @param n integer; how many translations to show.
#' @param width integer; the line width to fit each to.
#' @param ... Ignored.
#'
#' @return `x`, invisibly.
#' @keywords internal
#' @export
print.qlm_translation <- function(x, n = 10, width = getOption("width", 80), ...) {
  prov <- attr(x, "provenance")
  total <- length(x)
  failed <- sum(prov$status %in% c("failed", "unsubmitted"))
  models <- unique(prov$model)
  cat(sprintf(
    "<qlm_translation: %d translation%s%s; model%s %s; target %s>\n",
    total, if (total == 1L) "" else "s",
    if (failed) sprintf(", %d failed", failed) else "",
    if (length(models) == 1L) "" else "s",
    paste(models, collapse = ", "), paste(unique(prov$target_lang), collapse = ", ")
  ))
  shown <- seq_len(min(n, total))
  for (i in shown) {
    prefix <- paste0(names(x)[i], ": ")
    body <- if (is.na(x[[i]])) {
      paste0("<NA: ", prov$.error[i], ">")
    } else {
      gsub("[\\p{C}]+", " ", x[[i]], perl = TRUE)
    }
    room <- max(width - nchar(prefix), 10L)
    if (nchar(body) > room) {
      body <- paste0(substr(body, 1L, room - 3L), "...")
    }
    cat(prefix, body, "\n", sep = "")
  }
  if (total > length(shown)) {
    cat(sprintf("# ... with %d more\n", total - length(shown)))
  }
  invisible(x)
}

#' @rdname inputs
#' @export
inputs.qlm_translation <- function(x) {
  source <- stats::setNames(attr(x, "provenance")$source_text, names(x))
  corpus <- attr(x, "corpus")
  if (is.null(corpus)) {
    return(source)
  }
  structure(source, docvars = corpus$docvars, meta = corpus$meta,
            class = c("corpus", "character"))
}

#' @rdname corpus.qlm_coded
#' @rawNamespace S3method(quanteda::corpus, qlm_translation)
corpus.qlm_translation <- function(x, ...) {
  rlang::check_dots_empty()
  corpus <- attr(x, "corpus")
  meta <- corpus$meta %||% translation_corpus_meta()
  if (!is.null(meta$user$quallmer) && !is.list(meta$user$quallmer)) {
    cli::cli_abort("The original corpus user metadata field {.val quallmer} must be a list.")
  }
  meta$user$quallmer$translation <- attr(x, "provenance")
  # Summaries of the source texts cannot describe the translated texts.
  meta$object$summary <- list(hash = character(), data = NULL)
  structure(as.character(x),
            docvars = corpus$docvars %||% translation_docvars(names(x)),
            meta = meta, class = c("qlm_corpus", "corpus", "character"))
}


# Helpers ----------------------------------------------------------------------

translation_corpus_rows <- function(corpus, pos) {
  if (is.null(corpus)) {
    return(NULL)
  }
  docvars <- corpus$docvars[pos, , drop = FALSE]
  docvars$docid_ <- droplevels(docvars$docid_)
  rownames(docvars) <- NULL
  corpus$docvars <- docvars
  corpus
}

translation_texts <- function(x) {
  ids <- names(x)
  out <- unclass(x)
  attributes(out) <- NULL
  names(out) <- ids
  out
}

is_qlm_translation <- function(x) {
  inherits(x, "qlm_translation")
}

is_qlm_preprocessed <- function(x) {
  # Saved transcript vectors made before the shared parent existed still
  # carry valid provenance and must keep it when they are translated.
  inherits(x, "qlm_preprocessed") || inherits(x, "qlm_transcript")
}

# The provenance of a translation or a transcript, with .id reset to the
# current names, which are what a coding run keys on.
translation_provenance <- function(x) {
  provenance <- attr(x, "provenance", exact = TRUE)
  if (is.null(provenance)) {
    return(NULL)
  }
  provenance$.id <- as.character(names(x))
  rownames(provenance) <- NULL
  provenance
}


# Preprocessing history --------------------------------------------------------

# Histories are per document so that subsetting, concatenation and retries
# can combine documents with different preprocessing chains safely.
preprocessing_history <- function(x, compact = FALSE) {
  if (!is_qlm_preprocessed(x)) return(rep(list(list()), length(x)))
  provenance <- translation_provenance(x)
  stage <- if (is_qlm_translation(x)) "translation" else "transcription"
  lapply(seq_len(nrow(provenance)), function(i) {
    row <- provenance[i, , drop = FALSE]
    history <- if ("history" %in% names(row)) row$history[[1]] else list()
    row$history <- NULL
    row$source_text <- NULL
    steps <- c(history, list(list(stage = stage, provenance = row)))
    if (compact) lapply(steps, compact_preprocessing_step) else steps
  })
}

compact_preprocessing_step <- function(step) {
  row <- step$provenance
  row$source_text <- NULL
  if ("attempts" %in% names(row)) {
    row$attempts[[1]] <- compact_translation_attempts(row$attempts[[1]])
  }
  step$provenance <- row
  step
}

# A coding run keeps hashes of the source text, not the text: the context a
# request was given is replaced by its hash.
compact_translation_attempts <- function(attempts) {
  if (!"neighbouring_context" %in% names(attempts)) {
    return(attempts)
  }
  attempts$neighbouring_context_hash <- vapply(attempts$neighbouring_context,
    translation_hash, "", USE.NAMES = FALSE)
  attempts$neighbouring_context <- NULL
  attempts
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
