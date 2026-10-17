#' Convert translations and coded text fields to a corpus
#'
#' Converts a [qlm_translate()] result, or a text column of a `qlm_coded`
#' object, to a quanteda corpus. Quanteda is optional and is needed only when
#' calling its `corpus()` generic.
#'
#' @param x A `qlm_translation` or a `qlm_coded` object.
#' @param text_field For a `qlm_coded` object, the name of the character
#'   column to use as corpus texts. It can be omitted only when there is
#'   exactly one character output column.
#' @param ... Reserved; must be empty.
#' @return A quanteda corpus with the translation names, or `.id`, as
#'   document names. If the texts came from a corpus, its docvars and
#'   system and user metadata are restored, and text summary caches are
#'   cleared. Translation provenance is stored in
#'   `meta$user$quallmer$translation`. For a coded object, the other output
#'   columns, coding metadata and codebook are stored in
#'   `meta$user$quallmer$coding`.
#' @seealso [qlm_translate()], [as_qlm_coded()]
#' @examples
#' \dontrun{
#' translated <- qlm_translate(c(a = "Bonjour"), "deepl/quality_optimized")
#' quanteda::corpus(translated)
#'
#' summaries <- qlm_code(translated, my_summary_codebook, model = "openai/gpt-4o-mini")
#' quanteda::corpus(summaries, text_field = "summary")
#' }
#' @rawNamespace S3method(quanteda::corpus, qlm_coded)
corpus.qlm_coded <- function(x, text_field = NULL, ...) {
  rlang::check_dots_empty()
  check_qlm_coded(x)
  if (is.null(text_field)) {
    candidates <- setdiff(names(x)[vapply(x, is.character, logical(1))], c(".id", ".error"))
    if (length(candidates) != 1L) {
      cli::cli_abort("Supply {.arg text_field} to select one character output column.")
    }
    text_field <- candidates
  }
  if (!rlang::is_string(text_field) || !text_field %in% names(x) ||
      text_field %in% c(".id", ".error") || !is.character(x[[text_field]])) {
    cli::cli_abort("{.arg text_field} must name a character output column.")
  }
  original <- coded_corpus_attributes(x)
  text <- stats::setNames(x[[text_field]], as.character(x$.id))
  meta <- original$meta %||% translation_corpus_meta()
  if (!is.null(meta$user$quallmer) && !is.list(meta$user$quallmer)) {
    cli::cli_abort("The original corpus user metadata field {.val quallmer} must be a list.")
  }
  record <- redact_meta(attr(x, "meta"))
  record$user$corpus_docvars <- NULL
  record$user$corpus_meta <- NULL
  fields <- setdiff(names(x), text_field)
  other_outputs <- tibble::as_tibble(stats::setNames(lapply(fields, function(field) x[[field]]), fields))
  previous <- meta$user$quallmer$coding
  meta$user$quallmer$coding <- list(text_field = text_field, meta = record,
    codebook = codebook(x), other_outputs = other_outputs)
  if (!is.null(previous)) meta$user$quallmer$coding$parent <- previous
  meta$object$summary <- list(hash = character(), data = NULL)
  structure(text, docvars = original$docvars %||% translation_docvars(names(text)),
            meta = meta, class = c("qlm_corpus", "corpus", "character"))
}

# The corpus document variables and metadata qlm_code() recorded for a run,
# with the document variables aligned to the coded rows.
coded_corpus_attributes <- function(x) {
  user <- attr(x, "meta", exact = TRUE)$user
  docvars <- user$corpus_docvars
  if (!is.null(docvars)) {
    pos <- match(as.character(x$.id), docvars$docname_)
    if (anyNA(pos)) cli::cli_abort("Corpus document variables no longer match the coded identifiers.")
    docvars <- docvars[pos, , drop = FALSE]
    rownames(docvars) <- NULL
  }
  list(docvars = docvars, meta = user$corpus_meta)
}
