# The compatibility boundary with quanteda's character-vector corpus format.
# These helpers neither load nor require quanteda. Integration tests compare
# the result with real corpora when the suggested package is installed.

# The document variables and metadata a translation carries forward: those of
# a corpus input, or those an earlier translation carried, else NULL.
translation_corpus_attributes <- function(x) {
  if (is_qlm_translation(x)) {
    return(attr(x, "corpus", exact = TRUE))
  }
  if (!inherits(x, "corpus")) {
    return(NULL)
  }
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
  rownames(docvars) <- NULL
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

# Corpus user metadata without the records quallmer itself writes there.
translation_user_metadata <- function(meta) {
  user <- meta$user
  if (is.list(user$quallmer)) {
    user$quallmer$translation <- NULL
    user$quallmer$coding <- NULL
    if (!length(user$quallmer)) user$quallmer <- NULL
  }
  user
}
