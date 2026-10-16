# Run from the package root. Makes real, billed requests for six full documents.
# Save the API key once with keyring::key_set("google-translate"), or set
# GOOGLE_TRANSLATE_API_KEY. Set GOOGLE_CLOUD_PROJECT to your project ID.
pkgload::load_all(".")
library(quanteda)

udhr_ids <- c("deu_1996", "fra", "spa", "cmn_hans", "hin", "rus")
udhr <- quanteda.corpora::data_corpus_udhr[udhr_ids]
google_timing <- system.time(
  google_translated <- qlm_translate(
    udhr, model = "google-translate/translation-llm",
    target_lang = "en-GB", on_error = "continue"
  )
)
google_provenance <- qlm_meta(google_translated, "quallmer")$translation
google_corpus <- quanteda::corpus(google_translated)
print(google_timing)
print(google_provenance[c(".id", "status", "detected_language", ".error", "reported_model")])
google_user_meta <- quanteda::meta(google_corpus, type = "user")
google_user_meta$quallmer <- NULL
stopifnot(
  all(google_provenance$status == "ok"),
  identical(google_translated$.id, udhr_ids),
  identical(google_provenance$source_text, unname(as.character(udhr))),
  identical(attr(google_corpus, "docvars"), attr(udhr, "docvars")),
  identical(quanteda::meta(google_corpus, type = "system"),
            quanteda::meta(udhr, type = "system")),
  identical(google_user_meta, quanteda::meta(udhr, type = "user")),
  all(nzchar(as.character(google_translated))),
  all(quanteda::ntoken(quanteda::tokens(google_corpus)) > 0L)
)
print(google_translated)
