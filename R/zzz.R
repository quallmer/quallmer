.onLoad <- function(libname, pkgname) {
  # Only register corpus print methods if quanteda is not already loaded
  # This avoids conflicts when quanteda is loaded before quallmer
  if (!isNamespaceLoaded("quanteda")) {
    registerS3method("print", "corpus", print.corpus, envir = asNamespace(pkgname))
    registerS3method("[", "corpus", `[.corpus`, envir = asNamespace(pkgname))
  }
}
