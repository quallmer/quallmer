# The compatibility boundary with quanteda's character-vector corpus format.
# These helpers neither load nor require quanteda. Integration tests compare
# the result with real corpora when the suggested package is installed.
translation_corpus_attributes <- function(x) {
  if (is.data.frame(x) && inherits(x, "qlm_coded")) {
    user <- attr(x, "meta", exact = TRUE)$user
    docvars <- user$corpus_docvars
    if (!is.null(docvars)) {
      pos <- match(as.character(x$.id), docvars$docname_)
      if (anyNA(pos)) cli::cli_abort("Corpus document variables no longer match the coded identifiers.")
      docvars <- docvars[pos, , drop = FALSE]
      rownames(docvars) <- NULL
    }
    return(list(docvars = docvars, meta = user$corpus_meta))
  }
  if (!inherits(x, "corpus")) return(list(docvars = NULL, meta = NULL))
  docvars <- attr(x, "docvars", exact = TRUE)
  meta <- attr(x, "meta", exact = TRUE)
  if (!is.data.frame(docvars) || nrow(docvars) != length(x) ||
      !all(c("docname_", "docid_", "segid_") %in% names(docvars)) ||
      !identical(docvars$docname_, names(x))) {
    cli::cli_abort("The input corpus has invalid or misaligned document variables.")
  }
  if (!is.list(meta) || !all(c("system", "object", "user") %in% names(meta))) {
    cli::cli_abort("The input corpus must have system, object and user metadata.")
  }
  namespace <- meta$user[["quallmer", exact = TRUE]]
  if (!is.null(namespace) && !is.list(namespace)) {
    cli::cli_abort("The corpus user metadata field {.val quallmer} must be a list.")
  }
  existing <- namespace[["translation", exact = TRUE]]
  if (!is.null(existing) && (!is.data.frame(existing) ||
      !all(c(".id", "status", "source_hash", "output_hash") %in% names(existing)))) {
    cli::cli_abort("The corpus already has an incompatible {.val quallmer$translation} metadata field.")
  }
  list(docvars = docvars, meta = meta)
}

translation_docvars <- function(ids) {
  data.frame(docname_ = ids, docid_ = factor(ids, levels = ids),
             segid_ = rep(1L, length(ids)), stringsAsFactors = FALSE)
}

translation_corpus_meta <- function() {
  list(system = list(
    package = "quallmer", `package-version` = utils::packageVersion("quallmer"),
    `r-version` = getRversion(), system = Sys.info()[c("sysname", "machine", "user")],
    directory = getwd(), created = Sys.Date()
  ), object = list(unit = "documents", summary = list(hash = character(), data = NULL)),
  user = list())
}

translation_texts <- function(x) {
  if (is.data.frame(x) && inherits(x, "qlm_translation")) {
    return(stats::setNames(x$translation, as.character(x$.id)))
  }
  ids <- names(x)
  out <- unclass(x)
  attributes(out) <- NULL
  names(out) <- ids
  out
}

translation_provenance <- function(x) {
  meta <- attr(x, "meta", exact = TRUE)
  namespace <- meta$user[["quallmer", exact = TRUE]]
  provenance <- if (is.list(namespace)) namespace[["translation", exact = TRUE]]
  # Read first-attempt objects saved before corpus support was introduced.
  if (is.null(provenance)) provenance <- attr(x, "provenance", exact = TRUE)
  if (is.null(provenance)) return(NULL)
  if (!is.data.frame(provenance) || !".id" %in% names(provenance)) {
    cli::cli_abort("The translation provenance table is invalid.")
  }
  check_ids(provenance$.id, what = "Translation provenance identifiers")
  pos <- match(translation_ids(x), provenance$.id)
  if (anyNA(pos)) {
    cli::cli_abort("Translation provenance no longer matches the document identifiers.")
  }
  provenance <- provenance[pos, , drop = FALSE]
  rownames(provenance) <- NULL
  provenance
}

is_qlm_translation <- function(x) {
  namespace <- attr(x, "meta", exact = TRUE)$user[["quallmer", exact = TRUE]]
  inherits(x, "qlm_translation") ||
    (inherits(x, "corpus") && is.list(namespace) &&
       is.data.frame(namespace[["translation", exact = TRUE]]))
}

translation_user_metadata <- function(meta) {
  user <- meta$user
  if (is.list(user$quallmer)) {
    user$quallmer$translation <- NULL
    user$quallmer$coding <- NULL
    if (!length(user$quallmer)) user$quallmer <- NULL
  }
  user
}

#' @export
qlm_meta.qlm_translation <- function(x, field = NULL,
                                    type = c("user", "object", "system", "all")) {
  qlm_meta.qlm_coded(x, field = field, type = type)
}

#' @export
qlm_meta.qlm_translation_corpus <- function(x, field = NULL,
                                           type = c("user", "object", "system", "all")) {
  qlm_meta.qlm_coded(x, field = field, type = type)
}

# Quanteda's replacement method changes names directly. Route it through our
# method as well so that the keyed provenance follows the new names.
#' @rawNamespace S3method(quanteda::"docnames<-", qlm_translation_corpus)
`docnames<-.qlm_translation_corpus` <- function(x, unique_docnames = TRUE, value) {
  names(x) <- value
  x
}
