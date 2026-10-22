#' Translate texts
#'
#' `r lifecycle::badge("experimental")`
#'
#' Translates texts and returns them as a named character vector carrying
#' per-document translation provenance, as [qlm_transcribe()] does for
#' transcripts. The result can be passed to [qlm_code()]; [qlm_trail()] then
#' records translation as part of the coding instrument.
#'
#' @param x Character vector of texts, optionally named, or a quanteda corpus.
#'   A transcript from [qlm_transcribe()] or an earlier translation can also be
#'   translated, and its history is kept. Names must be unique and non-empty.
#'   Missing texts are recorded as failures without a request.
#' @param model The provider and model, as `"provider/model"`; required. See
#'   "Providers" for the translation services; any other [ellmer::chat()]
#'   model translates through [qlm_code()].
#' @param to Target language, as a BCP 47 language tag such as
#'   `"en"`, `"en-GB"`, `"pt-BR"` or `"zh-Hant"`: one tag for all texts, or
#'   one for each text, as when translating translations back into their
#'   source languages. See "Language codes".
#' @param from Source language, as a BCP 47 language tag: one tag for all
#'   texts, or one for each text, such as the `ISO` document variable of a
#'   multilingual corpus. `NULL`, or `NA` for a text, leaves the provider to
#'   detect that text's language. Set it whenever you know it: see
#'   "Unsupported languages".
#' @param instructions Character vector of translation directives, such as a
#'   register to use or how to treat names.
#' @param context One string of background about the texts, to inform the
#'   translation but not to be translated.
#' @param glossary Named character vector of source terms and their required
#'   translations, such as `c(Bundestag = "Bundestag")`.
#' @param protect Character vector of regular expressions matching text to
#'   keep exactly as it is, such as names or codes. Each is matched against
#'   the whole text, so a match may span paragraphs and `^` means the start
#'   of the text. Matches must not overlap or be empty; every one is checked
#'   in the translation.
#' @param params Generation settings from [ellmer::params()], such as
#'   `temperature` or `max_tokens`.
#' @param chunk_size The most source characters in one request, or `NULL` for
#'   the provider's default. Characters only estimate tokens: a response cut
#'   off at the output limit is detected and sent again in smaller parts.
#' @param adapter `NULL` to choose how requests are made from `model`, or
#'   `"generic"` to send a recognised translation model the ordinary chat
#'   request instead.
#' @param api_key An API key, or `NULL` to use the provider's environment
#'   variable or saved key (see "API keys"). Keys are never recorded.
#' @param base_url Optional API base URL, recorded with any credentials in it
#'   removed.
#' @param max_active Maximum concurrent requests, or `NULL` for the provider's
#'   default.
#' @param rpm Maximum requests per minute.
#' @param on_error Failure policy: `"continue"` attempts every text,
#'   `"return"` stops sending after a failure, and `"stop"` raises it.
#' @param ... Named arguments specific to the provider; see "Providers". Any
#'   other name is an error.
#'
#' @details
#' ## Providers
#'
#' `to`, `from` and `protect` work the same for every
#' provider. The other arguments depend on it; where a provider cannot honour
#' one, using it is an error rather than being ignored.
#'
#' | | DeepL | Qwen-MT | Google Translation LLM | Chat models |
#' |:--|:--|:--|:--|:--|
#' | `model` | `"deepl/"` and `quality_optimized`, `latency_optimized` or `prefer_quality_optimized` | `"dashscope/"` and `qwen-mt-plus`, `qwen-mt-flash` or `qwen-mt-lite` | `"google-translate/translation-llm"` | any [ellmer::chat()] model |
#' | `instructions` | at most 10, of at most 300 characters each | yes | error | yes |
#' | `context` | yes | yes | error | yes |
#' | `glossary` | error: not yet implemented | yes | error | yes |
#' | `params` | error | `temperature`, `top_p`, `top_k`, `seed`, `max_tokens` | error | any |
#' | `...` | `formality`: `"default"`, `"more"`, `"less"`, `"prefer_more"` or `"prefer_less"` | none | `project_id` (default: `GOOGLE_CLOUD_PROJECT`); `region` (default `"us-central1"`) | passed to [ellmer::chat()], e.g. `api_args` |
#' | One request | up to 50 whole documents of one language pair | adjacent paragraphs of one document | one document | adjacent paragraphs of one document |
#' | `chunk_size` default | 16,000 | 4,000 | 30,000, Google's limit | 8,000, or `2 * params$max_tokens` if smaller |
#' | `max_active` default | 2 | 2 | 2 | 10 |
#' | API key | `DEEPL_API_KEY`, or keyring `"deepl"` | `DASHSCOPE_API_KEY` | `GOOGLE_TRANSLATE_API_KEY`, or keyring `"google-translate"` | the provider's, through ellmer |
#' | Also recorded | detected language, model type used, billed characters | model, tokens | detected language, model | tokens, cost |
#'
#' DeepL model types express a quality or speed goal, not a fixed model
#' version. Google's `region` selects the model's location, but the Basic API
#' uses a global endpoint, so it does not guarantee where data is processed.
#' For chat models the answering model version is not yet recorded
#' ([#199](https://github.com/quallmer/quallmer/issues/199)). Arguments
#' passed to a chat model through `...` are recorded by name only, since they
#' can carry credentials.
#'
#' ## Language codes
#'
#' `to` and `from` take BCP 47 language tags: an ISO 639
#' language code (`"fr"`), optionally followed by an ISO 15924 script
#' (`"zh-Hant"`) and an ISO 3166 region or UN M.49 area (`"pt-BR"`,
#' `"es-419"`). A plain language code is usually what you want; add a region
#' only for a regional variant of the target. W3C's
#' [Choosing a language tag](https://www.w3.org/International/questions/qa-choosing-language-tags)
#' explains the parts, and the
#' [Language Subtag Lookup](https://r12a.github.io/app-subtags/) finds the tag
#' for a language. Case does not matter, and an underscore may be used for a
#' hyphen.
#'
#' A three-letter ISO 639-3 code, such as the `ISO` document variable of
#' `quanteda.corpora::data_corpus_udhr` holds, is replaced by its two-letter
#' ISO 639-1 code where there is one (`fra` becomes `fr`, `deu` becomes `de`,
#' and `cmn`, Mandarin, becomes `zh`). Any other is passed on as it is, so
#' that a provider that does not support the language says so instead of
#' guessing.
#'
#' Each provider spells some languages differently, so the tag is converted
#' to the provider's own code, and the provenance records both for each text
#' (`settings$provider_languages`). For Chinese, an explicit script decides
#' between Simplified and Traditional (`zh-Hans-HK` is Simplified); a region
#' only supplies the usual script when none is given (`zh-TW` is
#' Traditional).
#'
#' * DeepL takes regional variants only as targets, and only `en-GB`,
#'   `en-US`, `fr-CA`, `fr-FR`, `de-DE`, `de-CH`, `pt-BR`, `pt-PT`, `es-ES`,
#'   `es-419`, `zh-Hans` and `zh-Hant`; any other is an error before any
#'   request. A source is reduced to its language. `zh-CN` and `zh-TW` become
#'   `ZH-HANS` and `ZH-HANT`, `no` becomes `NB`, and `fil` becomes `TL`.
#' * Google Translation LLM: `zh-CN` and `zh-TW` become `zh-Hans` and
#'   `zh-Hant`, and `tl` becomes `fil`.
#' * Qwen-MT takes language codes only, with `zh_tw` for Traditional
#'   Chinese; a regional variant such as `en-GB` is requested in its
#'   instructions instead.
#' * Chat models receive the tag as given.
#'
#' ## Unsupported languages
#'
#' Language detection fails silently. Given text in a language it does not
#' support, every provider tested, DeepL, Google, Qwen-MT and a chat model,
#' returned a fluent but invented English text, recorded as `"ok"`; DeepL and
#' Google reported a wrong detected language (Swahili for Kimbundu). With
#' `from` set, DeepL, Google and Qwen-MT instead refuse an unsupported
#' language, and the text is `NA` with the provider's reason. Chat models do
#' not refuse, and may invent a translation even when told the source
#' language.
#'
#' So set `from` whenever the source language is known, and when it is
#' not, check the recorded `detected_language` against what you expect. For a
#' corpus in several languages, pass one tag for each text, for example
#' `from = quanteda::docvars(corpus, "ISO")`; use `NA` for a text whose
#' language you do not know. DeepL packs the texts of each language pair into
#' requests of their own. Results that look fluent are not evidence of a
#' correct translation.
#'
#' ## API keys
#'
#' * DeepL: see [access and authentication](https://developers.deepl.com/docs/getting-started/auth).
#'   A key ending in `:fx` uses the Free API host.
#' * Qwen-MT: see [Model Studio API keys](https://www.alibabacloud.com/help/en/model-studio/get-api-key).
#'   The key must match the endpoint's region.
#' * Google: see [Cloud Translation setup](https://docs.cloud.google.com/translate/docs/setup).
#'   Enable billing and the Cloud Translation API for the project, and create
#'   an API key allowed to call it.
#' * Chat models: see the [ellmer provider documentation](https://ellmer.tidyverse.org/reference/index.html).
#'
#' Where the table names a keyring entry, a key saved once with, for example,
#' `keyring::key_set("deepl")` is used when the environment variable is unset;
#' this needs the optional \pkg{keyring} package and may prompt to unlock the
#' system store. An explicit `api_key` overrides both.
#'
#' ## Paragraphs, retries and failures
#'
#' Paragraphs are separated by blank lines. The separators, and whitespace at
#' the start and end of each paragraph, are kept aside and restored exactly.
#' DeepL, Qwen-MT and chat models are told where each paragraph begins, and a
#' response that loses, merges or reorders paragraphs is sent again in
#' smaller parts. Google receives each document whole and handles paragraph
#' formatting itself, so exact separators are not guaranteed there. Text
#' longer than `chunk_size` is split at sentence ends, else at spaces, else
#' between characters.
#'
#' A response that is malformed or changes a protected term is retried once,
#' and one cut off at the output limit is sent again in smaller parts. A
#' document with any part that still fails is `NA`, never a partial
#' translation, and its error says why. Every attempt, with its usage, is
#' recorded in the provenance (`attempts`). The provenance records the
#' settings requested, not a guarantee that the provider applied them. Save
#' the result with [saveRDS()] to keep the exact translations used for
#' coding.
#'
#' @return A `qlm_translation`: a character vector of translations named by
#'   document, with `NA` for each translation that failed or was not
#'   submitted. Its `"provenance"` attribute is a data frame with one row per
#'   text: the source text and its hash, the output hash, requested and
#'   reported models, languages, adapter, settings, status, error, timestamp,
#'   any earlier preprocessing history, and `attempts`: for each text, a data
#'   frame with one row per request attempt, giving the segment, any error,
#'   the reductions made, and usage (tokens and cost, or DeepL's billed
#'   characters).
#'
#'   Subsetting with `[`, renaming, and `c()` keep the provenance aligned.
#'   Assigning plain text records an edit; assigning another
#'   `qlm_translation`, such as a retry of failed texts, carries its
#'   provenance. `as.character()` drops the provenance, and [inputs()] returns
#'   the source texts.
#'
#'   For a corpus input, the document variables and metadata are kept, and
#'   `quanteda::corpus(x)` (see [corpus.qlm_translation()]) returns a corpus of
#'   the translated texts with them restored.
#' @examples
#' \dontrun{
#' # Reads DEEPL_API_KEY, or supply api_key = keyring::key_get("deepl")
#' translated <- qlm_translate(c(speech = "Bonjour tout le monde."),
#'   model = "deepl/quality_optimized", to = "en-GB")
#' coded <- qlm_code(translated, data_codebook_sentiment,
#'   model = "openai/gpt-4o-mini")
#' qlm_trail(coded, path = "translation_trail")
#'
#' texts <- c(fr = "Bonjour tout le monde.", de = "Guten Morgen.")
#'
#' # Qwen-MT: reads DASHSCOPE_API_KEY for the Singapore endpoint
#' translated_qwen <- qlm_translate(texts,
#'   model = "dashscope/qwen-mt-plus", to = "en-GB",
#'   context = "Greetings in everyday conversation.",
#'   params = ellmer::params(temperature = 0.1))
#' translated_qwen
#'
#' # Google: reads GOOGLE_TRANSLATE_API_KEY, falling back to the optional
#' # keyring entry saved with keyring::key_set("google-translate")
#' translated_google <- qlm_translate(texts,
#'   model = "google-translate/translation-llm", to = "en-GB",
#'   project_id = "your-google-cloud-project-id")
#' # Alternatively, set GOOGLE_CLOUD_PROJECT and omit project_id.
#' attr(translated_google, "provenance")
#'
#' # DeepL with a formal register
#' qlm_translate(texts, model = "deepl/quality_optimized", formality = "more")
#'
#' # A multilingual corpus, with each text's language as ISO 639-3 codes
#' qlm_translate(texts, model = "deepl/quality_optimized", from = c("fra", "deu"))
#'
#' # Convert to a quanteda corpus, if quanteda is installed
#' quanteda::corpus(translated_google)
#' }
#' @export
qlm_translate <- function(x, model, to = "en", from = NULL,
                          instructions = NULL, context = NULL, glossary = NULL,
                          protect = NULL, params = NULL, chunk_size = NULL,
                          adapter = NULL, api_key = NULL, base_url = NULL,
                          max_active = NULL, rpm = 60,
                          on_error = c("continue", "return", "stop"), ...) {
  provider_args <- list(...)
  if (length(provider_args) &&
      (is.null(names(provider_args)) || any(!nzchar(names(provider_args))) ||
       anyDuplicated(names(provider_args)))) {
    cli::cli_abort("Arguments in {.arg ...} must be named, once each.")
  }
  on_error <- rlang::arg_match(on_error)
  if (!is.character(x) || !length(x)) {
    cli::cli_abort("{.arg x} must be a non-empty character vector of texts.")
  }
  if (missing(model) || !rlang::is_string(model) || !nzchar(model)) {
    cli::cli_abort("Supply {.arg model} as a single provider/model string.")
  }
  for (arg in c("context", "adapter", "api_key", "base_url")) {
    check_optional_string(get(arg), arg)
  }
  if (is.null(to)) {
    cli::cli_abort(c("{.arg to} is required.", language_tag_help))
  }
  # The provenance and the providers' requests call these target_lang and
  # source_lang, as the translation APIs do. Each has one value per text.
  target_lang <- translation_language_vector(to, "to", length(x), allow_missing = FALSE)
  source_lang <- translation_language_vector(from, "from", length(x), allow_missing = TRUE)
  check_translation_strings(instructions, "instructions")
  check_translation_strings(protect, "protect")
  check_translation_strings(glossary, "glossary")
  if (!is.null(glossary)) {
    if (!length(names(glossary))) {
      cli::cli_abort("{.arg glossary} must be a named character vector.")
    }
    check_ids(names(glossary), what = "The names of {.arg glossary}")
  }
  if (!is.null(params) && (!is.list(params) ||
      (length(params) && (is.null(names(params)) || any(!nzchar(names(params))))))) {
    cli::cli_abort("{.arg params} must be a named list from {.fn ellmer::params}.")
  }
  if (!is.null(max_active) && !is_count(max_active, 1L)) {
    cli::cli_abort("{.arg max_active} must be a positive whole number.")
  }
  if (!is_count(rpm, 1L)) {
    cli::cli_abort("{.arg rpm} must be a positive whole number.")
  }
  if (!is.null(chunk_size) && !is_count(chunk_size, 1L)) {
    cli::cli_abort("{.arg chunk_size} must be a positive whole number.")
  }
  ids <- names(x) %||% paste0("text", seq_along(x))
  check_ids(ids, what = "The names of {.arg x}")
  corpus_attributes <- translation_corpus_attributes(x)
  history <- preprocessing_history(x)
  input_errors <- if (is_qlm_preprocessed(x)) {
    attr(x, "provenance")$.error
  } else rep(NA_character_, length(x))
  source <- translation_texts(x)
  if (anyNA(source) && on_error == "stop") {
    cli::cli_abort("Translation failed: source text is missing.")
  }
  selected <- translation_adapter(model, adapter, base_url, api_key,
                                  credentials = provider_args$credentials)
  provider_args <- check_provider_args(provider_args, selected$name)
  # The translation APIs rate-limit concurrent requests more tightly than
  # chat endpoints do.
  max_active <- max_active %||% if (selected$name == "generic") 10L else 2L
  if (selected$name == "generic") {
    extra <- provider_args[setdiff(names(provider_args), names(selected$chat_args))]
    selected$chat_args <- c(selected$chat_args, extra)
  }
  if (selected$name == "deepl") {
    if (length(params)) cli::cli_abort("{.arg params} is not supported by DeepL.")
    if (!is.null(glossary)) {
      cli::cli_abort("Native DeepL {.arg glossary} is not implemented yet.")
    }
    if (length(instructions) > 10L || any(nchar(instructions) > 300L)) {
      cli::cli_abort("DeepL accepts at most 10 instructions of at most 300 characters each.")
    }
  }
  size <- chunk_size %||% switch(selected$name, deepl = 16000L,
                                `google-translate` = 30000L, `qwen-mt` = 4000L, 8000L)
  if (selected$name == "generic" && !is.null(params$max_tokens)) {
    if (!is_count(params$max_tokens, 1L)) {
      cli::cli_abort("{.arg params$max_tokens} must be a positive whole number.")
    }
    # A translation is about as long as its source. Two characters per token
    # leaves room for scripts that need more tokens, and for the JSON the
    # translations come back in; truncation is detected if it is too few.
    if (is.null(chunk_size)) size <- min(size, 2L * params$max_tokens)
  }
  settings <- list(instructions = instructions, context = context, protect = protect,
                   glossary = glossary, params = params,
                   chunk_size = size, template_version = 4L,
                   text_unit = switch(selected$name, deepl = "document",
                                      "paragraph_group"),
                   ellmer_version = as.character(utils::packageVersion("ellmer")))
  # Provider arguments are recorded with their values, except those passed to
  # a chat model, which can carry credentials: only their names are kept.
  settings$provider_args <- if (selected$name == "generic") {
    names(provider_args)
  } else provider_args
  if (selected$name == "deepl") settings$formality <- provider_args$formality
  if (selected$name == "qwen-mt") {
    settings$group_max_bytes <- 6000L
    settings$paragraph_alignment <- "boundary_markers"
  }
  if (selected$name == "google-translate") {
    settings <- translation_google_settings(settings, provider_args$project_id,
                                            provider_args$region %||% "us-central1")
    size <- settings$chunk_size
  }
  # Languages are checked once for each distinct pair, before any request;
  # the settings recorded for a text carry its own languages.
  languages <- translation_document_languages(selected$name, target_lang, source_lang)
  # All local splitting/protection validation finishes before building a key-
  # bearing request. Missing input is carried into the output without a call.
  plans <- if (selected$name == "google-translate") {
    Map(translation_google_plan, source, languages, MoreArgs = list(settings = settings))
  } else lapply(source, translation_plan, size = size, protect = protect)
  setup <- translation_setup(selected, settings, api_key, base_url, rpm)
  setup$languages <- languages
  result <- run_translation_plans(plans, setup, max_active, rpm, on_error)
  provenance <- data.frame(
    .id = ids, status = result$status, .error = result$error,
    source_text = unname(source), source_hash = vapply(source, translation_hash, "", USE.NAMES = FALSE),
    output_hash = vapply(result$text, translation_hash, "", USE.NAMES = FALSE), model = model,
    reported_model = vapply(result$attempts, translation_reported_models, ""),
    source_lang = source_lang, target_lang = target_lang,
    detected_language = vapply(result$attempts, translation_detected_languages, ""),
    adapter = selected$name, adapter_selection = if (is.null(adapter)) "automatic" else "explicit",
    base_url = setup$recorded_base_url %||% NA_character_, timestamp = Sys.time(),
    stringsAsFactors = FALSE
  )
  missing_input <- is.na(source)
  provenance$.error[missing_input] <- ifelse(
    is.na(input_errors[missing_input]), "source text is missing", input_errors[missing_input]
  )
  provenance$settings <- lapply(languages, function(language) {
    c(language, settings)
  })
  provenance$attempts <- lapply(result$attempts, translation_attempts_table)
  provenance$history <- history
  out <- new_qlm_translation(result$text, provenance, corpus_attributes)
  failed <- provenance$status == "failed"
  if (any(failed)) {
    cli::cli_warn(c("{sum(failed)} of {length(source)} translation{?s} failed.",
                   set_bullets(unique(provenance$.error[failed]))))
  }
  out
}

