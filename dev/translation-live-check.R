# Run from the package root with source("dev/translation-live-check.R").
# Makes real DeepL calls (about 6,000 source characters). Uses DEEPL_API_KEY,
# falling back automatically to keyring::key_get("deepl"). No key is saved.
pkgload::load_all(".")
library(quanteda)
stopifnot(requireNamespace("quanteda", quietly = TRUE))

french_texts <- c(
  housing = paste0(
    "Le conseil municipal a adopté un programme de rénovation de 240 logements. ",
    "Les travaux commenceront en janvier et les loyers resteront inchangés.\n\n",
    "Les associations de locataires demandent toutefois un calendrier précis ",
    "et des garanties pour les personnes qui devront déménager temporairement."
  ),
  research = paste0(
    "Notre équipe utilise quanteda pour comparer les discours électoraux ",
    "dans plusieurs pays. Les textes sont conservés dans leur langue ",
    "d'origine, puis traduits avec quallmer.\n\n",
    "Chaque traduction doit garder son identifiant et les informations ",
    "sur sa source. Une vérification humaine reste nécessaire pour les ",
    "expressions ambiguës et les références culturelles."
  ),
  transport = paste0(
    "À partir du 15 mars, la ligne de bus 12 circulera toutes les dix minutes ",
    "aux heures de pointe. Le prix du billet restera fixé à 2,50 euros. ",
    "Les voyageurs pourront consulter les nouveaux horaires sur le site ",
    "de la ville ; les arrêts provisoires seront signalés sur place."
  )
)

english <- qlm_translate(
  french_texts,
  model = "deepl/quality_optimized",
  source_lang = "fr", target_lang = "en-GB",
  protect = "quanteda|quallmer",
  context = "Public policy and social science research texts.",
  on_error = "stop"
)
english_corpus <- quanteda::corpus(english)
english_provenance <- attr(english, "provenance")
stopifnot(
  inherits(english, "qlm_translation"),
  identical(names(english), names(french_texts)),
  all(english_provenance$status == "ok"),
  identical(english_provenance$source_text, unname(french_texts)),
  ncol(quanteda::docvars(english_corpus)) == 0L,
  grepl("quanteda", as.character(english)["research"], fixed = TRUE),
  grepl("quallmer", as.character(english)["research"], fixed = TRUE),
  identical(
    stringi::stri_count_fixed(as.character(english), "\n\n"),
    stringi::stri_count_fixed(french_texts, "\n\n")
  )
)

speeches <- quanteda::data_corpus_inaugural[
  c("1793-Washington", "1865-Lincoln")
]
quanteda::meta(speeches, "project") <- "Translation integration check"
quanteda::meta(speeches, "quallmer") <- list(note = "Keep this existing entry")
french <- qlm_translate(
  speeches,
  model = "deepl/quality_optimized",
  source_lang = "en", target_lang = "fr",
  context = "Historical inaugural addresses by presidents of the United States.",
  on_error = "stop"
)
french_corpus <- quanteda::corpus(french)
french_provenance <- quanteda::meta(french_corpus, "quallmer")$translation
original_meta <- quanteda::meta(speeches, type = "user")
translated_meta <- quanteda::meta(french_corpus, type = "user")
translated_meta$quallmer$translation <- NULL
translated_meta$quallmer$coding <- NULL
stopifnot(
  all(french_provenance$status == "ok"),
  identical(names(french), names(speeches)),
  identical(attr(french_corpus, "docvars"), attr(speeches, "docvars")),
  identical(quanteda::meta(french_corpus, type = "system"),
            quanteda::meta(speeches, type = "system")),
  identical(translated_meta, original_meta),
  identical(french_provenance$source_text, unname(as.character(speeches))),
  identical(
    stringi::stri_count_fixed(as.character(french), "\n\n"),
    stringi::stri_count_fixed(as.character(speeches), "\n\n")
  )
)

french_tokens <- quanteda::tokens(french_corpus, remove_punct = TRUE)
lincoln <- quanteda::corpus_subset(french_corpus, President == "Lincoln")
stopifnot(
  quanteda::ndoc(french_tokens) == 2L,
  all(quanteda::ntoken(french_tokens) > 0L),
  identical(quanteda::docvars(french_tokens), quanteda::docvars(speeches)),
  identical(quanteda::meta(french_tokens, "quallmer")$translation,
            french_provenance),
  identical(names(lincoln), "1865-Lincoln"),
  "1865-Lincoln" %in% quanteda::meta(lincoln, "quallmer")$translation$.id
)

# Keep these objects in the interactive session for inspection.
print(as.character(english))
print(as.character(french))
print(quanteda::docvars(french_corpus))
print(english_provenance[c(".id", "status", "reported_model",
                           "detected_language")])
print(french_provenance[c(".id", "status", "reported_model",
                          "detected_language")])
cat("\nAll live translation and metadata checks passed.\n")
