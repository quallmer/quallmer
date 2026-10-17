# Run from the package root: source("dev/translation-udhr-live-check.R").
# Translates six complete UDHR documents (about 61,000 source characters).
# Makes real DeepL calls. Uses DEEPL_API_KEY or the saved "deepl" keyring key.
# quanteda.corpora is needed only for this manual example, not by quallmer.
pkgload::load_all(".")
library(quanteda)
stopifnot(
  requireNamespace("quanteda", quietly = TRUE),
  requireNamespace("quanteda.corpora", quietly = TRUE)
)

udhr_ids <- c("deu_1996", "fra", "spa", "cmn_hans", "hin", "rus")
expected_languages <- c("DE", "FR", "ES", "ZH", "HI", "RU")
udhr <- quanteda.corpora::data_corpus_udhr[udhr_ids]

# Keep complete documents, including headings. DeepL now sees each document
# together, so a short heading is no longer detected independently.
udhr_texts <- as.character(udhr)
udhr_sample <- udhr

# from is deliberately omitted: each document can be a different language.
udhr_english <- qlm_translate(
  udhr_sample,
  model = "deepl/quality_optimized",
  to = "en-GB",
  context = "Universal Declaration of Human Rights.",
  on_error = "stop"
)
udhr_provenance <- attr(udhr_english, "provenance")
udhr_corpus <- quanteda::corpus(udhr_english)
print(data.frame(
  document = udhr_ids,
  language = quanteda::docvars(udhr_sample)$Name,
  source_characters = nchar(udhr_texts),
  detected_language = udhr_provenance$detected_language,
  status = udhr_provenance$status,
  row.names = NULL
))
translated_user_meta <- quanteda::meta(udhr_corpus, type = "user")
translated_user_meta$quallmer <- NULL
stopifnot(
  identical(names(udhr_english), udhr_ids),
  all(udhr_provenance$status == "ok"),
  all(is.na(udhr_provenance$source_lang)),
  identical(unname(udhr_provenance$detected_language), expected_languages),
  identical(udhr_provenance$source_text, unname(udhr_texts)),
  all(nzchar(as.character(udhr_english))),
  identical(attr(udhr_corpus, "docvars"), attr(udhr_sample, "docvars")),
  identical(quanteda::meta(udhr_corpus, type = "system"),
            quanteda::meta(udhr_sample, type = "system")),
  identical(translated_user_meta, quanteda::meta(udhr_sample, type = "user")),
  identical(
    stringi::stri_count_fixed(as.character(udhr_english), "\n\n"),
    stringi::stri_count_fixed(udhr_texts, "\n\n")
  )
)
udhr_tokens <- quanteda::tokens(udhr_corpus)
stopifnot(
  all(quanteda::ntoken(udhr_tokens) > 0L),
  identical(quanteda::docvars(udhr_tokens), quanteda::docvars(udhr_sample))
)

print(udhr_english)
cat("\nAll six language-detection and corpus metadata checks passed.\n")
