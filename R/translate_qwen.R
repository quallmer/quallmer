# Qwen-MT accepts source text in a single user message and native translation
# options. It must not receive the generic chat system prompt or JSON wrapper.
translation_qwen_jobs <- function(jobs, setup, max_active, rpm, on_error,
                                  group_depth = 0L) {
  groups <- translation_qwen_groups(jobs, setup)
  reqs <- lapply(groups, function(idx) translation_qwen_request(jobs[idx], setup))
  # Input-limit 400s need to reach the parser so they can reduce a group.
  # Other HTTP and transport errors retain the pool's requested error policy.
  responses <- perform_translation_requests(reqs, max_active, on_error)
  out <- vector("list", length(jobs))
  repair <- TRUE
  for (i in seq_along(groups)) {
    idx <- groups[[i]]
    values <- translation_qwen_resolve(jobs[idx], responses[[i]], setup,
      max_active, rpm, on_error, group_depth, repair)
    out[idx] <- values
    if (on_error %in% c("return", "stop") && any(vapply(values, translation_qwen_failed, logical(1)))) {
      repair <- FALSE
    }
  }
  out
}

translation_qwen_setup <- function(adapter, settings, rpm) {
  if (!is.null(settings$formality)) {
    cli::cli_abort("Qwen-MT does not support {.arg formality}; use {.arg instructions} instead.")
  }
  translation_qwen_params(settings$params)
  host <- adapter$args$base_url
  if (is.null(host)) {
    cli::cli_abort("Qwen-MT requires a registered OpenAI-compatible provider or an explicit {.arg base_url}.")
  }
  host <- check_registry_url(host)
  credentials <- adapter$args$credentials
  key <- if (is.function(credentials)) credentials() else credentials
  if (!rlang::is_string(key) || !nzchar(trimws(key))) {
    cli::cli_abort("No Qwen-MT API key is available; set the provider's key variable (e.g. {.envvar DASHSCOPE_API_KEY}) or supply {.arg api_key}.")
  }
  list(adapter = adapter, settings = settings, api_key = key, base_url = host,
       recorded_base_url = redact_url(host), rpm = rpm)
}

translation_qwen_params <- function(params) {
  if (anyDuplicated(names(params))) {
    cli::cli_abort("Qwen-MT {.arg params} must have unique names.")
  }
  supported <- c("temperature", "top_p", "top_k", "seed", "max_tokens")
  unknown <- setdiff(names(params), supported)
  if (length(unknown)) cli::cli_abort("Unsupported Qwen-MT {.arg params}: {.val {unknown}}.")
  for (name in names(params)) {
    value <- params[[name]]
    valid <- switch(name,
      temperature = is.numeric(value) && length(value) == 1L &&
        is.finite(value) && value >= 0 && value < 2,
      top_p = is.numeric(value) && length(value) == 1L &&
        is.finite(value) && value > 0 && value <= 1,
      top_k = is_count(value) && value <= 100,
      seed = is_count(value),
      max_tokens = is_count(value, 1L))
    if (!valid) cli::cli_abort("Invalid Qwen-MT setting {.arg params${name}}.")
  }
}

translation_qwen_language <- function(language, source = FALSE) {
  if (is.null(language)) return(if (source) "auto" else "English")
  aliases <- c(en = "English", `en-gb` = "English", `en-us` = "English",
    de = "German", deu = "German", fr = "French", fra = "French",
    es = "Spanish", spa = "Spanish", zh = "Chinese", `zh-cn` = "Chinese",
    `zh-hans` = "Chinese", `zh-tw` = "Traditional Chinese",
    `zh-hant` = "Traditional Chinese", hi = "Hindi", hin = "Hindi",
    ru = "Russian", rus = "Russian")
  value <- unname(aliases[tolower(language)])
  if (is.na(value)) language else value
}

