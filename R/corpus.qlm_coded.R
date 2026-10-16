#' Convert coded text fields to a corpus
#'
#' Converts a text column of a `qlm_coded` object to a quanteda corpus. Quanteda
#' is optional and is needed only when calling its `corpus()` generic.
#'
#' @param x A `qlm_coded` object, including a `qlm_translation`.
#' @param text_field Name of the character column to use as corpus texts.
#'   Defaults to `"translation"` for translations. For other objects, it can
#'   be omitted only when there is exactly one character output column.
#' @param ... Reserved; must be empty.
#' @return A quanteda-compatible corpus with `.id` as document names. Original
#'   corpus docvars and system/user metadata are restored, aligned by ID.
#'   Object metadata is retained except for text summary caches, which are
#'   invalidated. Other output columns, coding metadata and the codebook are retained under
#'   `meta$user$quallmer$coding`; translation provenance remains under
#'   `meta$user$quallmer$translation`.
#' @seealso [qlm_translate()], [as_qlm_coded()]
#' @examples
#' \dontrun{
#' translated <- qlm_translate(c(a = "Bonjour"), "deepl/quality_optimized")
#' quanteda::corpus(translated)
#' quanteda::corpus(coded, text_field = "summary")
#' }
#' @rawNamespace S3method(quanteda::corpus, qlm_coded)
corpus.qlm_coded <- function(x, text_field = NULL, ...) {
  rlang::check_dots_empty()
  check_qlm_coded(x)
  if (is.null(text_field)) {
    if (inherits(x, "qlm_translation")) {
      text_field <- "translation"
    } else {
      candidates <- setdiff(names(x)[vapply(x, is.character, logical(1))], c(".id", ".error"))
      if (length(candidates) != 1L) {
        cli::cli_abort("Supply {.arg text_field} to select one character output column.")
      }
      text_field <- candidates
    }
  }
  if (!rlang::is_string(text_field) || !text_field %in% names(x) ||
      text_field %in% c(".id", ".error") || !is.character(x[[text_field]])) {
    cli::cli_abort("{.arg text_field} must name a character output column.")
  }
  original <- translation_corpus_attributes(x)
  text <- stats::setNames(x[[text_field]], as.character(x$.id))
  meta <- original$meta %||% translation_corpus_meta()
  if (!is.null(meta$user$quallmer) && !is.list(meta$user$quallmer)) {
    cli::cli_abort("The original corpus user metadata field {.val quallmer} must be a list.")
  }
  record <- redact_meta(attr(x, "meta"))
  record$user$corpus_docvars <- NULL
  record$user$corpus_meta <- NULL
  if (is_qlm_translation(x)) record$user$quallmer$translation <- NULL
  fields <- setdiff(names(x), text_field)
  other_outputs <- tibble::as_tibble(stats::setNames(lapply(fields, function(field) x[[field]]), fields))
  previous <- meta$user$quallmer$coding
  meta$user$quallmer$coding <- list(text_field = text_field, meta = record,
    codebook = codebook(x), other_outputs = other_outputs)
  if (!is.null(previous)) meta$user$quallmer$coding$parent <- previous
  if (is_qlm_translation(x) && identical(text_field, "translation")) {
    return(new_qlm_translation_corpus(text, translation_provenance(x), original$docvars, meta))
  }
  meta$object$summary <- list(hash = character(), data = NULL)
  structure(text, docvars = original$docvars %||% translation_docvars(names(text)),
            meta = meta, class = c("qlm_corpus", "corpus", "character"))
}

# Internal conversion also works without loading quanteda. It is used when
# a translation table is supplied as preprocessing input to qlm_code().
translation_as_corpus <- function(x) {
  original <- translation_corpus_attributes(x)
  new_qlm_translation_corpus(translation_texts(x), translation_provenance(x),
                            original$docvars, original$meta)
}
