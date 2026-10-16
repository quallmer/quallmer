new_qlm_translation_corpus <- function(text, provenance, docvars = NULL, meta = NULL) {
  if (length(text) != nrow(provenance)) {
    cli::cli_abort("Translation text and provenance have different lengths.", .internal = TRUE)
  }
  check_ids(provenance$.id, what = "Translation identifiers")
  rownames(provenance) <- NULL
  text <- as.vector(text, "character")
  names(text) <- provenance$.id
  docvars <- docvars %||% translation_docvars(provenance$.id)
  if (nrow(docvars) != length(text) || !identical(docvars$docname_, names(text))) {
    cli::cli_abort("Translation document variables are misaligned.", .internal = TRUE)
  }
  meta <- meta %||% translation_corpus_meta()
  meta$user$quallmer$translation <- provenance
  # Summaries of the source texts cannot describe newly translated texts.
  meta$object$summary <- list(hash = character(), data = NULL)
  structure(text, docvars = docvars, meta = meta,
            class = c("qlm_translation_corpus", "qlm_preprocessed", "qlm_corpus", "corpus", "character"))
}

#' @export
`[.qlm_translation_corpus` <- function(x, i, ..., drop_docid = TRUE) {
  if (missing(i)) return(x)
  pos <- stats::setNames(seq_along(x), names(x))[i]
  text <- as.character(x)[i]
  check_ids(names(text), what = "The names of the subset")
  docvars <- attr(x, "docvars")[pos, , drop = FALSE]
  if (drop_docid) docvars$docid_ <- droplevels(docvars$docid_)
  rownames(docvars) <- NULL
  new_qlm_translation_corpus(text, translation_provenance(x)[pos, , drop = FALSE],
                      docvars = docvars, meta = attr(x, "meta"))
}

#' @export
`names<-.qlm_translation_corpus` <- function(x, value) {
  if (length(value) != length(x)) {
    cli::cli_abort("Supply one name per translation.")
  }
  check_ids(value, what = "The names of the translations")
  provenance <- translation_provenance(x)
  provenance$.id <- as.character(value)
  docvars <- attr(x, "docvars")
  docvars[c("docname_", "docid_", "segid_")] <- translation_docvars(as.character(value))
  new_qlm_translation_corpus(as.character(x), provenance, docvars, attr(x, "meta"))
}

#' @export
c.qlm_translation_corpus <- function(...) {
  parts <- list(...)
  if (!all(vapply(parts, inherits, logical(1), "qlm_translation_corpus"))) {
    cli::cli_abort("Every argument must be a {.cls qlm_translation_corpus}; use {.fn as.character} to drop provenance.")
  }
  text <- unlist(unname(lapply(parts, as.character)), use.names = TRUE)
  provenance <- do.call(rbind, unname(lapply(parts, translation_provenance)))
  metas <- lapply(parts, attr, "meta")
  users <- lapply(metas, translation_user_metadata)
  if (!all(vapply(users, identical, logical(1), users[[1]]))) {
    cli::cli_abort("Cannot combine translations with different corpus user metadata.")
  }
  docvars <- do.call(vctrs::vec_rbind, unname(lapply(parts, attr, "docvars")))
  new_qlm_translation_corpus(text, provenance, docvars, metas[[1]])
}

#' @export
as.character.qlm_translation_corpus <- function(x, ...) {
  translation_texts(x)
}

#' @export
`[<-.qlm_translation_corpus` <- function(x, i, value) {
  pos <- if (missing(i)) seq_along(x) else stats::setNames(seq_along(x), names(x))[i]
  if (anyNA(pos)) cli::cli_abort("A translation vector cannot be extended by assignment.")
  if (!length(pos)) return(x)
  if (length(value) != 1L && length(value) != length(pos)) {
    cli::cli_abort("Supply one replacement, or one per position replaced.")
  }
  text <- as.character(x)
  provenance <- translation_provenance(x)
  take <- rep_len(seq_along(value), length(pos))
  text[pos] <- as.character(value)[take]
  if (inherits(value, "qlm_translation_corpus")) {
    rows <- translation_provenance(value)[take, , drop = FALSE]
    rows$.id <- provenance$.id[pos]
    provenance[pos, ] <- rows
  } else {
    provenance$status[pos] <- ifelse(is.na(text[pos]), "failed", "edited")
    provenance$.error[pos] <- ifelse(is.na(text[pos]), "set to NA by assignment", NA_character_)
    provenance$output_hash[pos] <- vapply(text[pos], translation_hash, "")
    provenance$timestamp[pos] <- Sys.time()
  }
  new_qlm_translation_corpus(text, provenance, attr(x, "docvars"), attr(x, "meta"))
}

#' @export
`[[<-.qlm_translation_corpus` <- function(x, i, value) {
  if (length(i) != 1L || length(value) != 1L) {
    cli::cli_abort("{.code [[<-} replaces one translation with one value.")
  }
  x[i] <- value
  x
}

#' @export
print.qlm_translation_corpus <- function(x, max_ndoc = 6L, max_nchar = 60L,
                                  show_summary = TRUE, ...) {
  rlang::check_dots_empty()
  if (!is_count(max_ndoc, -1L)) {
    cli::cli_abort("{.arg max_ndoc} must be a whole number of at least -1.")
  }
  if (!is_count(max_nchar, -1L)) {
    cli::cli_abort("{.arg max_nchar} must be a whole number of at least -1.")
  }
  if (!is.logical(show_summary) || length(show_summary) != 1L || is.na(show_summary)) {
    cli::cli_abort("{.arg show_summary} must be TRUE or FALSE.")
  }
  text <- as.character(x)
  ndoc <- length(text)
  if (show_summary) {
    nchars <- sum(nchar(text, type = "chars"), na.rm = TRUE)
    ndocvars <- length(setdiff(names(attr(x, "docvars")),
                              c("docname_", "docid_", "segid_")))
    header <- paste0("corpus (qlm_translation) of ", translation_print_count(ndoc),
      " document", if (ndoc != 1L) "s", " (", translation_print_count(nchars),
      " character", if (nchars != 1L) "s", ")")
    if (ndocvars > 0L) {
      header <- paste0(header, " and ", translation_print_count(ndocvars),
                       " docvar", if (ndocvars != 1L) "s")
    }
    cat(header, ".\n", sep = "")
  }
  if (max_ndoc < 0L) max_ndoc <- ndoc
  shown <- seq_len(min(max_ndoc, ndoc))
  provenance <- translation_provenance(x)
  for (i in shown) {
    value <- if (is.na(text[i])) paste0("<NA: ", provenance$.error[i], ">") else text[i]
    value <- gsub("[\\p{C}]+", " ", value, perl = TRUE)
    if (max_nchar >= 0L && nchar(value, type = "chars") > max_nchar) {
      value <- paste0(substr(value, 1L, max_nchar), "...")
    }
    cat(names(text)[i], " :\n\"", value, "\"\n\n", sep = "")
  }
  if (max_ndoc > 0L && ndoc > length(shown)) {
    remaining <- ndoc - length(shown)
    cat("[ reached max_ndoc ... ", remaining, " more document",
        if (remaining != 1L) "s", " ]\n", sep = "")
  }
  invisible(x)
}

translation_print_count <- function(x) {
  format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
}

