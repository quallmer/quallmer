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
#' @param model Required provider/model identifier. DeepL accepts
#'   `"deepl/quality_optimized"`, `"deepl/latency_optimized"` and
#'   `"deepl/prefer_quality_optimized"`. Qwen-MT accepts, for example,
#'   `"dashscope/qwen-mt-plus"`, `"dashscope/qwen-mt-flash"` and
#'   `"dashscope/qwen-mt-lite"`. Google Translation LLM uses
#'   `"google-translate/translation-llm"`. Other models use [ellmer::chat()].
#' @param target_lang Target language code, such as `"en"` or `"en-GB"`.
#' @param source_lang Source language code, or `NULL` for automatic detection.
#' @param instructions Character vector of translation directives. DeepL
#'   accepts at most 10 directives of at most 300 characters each. Qwen-MT
#'   receives these together with `context` as its native domain prompt.
#' @param context One string of background information, not text to translate.
#' @param protect Character vector of regular expressions matching text to
#'   preserve exactly. Matches must not overlap or be empty. Matched text is
#'   masked before splitting and restored only after marker validation.
#' @param glossary Named character vector of source terms and their desired
#'   translations. Qwen-MT uses native terminology options; the generic
#'   adapter uses instructions. Native
#'   DeepL glossaries are not implemented in this initial version.
#' @param adapter `NULL` for automatic selection, or `"generic"`, `"deepl"`,
#'   or `"qwen-mt"`. Exact Qwen-MT plus, flash and lite model IDs select the
#'   native adapter automatically. Google Translation LLM selects
#'   `"google-translate"` automatically; this can also be supplied explicitly.
#' @param params Settings created with [ellmer::params()], passed through on
#'   the chat route. Qwen-MT supports `temperature`, `top_p`, `top_k`, `seed`
#'   and `max_tokens`, rejecting unsupported settings. Non-empty settings are
#'   refused on the DeepL and Google Translation routes.
#' @param chunk_size Positive integer; the most source characters to send in
#'   one request for chat models and Qwen-MT, or in one segment for DeepL and
#'   Google, including protection markers. Defaults to 8000 for chat models,
#'   or twice a supplied `params$max_tokens` if that is smaller; 4000 for
#'   Qwen-MT; 16000 for DeepL; and 30000 for Google, its limit. Characters are
#'   an estimate of tokens: a response cut off at the output limit is
#'   detected and sent again in smaller parts.
#' @param api_key API key, or `NULL` to use the provider's environment variable
#'   (`DEEPL_API_KEY` for DeepL, `DASHSCOPE_API_KEY` for DashScope). If that
#'   variable is unset or empty, DeepL
#'   falls back to `keyring::key_get("deepl")` when the optional \pkg{keyring}
#'   package is installed. Save a key interactively once with
#'   `keyring::key_set("deepl")`. An explicit key overrides both other sources.
#'   Keyring lookup may prompt to unlock the system store. Keys are never
#'   recorded or copied into the environment by this function. Google Translation
#'   uses `GOOGLE_TRANSLATE_API_KEY`, falling back to
#'   `keyring::key_get("google-translate")`; explicit keys take precedence.
#' @param base_url Optional API base URL. DeepL defaults to its Free or Pro
#'   host according to the key. Recorded with URL credentials redacted.
#' @param max_active Maximum concurrent requests, or `NULL` for the provider's
#'   default: 2 for DeepL, Google Translation and Qwen-MT, 10 for chat models.
#' @param rpm Maximum requests per minute. Native translation requests are paced evenly
#'   rather than allowing an initial burst.
#' @param on_error Failure policy: `"continue"` attempts all units,
#'   `"return"` stops new submissions after a failure, and `"stop"` raises it.
#' @param ... Named arguments specific to one provider; any other name is an
#'   error.
#'   * DeepL: `formality`, one of `"default"`, `"more"`, `"less"`,
#'     `"prefer_more"` or `"prefer_less"`.
#'   * Google Translation: `project_id`, the Google Cloud project ID or number,
#'     defaulting to the `GOOGLE_CLOUD_PROJECT` environment variable; and
#'     `region`, the model location, defaulting to `"us-central1"`. The Basic
#'     API uses a global endpoint, so `region` does not guarantee data
#'     residency.
#'   * Qwen-MT: none.
#'   * Chat models: passed on to [ellmer::chat()] through [qlm_code()], as in
#'     a coding run, for example `api_args`. Only their names are recorded.
#'
#'   For a register on other providers, use `instructions`.
#'
#' @details
#' ## API setup and keys
#'
#' Obtain credentials using the provider's setup instructions:
#'
#' * [DeepL: access and authentication](https://developers.deepl.com/docs/getting-started/auth).
#'   Set `DEEPL_API_KEY` or save the key with `keyring::key_set("deepl")`.
#' * [Alibaba Cloud Model Studio: obtain an API key](https://www.alibabacloud.com/help/en/model-studio/get-api-key)
#'   for Qwen-MT. Set `DASHSCOPE_API_KEY`; the key must match the endpoint's region.
#' * [Google Cloud Translation: setup](https://docs.cloud.google.com/translate/docs/setup).
#'   Enable billing and Cloud Translation for the project, and create an API key
#'   that permits Cloud Translation. Set `GOOGLE_TRANSLATE_API_KEY` or save it
#'   with `keyring::key_set("google-translate")`. Supply `project_id` or set
#'   `GOOGLE_CLOUD_PROJECT`.
#'
#' For other chat providers, follow the credential instructions in the
#' corresponding [ellmer provider documentation](https://ellmer.tidyverse.org/reference/index.html).
#'
#' ## Requests and provenance
#'
#' Google Translation LLM uses the Cloud Translation Basic API with one complete
#' document per request, splitting only to meet 30000-character and 100 kB body
#' limits or a smaller `chunk_size`. Paragraph formatting is handled by Google;
#' exact paragraph separator preservation is not guaranteed. Detected source
#' languages are recorded when `source_lang` is omitted. The Basic API does not
#' accept `context`, `instructions`, `glossary` or non-empty `params`;
#' these arguments raise an error rather than being silently ignored.
#'
#' Chat models translate adjacent paragraphs of one document together, up to
#' `chunk_size` characters per request, through [qlm_code()] with a codebook
#' that returns one translation per paragraph ID. Each request also receives
#' the call's `context` and the source text just before the group, both
#' marked as context not to translate. A group whose response is cut off at
#' the output limit, or whose paragraph IDs come back missing, duplicated or
#' unknown, is sent again as two halves, down to single paragraphs. DeepL
#' receives whole documents, with XML tags preserving paragraph boundaries;
#' up to 50 documents share a request within its 131 kB (131,072 byte) limit.
#' A document is divided across requests only when its encoded body, including
#' context and settings, exceeds that limit. Blank-line paragraph separators
#' and whitespace at segment edges are kept locally and restored verbatim.
#' Sentences, then whitespace, then code points delimit oversized paragraphs.
#' Hard cuts can split grapheme clusters. DeepL receives the call-wide
#' context and the document's paragraphs together in each text. A document
#' whose paragraph structure DeepL changes is sent again as two halves, and a
#' half that fails again is halved only while the other half succeeds.
#'
#' Qwen-MT groups adjacent paragraphs from the same document, using native
#' language, terminology and domain options in a non-streaming request. Groups
#' target at most `chunk_size` characters and approximately 6000 serialized
#' UTF-8 request bytes. This is a packing heuristic, not a token count; an
#' individual segment can exceed that soft byte target. Input-length
#' rejections, output truncation and lost or reordered boundary markers reduce
#' groups at paragraph boundaries, with at most eight group reductions. An oversized
#' individual paragraph is reduced at sentence, whitespace or code-point
#' boundaries with at most eight reductions. Original paragraph separators
#' are restored locally. Group boundaries use opaque markers with native
#' terminology entries mapping each marker to itself. Extra blank lines
#' inside one translated source paragraph become single line breaks rather
#' than causing a validation failure. Qwen-MT does not report its detected
#' source language.
#'
#' Protection failures and malformed or blank responses are retried once; under
#' the default `on_error = "continue"` these retries are sent together. A
#' single paragraph cut off at the output limit is retried as smaller
#' segments, with at most two reductions. A document with any failed segment is `NA`, never
#' a partial translation. Usage for every attempt is retained. Under
#' `on_error = "return"`, a validation failure is known only after the pool
#' returns, so requests already submitted cannot be withheld; remaining
#' retries are withheld after the first terminal failure.
#'
#' The provenance records requested settings, not a guarantee that the
#' provider applied them. Unsupported-parameter warnings from ellmer are
#' recorded and emitted once each. The detected language and the model
#' version that answered are not reported for chat models (`NA`); DeepL
#' reports the detected language per document or oversized document part.
#' Chat usage is recorded once per request, in the attempt of its first
#' segment.
#' Qwen-MT usage is recorded once per group, in its first segment attempt.
#' DeepL usage is recorded once per submitted document or part, in its first
#' segment attempt. DeepL model types express
#' quality/latency goals, not pinned model versions. Save the returned object
#' with [saveRDS()] to retain the exact translations used for coding.
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
#'   model = "deepl/quality_optimized", target_lang = "en-GB")
#' coded <- qlm_code(translated, data_codebook_sentiment,
#'   model = "openai/gpt-4o-mini")
#' qlm_trail(coded, path = "translation_trail")
#'
#' texts <- c(fr = "Bonjour tout le monde.", de = "Guten Morgen.")
#'
#' # Qwen-MT: reads DASHSCOPE_API_KEY for the Singapore endpoint
#' translated_qwen <- qlm_translate(texts,
#'   model = "dashscope/qwen-mt-plus", target_lang = "en-GB",
#'   context = "Greetings in everyday conversation.",
#'   params = ellmer::params(temperature = 0.1))
#' translated_qwen
#'
#' # Google: reads GOOGLE_TRANSLATE_API_KEY, falling back to the optional
#' # keyring entry saved with keyring::key_set("google-translate")
#' translated_google <- qlm_translate(texts,
#'   model = "google-translate/translation-llm", target_lang = "en-GB",
#'   project_id = "your-google-cloud-project-id")
#' # Alternatively, set GOOGLE_CLOUD_PROJECT and omit project_id.
#' attr(translated_google, "provenance")
#'
#' # DeepL with a formal register
#' qlm_translate(texts, model = "deepl/quality_optimized", formality = "more")
#'
#' # Convert to a quanteda corpus, if quanteda is installed
#' quanteda::corpus(translated_google)
#' }
#' @export
qlm_translate <- function(x, model, target_lang = "en", source_lang = NULL,
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
  for (arg in c("target_lang", "source_lang", "context", "adapter", "api_key",
                "base_url")) {
    check_optional_string(get(arg), arg)
  }
  if (is.null(target_lang) || !nzchar(target_lang)) {
    cli::cli_abort("{.arg target_lang} must be a non-empty language code.")
  }
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
  selected <- translation_adapter(model, adapter, base_url, api_key)
  provider_args <- check_provider_args(provider_args, selected$name)
  # The translation APIs rate-limit concurrent requests more tightly than
  # chat endpoints do.
  max_active <- max_active %||% if (selected$name == "generic") 10L else 2L
  if (selected$name == "generic") {
    selected$chat_args <- c(selected$chat_args, provider_args)
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
  settings <- list(target_lang = target_lang, source_lang = source_lang,
                   instructions = instructions, context = context, protect = protect,
                   glossary = glossary, params = params,
                   chunk_size = size, template_version = 3L,
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
  # All local splitting/protection validation finishes before building a key-
  # bearing request. Missing input is carried into the output without a call.
  plans <- if (selected$name == "google-translate") {
    lapply(source, translation_google_plan, settings = settings)
  } else lapply(source, translation_plan, size = size, protect = protect)
  setup <- translation_setup(selected, settings, api_key, base_url, rpm)
  result <- run_translation_plans(plans, setup, max_active, rpm, on_error)
  provenance <- data.frame(
    .id = ids, status = result$status, .error = result$error,
    source_text = unname(source), source_hash = vapply(source, translation_hash, "", USE.NAMES = FALSE),
    output_hash = vapply(result$text, translation_hash, "", USE.NAMES = FALSE), model = model,
    reported_model = vapply(result$attempts, translation_reported_models, ""),
    source_lang = source_lang %||% NA_character_, target_lang = target_lang,
    detected_language = vapply(result$attempts, translation_detected_languages, ""),
    adapter = selected$name, adapter_selection = if (is.null(adapter)) "automatic" else "explicit",
    base_url = setup$recorded_base_url %||% NA_character_, timestamp = Sys.time(),
    stringsAsFactors = FALSE
  )
  missing_input <- is.na(source)
  provenance$.error[missing_input] <- ifelse(
    is.na(input_errors[missing_input]), "source text is missing", input_errors[missing_input]
  )
  provenance$settings <- rep(list(settings), length(source))
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