translation_qwen_body <- function(jobs, setup) {
  settings <- setup$settings
  boundaries <- translation_qwen_boundaries(jobs)
  domains <- c(
    "Preserve every opaque QLMP boundary marker exactly, once, in its original order.",
    "Translate the text on each side of a boundary marker independently; never move text across it.",
    "Preserve every opaque QLMKEEP marker exactly.",
    if (identical(tolower(settings$target_lang), "en-gb")) "Use British English.",
    if (identical(tolower(settings$target_lang), "en-us")) "Use American English.",
    settings$context, settings$instructions
  )
  options <- list(source_lang = translation_qwen_language(settings$source_lang, TRUE),
                  target_lang = translation_qwen_language(settings$target_lang),
                  domains = paste(domains, collapse = "\n"))
  terms <- unname(Map(function(source, target) list(source = source, target = target),
                      names(settings$glossary), unname(settings$glossary)))
  keep <- unique(c(boundaries$tokens, unlist(lapply(jobs, function(job) {
    translation_markers(job$text, job$marker_prefix)
  }))))
  terms <- c(terms, unname(lapply(keep, function(token) list(source = token, target = token))))
  if (length(terms)) options$terms <- terms
  c(list(model = setup$adapter$model_id,
         messages = list(list(role = "user", content = translation_qwen_text(jobs, boundaries))),
         translation_options = options, stream = FALSE), settings$params)
}

translation_qwen_boundaries <- function(jobs) {
  text <- paste(vapply(jobs, `[[`, "", "text"), collapse = "\n\n")
  prefix <- paste0("QLMP", substr(translation_hash(text), 1L, 12L), "_")
  while (grepl(prefix, text, fixed = TRUE)) prefix <- paste0(prefix, "X")
  tokens <- if (length(jobs) > 1L) paste0(prefix, seq_len(length(jobs) - 1L), "END") else character()
  list(prefix = prefix, tokens = tokens)
}

translation_qwen_text <- function(jobs, boundaries) {
  text <- jobs[[1]]$text
  for (i in seq_along(boundaries$tokens)) {
    text <- paste0(text, "\n\n", boundaries$tokens[i], "\n\n", jobs[[i + 1L]]$text)
  }
  text
}

# The byte target is a conservative packing heuristic, not a token count.
# Only explicit input-length errors trigger token-limit reductions.
translation_qwen_groups <- function(jobs, setup) {
  groups <- list()
  current <- integer()
  for (i in seq_along(jobs)) {
    proposed <- c(current, i)
    same_doc <- !length(current) || identical(jobs[[i]]$document, jobs[[current[1]]]$document)
    body <- translation_qwen_body(jobs[proposed], setup)
    fits <- same_doc && nchar(body$messages[[1]]$content) <= setup$settings$chunk_size &&
      translation_body_bytes(body) <= setup$settings$group_max_bytes
    if (!fits && length(current)) {
      groups[[length(groups) + 1L]] <- current
      current <- integer()
    }
    current <- c(current, i)
  }
  if (length(current)) groups[[length(groups) + 1L]] <- current
  groups
}

translation_qwen_request <- function(jobs, setup) {
  req <- httr2::request(setup$base_url)
  req <- httr2::req_url_path_append(req, "chat", "completions")
  req <- httr2::req_auth_bearer_token(req, setup$api_key)
  req <- httr2::req_body_json(req, translation_qwen_body(jobs, setup), auto_unbox = TRUE)
  req <- httr2::req_error(req, is_error = function(resp) {
    httr2::resp_status(resp) >= 400L && httr2::resp_status(resp) != 400L
  })
  req <- httr2::req_retry(req, max_tries = 3)
  httr2::req_throttle(req, capacity = 1, fill_time_s = 60 / setup$rpm,
    realm = paste0("quallmer-qwen-mt-", translation_hash(setup$base_url)))
}

translation_qwen_resolve <- function(jobs, response, setup, max_active, rpm,
                                     on_error, depth, repair) {
  values <- parse_qwen_translation(response, length(jobs), setup$api_key,
                                   translation_qwen_boundaries(jobs))
  for (i in seq_along(values)) {
    if (!is.null(values[[i]])) values[[i]]$group_reduction <- depth
  }
  first <- values[[1]]
  reduce <- isTRUE(first$input_too_long) || identical(first$finish, "max_tokens") ||
    isTRUE(first$boundary_mismatch)
  if (!repair || !reduce || length(jobs) < 2L || depth >= 8L) return(values)
  halves <- list(seq_len(floor(length(jobs) / 2L)),
                 seq.int(floor(length(jobs) / 2L) + 1L, length(jobs)))
  # Record the parent before submitting children. Unprocessed children retain
  # their parent's actual rejection when an error policy stops further work.
  parents <- lapply(seq_along(jobs), function(i) {
    parent <- values[[i]]
    reason <- parent$error %||% NA_character_
    if (identical(parent$finish, "max_tokens")) reason <- "the model reached its output token limit"
    translation_attempt(jobs[[i]], parent, reason, depth)
  })
  out <- values
  for (idx in halves) {
    child <- translation_qwen_jobs(jobs[idx], setup, max_active, rpm, on_error,
                                   group_depth = depth + 1L)
    for (i in seq_along(idx)) {
      pos <- idx[i]
      if (!is.null(child[[i]])) {
        child[[i]]$prior_attempts <- c(list(parents[[pos]]), child[[i]]$prior_attempts %||% list())
      }
    }
    out[idx] <- child
    if (on_error %in% c("return", "stop") && any(vapply(child, translation_qwen_failed, logical(1)))) break
  }
  out
}

