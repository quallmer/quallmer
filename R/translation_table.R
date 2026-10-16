# A translation is a coded text field, with its original inputs retained by
# the same constructor and accessors as other coding results.
new_qlm_translation <- function(text, provenance, docvars = NULL, meta = NULL,
                                data = NULL, call = NULL) {
  if (length(text) != nrow(provenance)) {
    cli::cli_abort("Translation text and provenance have different lengths.", .internal = TRUE)
  }
  check_ids(provenance$.id, what = "Translation identifiers")
  rownames(provenance) <- NULL
  settings <- if (nrow(provenance)) provenance$settings[[1]] else list()
  instructions <- paste(c(
    paste0("Translate the input text into ", settings$target_lang %||% "the target language", "."),
    settings$instructions
  ), collapse = "\n")
  schema <- qlm_codebook("Translation", instructions,
    ellmer::type_object(translation = ellmer::type_string("Translated text")))
  errors <- lapply(provenance$.error, function(error) {
    if (is.na(error)) NULL else simpleError(error)
  })
  result <- new_qlm_coded(
    results = tibble::tibble(.id = provenance$.id, translation = unname(text), .error = errors),
    codebook = schema, data = data %||% stats::setNames(provenance$source_text, provenance$.id),
    input_type = "text", chat_args = list(name = paste(unique(provenance$model), collapse = ", ")),
    execution_args = list(), metadata = list(
      n_units = length(text), timestamp = Sys.time(),
      ellmer_version = as.character(utils::packageVersion("ellmer")),
      quallmer_version = as.character(utils::packageVersion("quallmer")),
      R_version = as.character(getRversion()),
      corpus_docvars = docvars, corpus_meta = meta,
      quallmer = list(translation = provenance)),
    name = "translation", call = call
  )
  attr(result, "meta") <- redact_meta(attr(result, "meta"))
  class(result) <- c("qlm_translation", class(result))
  result
}

translation_ids <- function(x) {
  if (is.data.frame(x) && inherits(x, "qlm_translation")) as.character(x$.id) else names(x)
}

#' @export
as.character.qlm_translation <- function(x, ...) {
  translation_texts(x)
}

#' @export
print.qlm_translation <- function(x, ...) {
  if (!is.data.frame(x)) return(print.qlm_translation_corpus(x, ...))
  cat("# Translation result (qlm_translation)\n")
  NextMethod()
}

#' @export
`[.qlm_translation` <- function(x, i, j, ..., drop = FALSE) {
  if (!is.data.frame(x)) return(`[.qlm_translation_corpus`(x, i, ...))
  out <- NextMethod()
  if (!is.data.frame(out)) return(out)
  if (!all(c(".id", "translation") %in% names(out))) {
    class(out) <- setdiff(class(out), "qlm_translation")
    return(out)
  }
  sync_translation_table(out, x)
}

#' @export
`[<-.qlm_translation` <- function(x, i, j, value) {
  if (!is.data.frame(x)) return(`[<-.qlm_translation_corpus`(x, i, value))
  old <- x
  out <- NextMethod()
  out <- sync_translation_table(out, old,
    rekey = nrow(out) == nrow(old) && !identical(out$.id, old$.id))
  if (inherits(value, "qlm_translation") && missing(j)) {
    provenance <- translation_provenance(out)
    replacement <- translation_provenance(value)
    pos <- match(replacement$.id, out$.id)
    provenance[pos, ] <- replacement
    metadata <- attr(out, "meta")
    metadata$user$quallmer$translation <- provenance
    attr(out, "meta") <- metadata
    class(out) <- setdiff(class(out), "qlm_translation")
    out$.error[pos] <- value$.error
    class(out) <- c("qlm_translation", class(out))
    data <- stats::setNames(provenance$source_text, provenance$.id)
    if (inherits(inputs(old), "corpus")) {
      data <- structure(data, docvars = metadata$user$corpus_docvars,
        meta = metadata$user$corpus_meta, class = class(inputs(old)))
    }
    attr(out, "data") <- data
  }
  out
}

#' @export
`[[<-.qlm_translation` <- function(x, i, value) {
  if (!is.data.frame(x)) return(`[[<-.qlm_translation_corpus`(x, i, value))
  old <- x
  out <- NextMethod()
  sync_translation_table(out, old, rekey = !identical(out$.id, old$.id))
}

#' @export
`$<-.qlm_translation` <- function(x, name, value) {
  x[[name]] <- value
  x
}

#' @export
`names<-.qlm_translation` <- function(x, value) {
  if (!is.data.frame(x)) return(`names<-.qlm_translation_corpus`(x, value))
  check_ids(value, what = "Column names")
  class(x) <- setdiff(class(x), "qlm_translation")
  names(x) <- value
  if (!".id" %in% names(x)) {
    class(x) <- setdiff(class(x), "qlm_coded")
    for (name in c("data", "codebook", "meta")) attr(x, name) <- NULL
  } else if ("translation" %in% names(x)) {
    class(x) <- c("qlm_translation", class(x))
  }
  x
}

