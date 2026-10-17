# Run from the package root with source("dev/translation-chat-live-check.R").
# Makes real OpenAI calls through qlm_code() (about 3,000 source characters).
# Uses OPENAI_API_KEY; set QUALLMER_CHAT_MODEL to try another chat model.
pkgload::load_all(".")

model <- Sys.getenv("QUALLMER_CHAT_MODEL", "openai/gpt-4.1-mini")
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
    "sur sa source.\n\n",
    "Une vérification humaine reste nécessaire pour les ",
    "expressions ambiguës et les références culturelles."
  ),
  transport = paste0(
    "À partir du 15 mars, la ligne de bus 12 circulera toutes les dix minutes ",
    "aux heures de pointe. Le prix du billet restera fixé à 2,50 euros."
  )
)

# Whole documents per request, then a small budget that forces several
# groups per document and passes the preceding text as context.
runs <- list(
  whole = qlm_translate(french_texts, model = model, source_lang = "fr",
    target_lang = "en-GB", protect = c("quanteda", "quallmer"),
    context = "Public policy and social science research texts.", on_error = "stop"),
  grouped = qlm_translate(french_texts, model = model, source_lang = "fr",
    target_lang = "en-GB", protect = c("quanteda", "quallmer"),
    chunk_size = 120, on_error = "stop")
)

for (name in names(runs)) {
  out <- runs[[name]]
  provenance <- attr(out, "provenance")
  attempts <- do.call(rbind, provenance$attempts)
  stopifnot(
    inherits(out, "qlm_translation"),
    identical(names(out), names(french_texts)),
    all(provenance$status == "ok"),
    grepl("quanteda", out[["research"]], fixed = TRUE),
    grepl("quallmer", out[["research"]], fixed = TRUE),
    identical(
      lengths(regmatches(as.character(out), gregexpr("\n\n", as.character(out), fixed = TRUE))),
      lengths(regmatches(french_texts, gregexpr("\n\n", french_texts, fixed = TRUE)))
    )
  )
  requests <- sum(!is.na(attempts$input_tokens))
  cat("\n==", name, "-", requests, "request(s) for", nrow(attempts), "segment attempt(s)\n")
  print(as.character(out))
}
stopifnot(
  any(!is.na(do.call(rbind, attr(runs$grouped, "provenance")$attempts)$neighbouring_context))
)
cat("\nAll live chat translation checks passed.\n")
