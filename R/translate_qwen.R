# Qwen-MT accepts source text in a single user message and native translation
# options. It must not receive the generic chat system prompt or JSON wrapper.
translation_qwen_jobs <- function(jobs, setup, max_active, rpm, on_error) {
  groups <- translation_qwen_groups(jobs, setup)
  out <- vector("list", length(jobs))
  depth <- 0L
  # A group rejected as too long, cut off at the output limit, or whose
  # boundary markers came back wrong is sent again as two halves. Each round
  # sends every such half together, so repairs run in parallel rather than
  # one request at a time; at most eight rounds.
  while (length(groups)) {
    reqs <- lapply(groups, function(idx) translation_qwen_request(jobs[idx], setup))
    # Input-limit 400s need to reach the parser so they can reduce a group.
    # Other HTTP and transport errors retain the pool's requested error policy.
    responses <- perform_translation_requests(reqs, max_active, on_error)
    halves <- list()
    repair <- TRUE
    for (i in seq_along(groups)) {
      idx <- groups[[i]]
      values <- parse_qwen_translation(responses[[i]], length(idx), setup$api_key,
                                       translation_qwen_boundaries(jobs[idx]))
      for (k in seq_along(idx)) {
        pos <- idx[k]
        if (is.null(values[[k]])) next
        values[[k]]$group_reduction <- depth
        # A segment keeps the record of each larger group it was part of.
        # Unprocessed segments retain their parent's actual rejection when
        # an error policy stops further work.
        parent <- out[[pos]]
        if (!is.null(parent)) {
          reason <- parent$error %||% NA_character_
          if (identical(parent$finish, "max_tokens")) reason <- "the model reached its output token limit"
          values[[k]]$prior_attempts <- c(parent$prior_attempts,
            list(translation_attempt(jobs[[pos]], parent, reason, depth - 1L)))
        }
        out[[pos]] <- values[[k]]
      }
      first <- values[[1]]
      reduce <- isTRUE(first$input_too_long) || identical(first$finish, "max_tokens") ||
        isTRUE(first$boundary_mismatch)
      if (reduce && length(idx) >= 2L && depth < 8L) {
        h <- floor(length(idx) / 2L)
        halves <- c(halves, list(idx[seq_len(h)], idx[-seq_len(h)]))
      }
      if (on_error %in% c("return", "stop") && any(vapply(values, translation_qwen_failed, logical(1)))) {
        repair <- FALSE
      }
    }
    groups <- if (repair) halves else list()
    depth <- depth + 1L
  }
  out
}

translation_qwen_setup <- function(adapter, settings, rpm) {
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

translation_qwen_body <- function(jobs, setup) {
  settings <- setup$settings
  boundaries <- translation_qwen_boundaries(jobs)
  domains <- c(
    "Preserve every opaque QLMP boundary marker exactly, once, in its original order.",
    "Translate the text on each side of a boundary marker independently; never move text across it.",
    "Preserve every opaque QLMKEEP marker exactly.",
    if (!is.null(settings$provider_languages$variant)) {
      paste0("Write in the ", settings$provider_languages$variant, " regional variant of the target language.")
    },
    settings$context, settings$instructions
  )
  options <- list(source_lang = settings$provider_languages$source,
                  target_lang = settings$provider_languages$target,
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
  # Qwen-MT reports an unsupported language only in Chinese
  if (rlang::is_string(message) && grepl("\u4e0d\u652f\u6301\u5f53\u524d\u8bbe\u7f6e\u7684\u8bed\u79cd", message)) {
    message <- paste0("Qwen-MT does not support the requested source or target language (", message, ")")
  }
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
