# Cloud Translation Basic accepts the standard Translation LLM using an API
# key and a full model resource name. Each request contains one document.
translation_google_jobs <- function(jobs, setup, max_active, on_error) {
  reqs <- lapply(jobs, translation_google_request, setup = setup)
  responses <- perform_translation_requests(reqs, max_active, on_error)
  lapply(responses, parse_google_translation, api_key = setup$api_key)
}

translation_google_settings <- function(settings, project_id, region) {
  for (arg in c("params", "instructions", "context", "glossary", "formality")) {
    if (length(settings[[arg]])) {
      cli::cli_abort("Google Translation LLM does not support {.arg {arg}} through the Basic API.")
    }
  }
  project_id <- project_id %||% Sys.getenv("GOOGLE_CLOUD_PROJECT")
  if (!rlang::is_string(project_id) ||
      !grepl("^[a-z][a-z0-9-]{4,28}[a-z0-9]$|^[0-9]+$", project_id)) {
    cli::cli_abort("Supply a Google Cloud {.arg project_id} or set {.envvar GOOGLE_CLOUD_PROJECT}.")
  }
  if (!rlang::is_string(region) || !grepl("^[a-z][a-z0-9-]*$", region)) {
    cli::cli_abort("{.arg region} must be a Google Cloud location, such as {.val us-central1}.")
  }
  settings$project_id <- project_id
  settings$region <- region
  settings$chunk_size <- min(settings$chunk_size, 30000L)
  settings$text_unit <- "document"
  settings$google_model <- paste0("projects/", project_id, "/locations/", region,
                                 "/models/general/translation-llm")
  settings
}

translation_google_setup <- function(adapter, settings, api_key, base_url, rpm) {
  host <- check_registry_url(base_url %||% "https://translation.googleapis.com")
  if (is.null(api_key) && host != "https://translation.googleapis.com") {
    cli::cli_abort("Supply an explicit {.arg api_key} when overriding the Google Translation {.arg base_url}.")
  }
  key <- google_translation_api_key(api_key)
  list(adapter = adapter, settings = settings, api_key = key, base_url = host,
       recorded_base_url = redact_url(host), rpm = rpm)
}

google_translation_api_key <- function(api_key = NULL) {
  key <- api_key
  if (is.null(key)) {
    key <- Sys.getenv("GOOGLE_TRANSLATE_API_KEY")
    if (!nzchar(key)) key <- google_translation_keyring_key()
  }
  if (!rlang::is_string(key) || !nzchar(trimws(key))) {
    cli::cli_abort(c(
      "No Google Translation API key is available.",
      "i" = "Supply {.arg api_key} or set {.envvar GOOGLE_TRANSLATE_API_KEY}.",
      "i" = 'Alternatively, install {.pkg keyring} and save a key with {.code keyring::key_set("google-translate")}.'
    ))
  }
  key
}

google_translation_keyring_key <- function() {
  if (!requireNamespace("keyring", quietly = TRUE)) return(NULL)
  suppressWarnings(tryCatch(keyring::key_get("google-translate"), error = function(e) NULL))
}

translation_google_body <- function(text, settings) {
  body <- list(q = list(text), target = settings$target_lang, format = "text",
               model = settings$google_model)
  if (!is.null(settings$source_lang)) body$source <- settings$source_lang
  body
}

# Preserve complete documents when possible. Split only at the character or
# serialized JSON byte limit, without XML or paragraph-alignment sentinels.
translation_google_plan <- function(text, settings) {
  if (is.na(text)) return(NULL)
  masked <- mask_translation_terms(text, settings$protect)
  size <- settings$chunk_size
  repeat {
    pieces <- split_translation_segment(masked$text, size, masked$prefix)
    fits <- vapply(pieces, function(piece) {
      translation_body_bytes(translation_google_body(piece$text, settings)) <= 100000L
    }, logical(1))
    if (all(fits)) break
    if (size == 1L) cli::cli_abort("Google Translation request settings exceed the 100 kB limit.")
    size <- max(1L, floor(size / 2L))
  }
  list(list(pieces = pieces, markers = masked$markers,
            marker_prefix = masked$prefix, separator = ""))
}

translation_google_request <- function(job, setup) {
  body <- translation_google_body(job$text, setup$settings)
  if (nchar(job$text) > 30000L || translation_body_bytes(body) > 100000L) {
    cli::cli_abort("Google Translation requests must fit within 30,000 characters and 100 kB.")
  }
  req <- httr2::request(setup$base_url)
  req <- httr2::req_url_path_append(req, "language", "translate", "v2")
  req <- httr2::req_headers(req, `x-goog-api-key` = setup$api_key)
  req <- httr2::req_body_json(req, body, auto_unbox = TRUE)
  req <- httr2::req_error(req, body = translation_google_error)
  req <- httr2::req_retry(req, max_tries = 3)
  req <- httr2::req_timeout(req, seconds = 180)
  httr2::req_throttle(req, capacity = 1, fill_time_s = 60 / setup$rpm,
    realm = paste0("quallmer-google-translate-", translation_hash(setup$base_url)))
}

translation_google_error <- function(resp) {
  body <- tryCatch(httr2::resp_body_json(resp), error = function(e) NULL)
  if (is.list(body) && is.list(body$error) && rlang::is_string(body$error$message)) {
    body$error$message
  } else NULL
}

parse_google_translation <- function(response, api_key) {
  if (is.null(response)) return(NULL)
  out <- list(text = NA_character_, error = NA_character_, finish = NA_character_,
              usage = NULL)
  if (inherits(response, "error")) {
    out$error <- gsub(api_key, "[REDACTED]", strip_ansi(conditionMessage(response)), fixed = TRUE)
    return(out)
  }
  body <- tryCatch(httr2::resp_body_json(response, simplifyVector = FALSE), error = function(e) NULL)
  values <- if (is.list(body) && is.list(body$data)) body$data$translations else NULL
  if (!is.list(values) || length(values) != 1L || !is.list(values[[1]]) ||
      !rlang::is_string(values[[1]]$translatedText) ||
      !nzchar(trimws(values[[1]]$translatedText))) {
    out$error <- "Google Translation returned an invalid translation response"
    out$stage <- "content"
    return(out)
  }
  value <- values[[1]]
  out$text <- value$translatedText
  out$reported_model <- if (rlang::is_string(value$model)) value$model else NULL
  out$detected_language <- if (rlang::is_string(value$detectedSourceLanguage)) {
    value$detectedSourceLanguage
  } else NULL
  out
}
