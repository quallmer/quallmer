# Corpus print methods
#
# These methods provide basic printing for quanteda corpus objects when quanteda
# is not loaded. The data_corpus_* objects in this package are quanteda corpus
# objects, which print nicely when quanteda is loaded but appear as ugly character
# vectors with many attributes when quanteda is not available.
#
# To avoid adding quanteda as a dependency, we provide lightweight print methods
# that are conditionally registered in .onLoad() only if quanteda is not already
# loaded. This prevents conflicts when quanteda is loaded first. If quanteda is
# loaded after quallmer, users will see a warning but the methods still work
# correctly because they check at runtime and defer to quanteda's methods.

#' Print method for corpus objects
#'
#' Provides a simple print method for corpus objects when quanteda is not loaded.
#' This displays basic information about the corpus structure without requiring
#' quanteda as a dependency.
#'
#' @param x a corpus object
#' @param ... additional arguments (not used)
#' @importFrom utils getFromNamespace
#' @keywords internal
print.corpus <- function(x, ...) {
  # If quanteda is loaded, defer to its method
  if (isNamespaceLoaded("quanteda")) {
    quanteda_print <- getFromNamespace("print.corpus", "quanteda")
    return(quanteda_print(x, ...))
  }

  ndoc <- length(x)
  ntoken <- sum(lengths(strsplit(as.character(x), "\\s+")))

  cat("Corpus consisting of ", ndoc, " document",
      if (ndoc != 1) "s" else "", ".\n", sep = "")

  # Get docvars if present
  docvars <- attr(x, "docvars")
  if (!is.null(docvars) && ncol(docvars) > 3) {
    # Skip internal quanteda docvars (docname_, docid_, segid_)
    user_docvars <- setdiff(names(docvars), c("docname_", "docid_", "segid_"))
    if (length(user_docvars) > 0) {
      cat("\nDocvars: ", paste(user_docvars, collapse = ", "), "\n", sep = "")
    }
  }

  # Show first few documents
  if (ndoc > 0) {
    cat("\n")
    show_n <- min(2, ndoc)
    doc_names <- names(x)
    if (is.null(doc_names)) doc_names <- paste0("text", seq_len(ndoc))

    for (i in seq_len(show_n)) {
      doc_text <- as.character(x[i])
      # Truncate long documents
      if (nchar(doc_text) > 70) {
        doc_text <- paste0(substr(doc_text, 1, 67), "...")
      }
      cat(doc_names[i], ": ", doc_text, "\n", sep = "")
    }

    if (ndoc > show_n) {
      cat("[ ... and ", ndoc - show_n, " more document",
          if (ndoc - show_n != 1) "s" else "", " ]\n", sep = "")
    }
  }

  invisible(x)
}

#' Subset method for corpus objects
#'
#' @param x a corpus object
#' @param i index for subsetting
#' @param ... additional arguments
#' @keywords internal
`[.corpus` <- function(x, i, ...) {
  # If quanteda is loaded, defer to its method
  if (isNamespaceLoaded("quanteda")) {
    quanteda_subset <- getFromNamespace("[.corpus", "quanteda")
    return(quanteda_subset(x, i, ...))
  }

  # Basic subsetting that preserves corpus structure
  result <- unclass(x)[i]

  # Preserve corpus class
  class(result) <- "corpus"

  # Subset docvars if present
  docvars <- attr(x, "docvars")
  if (!is.null(docvars)) {
    attr(result, "docvars") <- docvars[i, , drop = FALSE]
  }

  # Preserve meta attribute
  attr(result, "meta") <- attr(x, "meta")

  result
}