#' @export
rbind.qlm_translation <- function(..., deparse.level = 1) {
  parts <- list(...)
  if (!length(parts) || !all(vapply(parts, inherits, logical(1), "qlm_translation"))) {
    cli::cli_abort("Every argument must be a {.cls qlm_translation}.")
  }
  originals <- lapply(parts, translation_corpus_attributes)
  users <- lapply(originals, function(original) original$meta$user)
  if (!all(vapply(users, identical, logical(1), users[[1]]))) {
    cli::cli_abort("Cannot combine translations with different corpus user metadata.")
  }
  provenance <- do.call(rbind, lapply(parts, translation_provenance))
  text <- unlist(lapply(parts, function(part) unname(part$translation)), use.names = FALSE)
  docvars <- if (all(vapply(originals, function(original) is.null(original$docvars), logical(1)))) {
    NULL
  } else do.call(vctrs::vec_rbind, lapply(seq_along(parts), function(i) {
    originals[[i]]$docvars %||% translation_docvars(parts[[i]]$.id)
  }))
  data <- stats::setNames(provenance$source_text, provenance$.id)
  if (!is.null(docvars)) {
    attributes(data) <- c(attributes(data), list(docvars = docvars,
      meta = originals[[1]]$meta %||% translation_corpus_meta(),
      class = c("qlm_corpus", "corpus", "character")))
  }
  new_qlm_translation(text, provenance, docvars, originals[[1]]$meta, data = data)
}

# Keep the keyed metadata and retained inputs aligned with ordinary tibble
# row selection and edits. Edited text is marked as such, not model output.
sync_translation_table <- function(out, old, rekey = FALSE) {
  if (!all(c(".id", "translation") %in% names(out))) {
    class(out) <- setdiff(class(out), "qlm_translation")
    if (!".id" %in% names(out)) {
      class(out) <- setdiff(class(out), "qlm_coded")
      for (name in c("data", "codebook", "meta")) attr(out, name) <- NULL
    }
    return(out)
  }
  check_ids(out$.id, what = "Translation identifiers")
  if (!is.character(out$translation)) cli::cli_abort("{.field translation} must be a character column.")
  provenance <- translation_provenance(old)
  pos <- if (rekey) seq_len(nrow(old)) else match(out$.id, old$.id)
  if (anyNA(pos) || nrow(out) != length(pos)) {
    cli::cli_abort("A translation table cannot be extended without translation provenance.")
  }
  rows <- provenance[pos, , drop = FALSE]
  hashes <- vapply(out$translation, translation_hash, "")
  edited <- !(is.na(hashes) & is.na(rows$output_hash)) &
    (is.na(hashes) | is.na(rows$output_hash) | hashes != rows$output_hash)
  edited[is.na(edited)] <- FALSE
  rows$.id <- as.character(out$.id)
  rows$status[edited] <- ifelse(is.na(out$translation[edited]), "failed", "edited")
  rows$.error[edited] <- ifelse(is.na(out$translation[edited]), "set to NA by assignment", NA_character_)
  rows$output_hash <- unname(hashes)
  rows$timestamp[edited] <- Sys.time()
  rownames(rows) <- NULL
  metadata <- attr(out, "meta")
  metadata$user$quallmer$translation <- rows
  docvars <- attr(old, "meta")$user$corpus_docvars
  if (!is.null(docvars)) {
    docvars <- docvars[match(old$.id, docvars$docname_)[pos], , drop = FALSE]
    docvars$docname_ <- as.character(out$.id)
    if (rekey) docvars[c("docname_", "docid_", "segid_")] <- translation_docvars(as.character(out$.id))
    rownames(docvars) <- NULL
    metadata$user$corpus_docvars <- docvars
  }
  attr(out, "meta") <- metadata
  data <- inputs(old)
  data <- translation_subset_inputs(data, pos)
  if (rekey) {
    if (is.data.frame(data) && inherits(data, "qlm_translation")) {
      data$.id <- as.character(out$.id)
    } else if (!is.data.frame(data)) {
      names(data) <- as.character(out$.id)
      if (inherits(data, "corpus")) {
        vars <- attr(data, "docvars")
        vars[c("docname_", "docid_", "segid_")] <- translation_docvars(names(data))
        attr(data, "docvars") <- vars
      }
    }
  }
  attr(out, "data") <- data
  if (".error" %in% names(out) || any(edited)) {
    errors <- out[[".error"]] %||% rep(list(NULL), nrow(out))
    for (i in which(edited)) {
      errors[i] <- list(if (is.na(rows$.error[i])) NULL else simpleError(rows$.error[i]))
    }
    # Avoid replacement dispatch while updating a derived diagnostic column.
    class(out) <- setdiff(class(out), "qlm_translation")
    out$.error <- errors
    class(out) <- c("qlm_translation", class(out))
  }
  out
}

translation_subset_inputs <- function(data, pos) {
  if (is.data.frame(data)) return(data[pos, , drop = FALSE])
  if (!inherits(data, "corpus")) return(data[pos])
  out <- translation_texts(data)[pos]
  docvars <- attr(data, "docvars")[pos, , drop = FALSE]
  rownames(docvars) <- NULL
  structure(out, docvars = docvars, meta = attr(data, "meta"), class = class(data))
}