# The arguments `...` accepts for each provider. A chat model's go on to
# qlm_code() and ellmer's chat(), as in a coding run, except qlm_code()'s own
# and those the translation sets itself.
provider_arg_names <- list(
  deepl = "formality",
  `google-translate` = c("project_id", "region"),
  `qwen-mt` = character()
)

check_provider_args <- function(args, adapter) {
  if (!length(args)) {
    return(args)
  }
  label <- switch(adapter, deepl = "DeepL", `google-translate` = "Google Translation",
                  `qwen-mt` = "Qwen-MT", "a chat model")
  if (adapter == "generic") {
    reserved <- c(setdiff(names(formals(qlm_code)), "..."), "include_tokens",
                  "include_cost", "max_active", "rpm", "params")
    bad <- intersect(names(args), reserved)
    if (length(bad)) {
      cli::cli_abort(c(
        "{.arg {bad}} cannot be passed to {label} through {.arg ...}.",
        "i" = "{cli::qty(length(bad))}{.fn qlm_translate} sets {?it/them} itself, or {?it is/they are} a {.fn qlm_code} setting with no meaning for translation."
      ))
    }
    if ("formality" %in% names(args)) {
      cli::cli_abort(c(
        "{.arg formality} is a DeepL argument.",
        "i" = "For a chat model, describe the register in {.arg instructions}."
      ))
    }
    return(args)
  }
  allowed <- provider_arg_names[[adapter]]
  bad <- setdiff(names(args), allowed)
  if (length(bad)) {
    cli::cli_abort(c(
      "{.arg {bad}} {?is not an argument/are not arguments} for {label}.",
      "i" = if (length(allowed)) "{label} accepts {.arg {allowed}} in {.arg ...}." else "{label} accepts no further arguments.",
      "i" = if ("formality" %in% bad) "Describe the register in {.arg instructions} instead."
    ))
  }
  if (!is.null(args$formality)) {
    args$formality <- rlang::arg_match0(args$formality,
      c("default", "more", "less", "prefer_more", "prefer_less"), arg_nm = "formality")
  }
  for (name in intersect(c("project_id", "region"), names(args))) {
    check_optional_string(args[[name]], name)
  }
  args
}

