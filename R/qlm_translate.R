#' Translate texts before coding
#'
#' Translates texts and returns a quanteda-compatible corpus, retaining source
#' texts and per-document provenance in corpus user metadata. The result can be passed to [qlm_code()];
#' [qlm_trail()] then records translation as part of the coding instrument.
#'
#' @param x Character vector of texts, optionally named, or a quanteda corpus.
#'   Corpus document variables and system/user metadata are retained. Names
#'   must be unique and non-empty. Missing inputs remain failed units without
#'   a request. No installation or loading of quanteda is required.
#' @param model Required provider/model identifier. DeepL accepts
#'   `"deepl/quality_optimized"`, `"deepl/latency_optimized"` and
#'   `"deepl/prefer_quality_optimized"`. Other providers use [ellmer::chat()].
#' @param target_lang Target language code, such as `"en"` or `"en-GB"`.
#' @param source_lang Source language code, or `NULL` for automatic detection.
#' @param instructions Character vector of translation directives. DeepL
#'   accepts at most 10 directives of at most 300 characters each.
#' @param context One string of background information, not text to translate.
#' @param protect Character vector of regular expressions matching text to
#'   preserve exactly. Matches must not overlap or be empty. Matched text is
#'   masked before splitting and restored only after marker validation.
#' @param glossary Named character vector of source terms and their desired
#'   translations. Supported as instructions by the generic adapter. Native
#'   DeepL glossaries are not implemented in this initial version.
#' @param formality DeepL formality setting (`"default"`, `"more"`, `"less"`,
#'   `"prefer_more"`, `"prefer_less"`); an instruction for generic chat.
#' @param adapter `NULL` for automatic selection, or `"generic"` or `"deepl"`.
#'   Recognised Qwen-MT IDs require an adapter not yet implemented; explicitly
#'   selecting `"generic"` permits an experimental generic request.
#' @param params Settings created with [ellmer::params()], passed through on
#'   the chat route. Non-empty settings are refused on the DeepL route.
#' @param chunk_size Positive integer; estimated maximum characters per
#'   segment, including protection markers. Defaults to 4000 for chat and
#'   16000 for DeepL, reduced by a supplied `params$max_tokens` on chat.
#'   Character counts cannot guarantee token limits.
#' @param api_key API key, or `NULL` to use the provider's environment variable
#'   (`DEEPL_API_KEY` for DeepL). For macOS Keychain, save a key interactively
#'   with `keyring::key_set("deepl")`, then pass
#'   `api_key = keyring::key_get("deepl")`. Keys are never recorded.
#' @param base_url Optional API base URL. DeepL defaults to its Free or Pro
#'   host according to the key. Recorded with URL credentials redacted.
#' @param max_active Maximum concurrent requests.
#' @param rpm Maximum requests per minute.
#' @param on_error Failure policy: `"continue"` attempts all units,
#'   `"return"` stops new submissions after a failure, and `"stop"` raises it.
#' @param ... Reserved; must be empty.
#'
#' @details
#' This initial implementation translates one paragraph or smaller segment
#' per prompt. DeepL packs segments sharing context into requests of at most
#' 50 texts and 128 KiB. Blank-line paragraph separators and whitespace at
#' segment edges are kept locally and restored verbatim. Sentences, then
#' whitespace, then code points delimit oversized paragraphs. Hard cuts can
#' split grapheme clusters. Every segment receives the preceding source
#' segment within its document as separate context; documents never share it.
#'
#' Protection failures and malformed or blank responses are retried once.
#' A chat response reported as truncated is retried as smaller segments, with
#' at most two reductions. A document with any failed segment is `NA`, never
#' a partial translation. Usage for every attempt is retained. Under
#' `on_error = "return"`, a validation failure is known only after the pool
#' returns, so requests already submitted cannot be withheld; remaining
#' retries are withheld after the first terminal failure.
#'
#' The provenance records requested settings, not a guarantee that the
#' provider applied them. Unsupported-parameter warnings from ellmer are
#' recorded and emitted once each. The detected language for chat models is
#' unreported (`NA`); DeepL reports it per segment. DeepL model types express
#' quality/latency goals, not pinned model versions. Save the returned object
#' with [saveRDS()] to retain the exact translations used for coding.
#'
#' @return A named character vector of class `qlm_translation`, inheriting
#'   from `qlm_preprocessed`, `qlm_corpus` and `corpus`. Its `meta` attribute
#'   follows quanteda's system/object/user structure. The provenance table is
#'   stored at `meta$user$quallmer$translation`, accessible as
#'   `qlm_meta(x, "quallmer")$translation` or, with quanteda loaded,
#'   `quanteda::meta(x, "quallmer")$translation`. It includes
#'   `.id`, `status`, `.error`, `source_text`, `source_hash`, `output_hash`,
#'   requested and reported models, languages, adapter selection, endpoint,
#'   timestamp, and list columns for settings, segment attempts and prior
#'   preprocessing stages. Subsetting, renaming and concatenating keep the
#'   records aligned. Replacement by plain text records an edit and keeps the
#'   destination document variables. Existing corpus user fields are preserved;
#'   `quallmer` is a reserved list namespace for translation provenance. New
#'   corpora have no user document variables and record quallmer as their
#'   creating package in system metadata. Existing system metadata is retained
#'   exactly. Object-level summary caches are cleared after translation.
#'   Concatenation uses the first corpus's system/object metadata and requires
#'   compatible user metadata (excluding the translation records).
#' @examples
#' \dontrun{
#' # Reads DEEPL_API_KEY, or supply api_key = keyring::key_get("deepl")
#' translated <- qlm_translate(c(speech = "Bonjour tout le monde."),
#'   model = "deepl/quality_optimized", target_lang = "en-GB")
#' coded <- qlm_code(translated, codebook_sentiment,
#'   model = "openai/gpt-4o-mini")
#' qlm_trail(coded, path = "translation_trail")
#' }
#' @export
qlm_translate <- function(x, model, target_lang = "en", source_lang = NULL,
                          instructions = NULL, context = NULL, protect = NULL,
                          glossary = NULL, formality = NULL, adapter = NULL,
                          params = NULL, chunk_size = NULL, api_key = NULL,
                          base_url = NULL, max_active = 10, rpm = 60,
                          on_error = c("continue", "return", "stop"), ...) {
  rlang::check_dots_empty()
  on_error <- rlang::arg_match(on_error)
  if (!is.character(x) || !length(x)) {
    cli::cli_abort("{.arg x} must be a non-empty character vector of texts.")
  }
  if (missing(model) || !rlang::is_string(model) || !nzchar(model)) {
    cli::cli_abort("Supply {.arg model} as a single provider/model string.")
  }
  for (arg in c("target_lang", "source_lang", "context", "formality",
                "adapter", "api_key", "base_url")) {
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
  for (arg in c("max_active", "rpm")) {
    if (!is_count(get(arg), 1L)) {
      cli::cli_abort("{.arg {arg}} must be a positive whole number.")
    }
  }
  if (!is.null(chunk_size) && !is_count(chunk_size, 1L)) {
    cli::cli_abort("{.arg chunk_size} must be a positive whole number.")
  }
  ids <- names(x) %||% paste0("text", seq_along(x))
  check_ids(ids, what = "The names of {.arg x}")
  corpus_attributes <- translation_corpus_attributes(x)
  history <- preprocessing_history(x)
  input_errors <- if (is_qlm_preprocessed(x)) {
    if (is_qlm_translation(x)) translation_provenance(x)$.error else attr(x, "provenance")$.error
  } else rep(NA_character_, length(x))
  source <- translation_texts(x)
  if (anyNA(source) && on_error == "stop") {
    cli::cli_abort("Translation failed: source text is missing.")
  }
  selected <- translation_adapter(model, adapter, base_url, api_key)
  if (selected$name == "deepl") {
    if (length(params)) cli::cli_abort("{.arg params} is not supported by DeepL.")
    if (!is.null(glossary)) {
      cli::cli_abort("Native DeepL {.arg glossary} is not implemented yet.")
    }
    if (length(instructions) > 10L || any(nchar(instructions) > 300L)) {
      cli::cli_abort("DeepL accepts at most 10 instructions of at most 300 characters each.")
    }
    if (!is.null(formality)) {
      formality <- rlang::arg_match(formality, c(
        "default", "more", "less", "prefer_more", "prefer_less"
      ))
    }
  }
  size <- chunk_size %||% if (selected$name == "deepl") 16000L else 4000L
  if (selected$name == "generic" && !is.null(params$max_tokens)) {
    if (!is_count(params$max_tokens, 1L)) {
      cli::cli_abort("{.arg params$max_tokens} must be a positive whole number.")
    }
    size <- min(size, params$max_tokens)
  }
  settings <- list(target_lang = target_lang, source_lang = source_lang,
                   instructions = instructions, context = context, protect = protect,
                   glossary = glossary, formality = formality, params = params,
                   chunk_size = size, template_version = 1L,
                   ellmer_version = as.character(utils::packageVersion("ellmer")))
  # All local splitting/protection validation finishes before building a key-
  # bearing request. Missing input is carried into the output without a call.
  plans <- lapply(source, translation_plan, size = size, protect = protect)
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
  provenance$settings <- rep(list(settings), length(x))
  provenance$attempts <- result$attempts
  provenance$history <- history
  out <- new_qlm_translation(result$text, provenance,
    docvars = corpus_attributes$docvars, meta = corpus_attributes$meta)
  failed <- provenance$status == "failed"
  if (any(failed)) {
    cli::cli_warn(c("{sum(failed)} of {length(x)} translation{?s} failed.",
                   set_bullets(unique(provenance$.error[failed]))))
  }
  out
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
