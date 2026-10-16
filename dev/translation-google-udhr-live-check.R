# Run from the package root. Executes the article's actual six-document example
# against Google (billed), then saves its rendered HTML and translated object.
# Uses GOOGLE_TRANSLATE_API_KEY or the optional "google-translate" keyring key.
# Set GOOGLE_CLOUD_PROJECT before running. No credentials are saved or printed.
pkgload::load_all(".")
stopifnot(
  requireNamespace("quanteda", quietly = TRUE),
  requireNamespace("quanteda.corpora", quietly = TRUE),
  requireNamespace("rmarkdown", quietly = TRUE),
  nzchar(Sys.getenv("GOOGLE_CLOUD_PROJECT"))
)

google_article_path <- normalizePath(
  "vignettes/pkgdown/examples/example_translation_google.Rmd"
)
google_article_dir <- getOption("quallmer.google_article_output_dir",
                               tempfile("quallmer-google-article-"))
dir.create(google_article_dir, recursive = TRUE, showWarnings = FALSE)
google_article_env <- new.env(parent = globalenv())
google_article_html <- rmarkdown::render(
  google_article_path,
  params = list(live = TRUE),
  output_dir = google_article_dir,
  envir = google_article_env,
  quiet = TRUE
)

# Keep the results available for interactive inspection and reuse.
google_translated <- google_article_env$google_translated
google_provenance <- google_article_env$google_provenance
google_corpus <- google_article_env$google_corpus
google_timing <- google_article_env$google_timing
google_results_file <- file.path(google_article_dir, "udhr-google-english.rds")
saveRDS(google_translated, google_results_file)
if (isTRUE(getOption("quallmer.update_google_article_cache", FALSE))) {
  # Publish actual results without publishing the caller's project identifiers.
  google_cache <- google_translated
  google_cache_meta <- quallmer:::redact_meta(attr(google_cache, "meta"))
  google_cache_provenance <- google_cache_meta$user$quallmer$translation
  google_cache_provenance$settings <- lapply(google_cache_provenance$settings, function(settings) {
    settings$project_id <- "your-project-id"
    settings$google_model <- sub("^projects/[^/]+/", "projects/your-project-id/", settings$google_model)
    settings
  })
  google_cache_meta$user$quallmer$translation <- google_cache_provenance
  attr(google_cache, "meta") <- google_cache_meta
  google_cache_path <- file.path(dirname(google_article_path), "data", "translated_udhr_google.rds")
  saveRDS(google_cache, google_cache_path, compress = "xz")
  cat("Updated article fixture: ", google_cache_path, "\n", sep = "")
}
print(google_timing)
print(google_provenance[c(".id", "status", "detected_language", ".error", "reported_model")])
cat("\nAll six article translations and corpus checks passed.\n")
cat("Live HTML: ", google_article_html, "\n", sep = "")
cat("Saved translation: ", google_results_file, "\n", sep = "")