translation_qwen_failed <- function(value) {
  if (is.null(value)) return(TRUE)
  error <- !is.na(value$error %||% NA_character_) && !isTRUE(value$input_too_long)
  finish <- value$finish %||% NA_character_
  error || (!is.na(finish) && !finish %in% c("success", "max_tokens"))
}

parse_qwen_translation <- function(response, n, key, boundaries = NULL) {
  if (is.null(response)) return(rep(list(NULL), n))
  body <- if (!inherits(response, "error")) {
    tryCatch(httr2::resp_body_json(response, simplifyVector = FALSE), error = function(e) NULL)
  }
  if (!is.list(body)) body <- list()
  message <- if (inherits(response, "error")) conditionMessage(response) else {
    if (is.list(body$error)) body$error$message else NULL
  }
  bad_http <- inherits(response, "error") || httr2::resp_status(response) >= 400L
  if (bad_http && !rlang::is_string(message)) message <- "Qwen-MT request failed"
  if (rlang::is_string(message)) message <- gsub(key, "[REDACTED]", strip_ansi(message), fixed = TRUE)
  input_limit <- bad_http && !inherits(response, "error") &&
    httr2::resp_status(response) == 400L && rlang::is_string(message) &&
    grepl("Range of input length should be \\[1, ?[0-9]+\\]", message)
  choice <- if (is.list(body$choices) && length(body$choices)) body$choices[[1]] else list()
  if (!is.list(choice)) choice <- list()
  text <- if (is.list(choice$message)) choice$message$content else NULL
  finish_reason <- choice$finish_reason
  if (!rlang::is_string(finish_reason)) finish_reason <- "unknown"
  finish <- switch(finish_reason, stop = "success", length = "max_tokens", finish_reason)
  parts <- translation_qwen_parts(text, n, boundaries)
  mismatch <- !bad_http && is.null(parts)
  error <- if (bad_http) message else if (mismatch) {
    "Qwen-MT returned empty text or missing, duplicated or reordered boundary markers"
  } else NA_character_
  lapply(seq_len(n), function(i) list(
    text = if (!bad_http && !mismatch) parts[i] else NA_character_, error = error,
    finish = if (bad_http) NA_character_ else finish,
    stage = if (bad_http) "transport" else "content", input_too_long = input_limit,
    boundary_mismatch = mismatch, boundary_prefix = boundaries$prefix,
    group_size = n, request_id = body$id,
    reported_model = body$model, detected_language = NULL,
    usage = if (i == 1L) body$usage else NULL
  ))
}

translation_qwen_parts <- function(text, n, boundaries) {
  if (!rlang::is_string(text) || !nzchar(trimws(text))) return(NULL)
  if (n == 1L) {
    parts <- text
  } else {
    if (is.null(boundaries) || length(boundaries$tokens) != n - 1L) return(NULL)
    found <- gregexpr(paste0(boundaries$prefix, "[0-9]+END"), text, perl = TRUE)
    if (!identical(regmatches(text, found)[[1]], boundaries$tokens)) return(NULL)
    starts <- found[[1]]
    ends <- starts + attr(starts, "match.length") - 1L
    parts <- substring(text, c(1L, ends + 1L), c(starts - 1L, nchar(text)))
  }
  # The original blank-line separators live in the plan. Any blank lines
  # added within a translated source paragraph are formatting, not boundaries.
  parts <- trimws(gsub(translation_paragraph_pattern(), "\n", parts, perl = TRUE),
                  whitespace = "[[:space:]]")
  if (any(!nzchar(parts))) return(NULL)
  parts
}