check_translation_strings <- function(x, arg) {
  if (!is.null(x) && (!is.character(x) || !length(x) || anyNA(x) || any(!nzchar(x)))) {
    cli::cli_abort("{.arg {arg}} must be NULL or non-empty character strings without missing values.")
  }
}

translation_hash <- function(x) {
  if (is.na(x)) NA_character_ else digest::digest(enc2utf8(x), algo = "sha256", serialize = FALSE)
}

translation_reported_models <- function(attempts) {
  values <- unique(unlist(lapply(attempts, `[[`, "reported_model")))
  values <- values[!is.na(values)]
  if (length(values)) paste(values, collapse = ", ") else NA_character_
}

translation_detected_languages <- function(attempts) {
  values <- unique(unlist(lapply(attempts, `[[`, "detected_language")))
  values <- values[!is.na(values)]
  if (length(values)) paste(values, collapse = ", ") else NA_character_
}

# One row per request attempt for a document, rather than one list each:
# a list of some 25 scalars per attempt made a translation about 12 times
# the size of its source. Usage is spread over the columns the providers
# share, tokens and cost for chat models and Qwen-MT, billed characters for
# DeepL. The protected-term map is not kept per attempt, since the source
# text and `settings$protect` reproduce it.
translation_attempts_table <- function(attempts) {
  field <- function(name, type, as) {
    vapply(attempts, function(attempt) {
      value <- attempt[[name, exact = TRUE]]
      if (is.null(value) || !length(value)) as(NA) else as(value[[1]])
    }, type)
  }
  usage <- function(keys) {
    vapply(attempts, function(attempt) {
      for (key in keys) {
        value <- attempt$usage[[key, exact = TRUE]]
        if (!is.null(value) && length(value) && !is.na(value[[1]])) return(as.numeric(value[[1]]))
      }
      NA_real_
    }, numeric(1))
  }
  data.frame(
    paragraph = field("paragraph", integer(1), as.integer),
    segment = field("segment", integer(1), as.integer),
    start = field("start", integer(1), as.integer),
    end = field("end", integer(1), as.integer),
    split = field("split", character(1), as.character),
    reduction = field("reduction", integer(1), as.integer),
    group_reduction = field("group_reduction", integer(1), as.integer),
    group_size = field("group_size", integer(1), as.integer),
    finish = field("finish", character(1), as.character),
    error = field("error", character(1), as.character),
    protection_ok = field("protection_ok", logical(1), as.logical),
    reported_model = field("reported_model", character(1), as.character),
    detected_language = field("detected_language", character(1), as.character),
    request_id = field("request_id", character(1), as.character),
    input_tokens = usage(c("input_tokens", "prompt_tokens")),
    output_tokens = usage(c("output_tokens", "completion_tokens")),
    cached_input_tokens = usage("cached_input_tokens"),
    cost = usage("cost"),
    billed_characters = usage("billed_characters"),
    warnings = vapply(attempts, function(attempt) {
      if (length(attempt$warnings)) paste(attempt$warnings, collapse = "\n") else NA_character_
    }, character(1)),
    neighbouring_context = field("neighbouring_context", character(1), as.character),
    timestamp = as.POSIXct(field("timestamp", numeric(1), as.numeric), origin = "1970-01-01"),
    stringsAsFactors = FALSE
  )
}
