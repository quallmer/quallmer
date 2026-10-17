# Adapter selection is independent of the host: a registered prefix may
# expose either an ordinary chat model or a specialised translation model.
translation_adapter <- function(model, adapter, base_url, api_key) {
  google <- identical(model_provider(model), "google-translate")
  if (google || identical(adapter, "google-translate")) {
    if (!google || !model %in% c("google-translate/translation-llm",
        "google-translate/general/translation-llm") ||
        (!is.null(adapter) && adapter != "google-translate")) {
      cli::cli_abort("The Google Translation adapter requires {.val google-translate/translation-llm}.")
    }
    return(list(name = "google-translate", model_id = "general/translation-llm",
                model = model, args = list()))
  }
  deepl <- identical(model_provider(model), "deepl")
  if (!is.null(adapter) && !adapter %in% c("generic", "deepl", "qwen-mt", "hy-mt2", "translategemma")) {
    cli::cli_abort("Unknown translation {.arg adapter}: {.val {adapter}}.")
  }
  if (!is.null(adapter) && xor(deepl, identical(adapter, "deepl"))) {
    cli::cli_abort("{.arg adapter} is incompatible with the transport for {.val {model}}.")
  }
  if (deepl) {
    id <- sub("^[^/]*/", "", model)
    if (!id %in% c("quality_optimized", "latency_optimized", "prefer_quality_optimized")) {
      cli::cli_abort("Unknown DeepL model type {.val {id}}.")
    }
    return(list(name = "deepl", model_id = id, model = model, args = list()))
  }
  args <- list()
  if (!is.null(base_url)) args$base_url <- base_url
  if (!is.null(api_key)) args$credentials <- function() api_key
  resolved <- resolve_provider(model, args)
  id <- sub("^[^/]*/", "", resolved$model)
  chosen <- adapter %||% if (id %in% c("qwen-mt-plus", "qwen-mt-flash", "qwen-mt-lite")) {
    "qwen-mt"
  } else "generic"
  if (chosen == "qwen-mt" && !startsWith(id, "qwen-mt-")) {
    cli::cli_abort("The Qwen-MT adapter requires a Qwen-MT model identifier.")
  }
  if (!chosen %in% c("generic", "qwen-mt")) {
    cli::cli_abort(c(
      "The {.val {chosen}} translation adapter is not implemented yet.",
      "i" = "Use another model, or explicitly set {.code adapter = \"generic\"} to try a generic prompt."
    ))
  }
  # qlm_code() resolves the provider again from the requested model and the
  # user's own arguments, as it would for any coding run.
  list(name = chosen, model = resolved$model, model_id = id, args = resolved$args,
       resolution = resolved$resolution, requested = model, chat_args = args)
}

translation_setup <- function(adapter, settings, api_key, base_url, rpm) {
  if (adapter$name == "google-translate") {
    return(translation_google_setup(adapter, settings, api_key, base_url, rpm))
  }
  if (adapter$name == "qwen-mt") return(translation_qwen_setup(adapter, settings, rpm))
  if (adapter$name == "deepl") {
    key <- deepl_api_key(api_key)
    host <- base_url %||% if (endsWith(key, ":fx")) {
      "https://api-free.deepl.com"
    } else "https://api.deepl.com"
    # Validate the URL without disclosing any embedded credential.
    host <- check_registry_url(host)
    return(list(adapter = adapter, settings = settings, api_key = key,
                base_url = host, recorded_base_url = redact_url(host), rpm = rpm))
  }
  list(adapter = adapter, settings = settings, codebook = translation_codebook(settings),
       recorded_base_url = if (!is.null(adapter$args$base_url)) redact_url(adapter$args$base_url))
}

# Explicit credentials and the environment take precedence over the optional
# system credential store. The retrieved value stays local to the request;
# neither it nor a keyring error is copied to provenance or the environment.
deepl_api_key <- function(api_key = NULL) {
  if (!is.null(api_key)) {
    key <- api_key
  } else {
    key <- Sys.getenv("DEEPL_API_KEY")
    if (!nzchar(key)) key <- deepl_keyring_key()
  }
  if (!rlang::is_string(key) || !nzchar(trimws(key))) {
    cli::cli_abort(c(
      "No DeepL API key is available.",
      "i" = "Supply {.arg api_key} or set {.envvar DEEPL_API_KEY}.",
      "i" = "Alternatively, install {.pkg keyring}, save a key with {.code keyring::key_set(\"deepl\")}, and ensure the keyring is accessible."
    ))
  }
  key
}

deepl_keyring_key <- function() {
  if (!requireNamespace("keyring", quietly = TRUE)) return(NULL)
  # Missing entries, locked stores and unavailable OS backends all leave
  # the caller free to supply credentials explicitly. Do not surface an
  # arbitrary backend message that could disclose credential details.
  suppressWarnings(tryCatch(keyring::key_get("deepl"), error = function(e) NULL))
}

# DeepL accepts at most 50 texts and a 128 KiB request body.
deepl_max_texts <- 50L
deepl_max_bytes <- 128L * 1024L

# Each DeepL text is one document, or one part of a document too large for a
# request, as XML: <qlm>text</qlm> for a single paragraph and
# <qlm><p id="1">...</p><p id="2">...</p></qlm> for several. The string is
# built directly, not with xml2, so that its encoded size is the sum of its
# paragraphs' sizes and a request can be packed without re-encoding it.
translation_deepl_text <- function(jobs) {
  inner <- vapply(jobs, translation_deepl_inner, "")
  if (length(jobs) == 1L) {
    return(paste0("<qlm>", inner, "</qlm>"))
  }
  paste0("<qlm>", paste0('<p id="', seq_along(jobs), '">', inner, "</p>", collapse = ""), "</qlm>")
}

# Markers contain only ASCII letters, digits and underscores, so wrapping
# them after escaping cannot introduce untrusted markup.
translation_deepl_inner <- function(job) {
  text <- translation_xml_escape(job$text)
  for (marker in unique(translation_markers(job$text, job$marker_prefix))) {
    text <- gsub(marker, paste0("<keep>", marker, "</keep>"), text, fixed = TRUE)
  }
  text
}

# Characters XML 1.0 cannot carry become U+FFFD, as xml2 would make them; a
# carriage return is kept as a character reference.
translation_xml_escape <- function(text) {
  text <- gsub("&", "&amp;", text, fixed = TRUE)
  text <- gsub("<", "&lt;", text, fixed = TRUE)
  text <- gsub(">", "&gt;", text, fixed = TRUE)
  text <- gsub("\r", "&#13;", text, fixed = TRUE)
  gsub("[\\x01-\\x08\\x0B\\x0C\\x0E-\\x1F]", "\uFFFD", text, perl = TRUE)
}

translation_deepl_body <- function(jobs, items, setup) {
  settings <- setup$settings
  body <- list(text = lapply(items, function(idx) translation_deepl_text(jobs[idx])),
    target_lang = settings$provider_languages$target, model_type = setup$adapter$model_id,
    tag_handling = "xml", tag_handling_version = "v2", ignore_tags = list("keep"),
    split_sentences = "nonewlines", preserve_formatting = TRUE, show_billed_characters = TRUE)
  if (!is.null(settings$source_lang)) body$source_lang <- settings$provider_languages$source
  if (!is.null(settings$context) && nzchar(settings$context)) body$context <- settings$context
  if (length(settings$instructions)) body$custom_instructions <- as.list(settings$instructions)
  if (!is.null(settings$formality)) body$formality <- settings$formality
  body
}

# One item per document: the job positions that become one DeepL text.
translation_deepl_groups <- function(jobs) {
  documents <- vapply(seq_along(jobs), function(i) as.character(jobs[[i]]$document %||% i), "")
  unname(split(seq_along(jobs), match(documents, unique(documents))))
}

translation_body_bytes <- function(body) {
  nchar(jsonlite::toJSON(body, auto_unbox = TRUE, null = "null"), type = "bytes")
}

# The bytes a string adds inside a JSON string. JSON escaping is per
# character, so the size of a concatenation is the sum of the sizes.
translation_json_bytes <- function(text) {
  nchar(jsonlite::toJSON(enc2utf8(text), auto_unbox = TRUE), type = "bytes") - 2L
}

# The encoded size of one text from its paragraphs' escaped sizes: two quotes
# and <qlm></qlm>, plus <p id=""></p> and the id for each of several. The
# wrappers are measured rather than counted, since JSON escapes "/" and '"'.
translation_deepl_item_bytes <- function(inner) {
  n <- length(inner)
  bytes <- 2 + translation_json_bytes("<qlm></qlm>") + sum(inner)
  if (n > 1L) {
    bytes <- bytes + n * translation_json_bytes('<p id=""></p>') + sum(nchar(seq_len(n)))
  }
  bytes
}

# Packs items into requests of at most 50 texts and 128 KiB. Sizes are
# computed once per paragraph and summed, so packing is linear in the input.
# An item too large for a request on its own is divided at paragraphs; no
# other document is divided.
translation_deepl_batches <- function(jobs, setup, items = translation_deepl_groups(jobs)) {
  inner <- vapply(jobs, function(job) translation_json_bytes(translation_deepl_inner(job)), 0)
  room <- deepl_max_bytes - translation_body_bytes(translation_deepl_body(jobs, list(), setup))
  too_large <- function() {
    cli::cli_abort("A DeepL segment and its context exceed 128 KiB; reduce {.arg chunk_size} or {.arg context}.")
  }
  parts <- list()
  for (item in items) {
    if (translation_deepl_item_bytes(inner[item]) <= room) {
      parts[[length(parts) + 1L]] <- item
      next
    }
    current <- integer()
    for (j in item) {
      if (length(current) && translation_deepl_item_bytes(inner[c(current, j)]) > room) {
        parts[[length(parts) + 1L]] <- current
        current <- integer()
      }
      current <- c(current, j)
      if (translation_deepl_item_bytes(inner[current]) > room) too_large()
    }
    parts[[length(parts) + 1L]] <- current
  }
  batches <- list()
  current <- list()
  used <- 0
  for (part in parts) {
    bytes <- translation_deepl_item_bytes(inner[part])
    if (length(current) &&
        (length(current) == deepl_max_texts || used + 1 + bytes > room)) {
      batches[[length(batches) + 1L]] <- current
      current <- list()
      used <- 0
    }
    used <- used + bytes + if (length(current)) 1 else 0
    current[[length(current) + 1L]] <- part
  }
  if (length(current)) batches[[length(batches) + 1L]] <- current
  batches
}

translation_deepl_request <- function(jobs, items, setup) {
  req <- httr2::request(setup$base_url)
  req <- httr2::req_url_path_append(req, "v2", "translate")
  req <- httr2::req_headers(req, Authorization = paste("DeepL-Auth-Key", setup$api_key))
  req <- httr2::req_body_json(req, translation_deepl_body(jobs, items, setup), auto_unbox = TRUE)
  req <- httr2::req_error(req, body = translation_deepl_error)
  req <- httr2::req_retry(req, max_tries = 3)
  httr2::req_throttle(req, capacity = 1, fill_time_s = 60 / setup$rpm,
                     realm = paste0("quallmer-deepl-paced-", translation_hash(setup$base_url)))
}

translation_deepl_error <- function(resp) {
  body <- tryCatch(httr2::resp_body_json(resp), error = function(e) NULL)
  if (rlang::is_string(body$message)) body$message else NULL
}

perform_translation_requests <- function(reqs, max_active, on_error) {
  httr2::req_perform_parallel(reqs, max_active = max_active,
                             on_error = on_error, progress = "Translating")
}

translation_deepl_jobs <- function(jobs, setup, max_active, rpm, on_error,
                                   items = translation_deepl_groups(jobs)) {
  out <- translation_deepl_send(jobs, items, setup, max_active, on_error)
  failed <- Filter(function(item) isTRUE(out[[item[1]]]$structure_failure), items)
  translation_deepl_split(jobs, out, failed, setup, max_active, on_error)
}

translation_deepl_send <- function(jobs, items, setup, max_active, on_error) {
  batches <- translation_deepl_batches(jobs, setup, items)
  reqs <- lapply(batches, function(batch) translation_deepl_request(jobs, batch, setup))
  responses <- perform_translation_requests(reqs, max_active, on_error)
  out <- vector("list", length(jobs))
  for (i in seq_along(batches)) {
    batch <- batches[[i]]
    idx <- unlist(batch)
    resp <- responses[[i]]
    if (is.null(resp)) next
    if (inherits(resp, "error")) {
      reason <- strip_ansi(conditionMessage(resp))
      reason <- gsub(setup$api_key, "[REDACTED]", reason, fixed = TRUE)
      out[idx] <- rep(list(list(text = NA_character_, error = reason,
        usage = NULL, finish = NA_character_)), length(idx))
      next
    }
    body <- tryCatch(httr2::resp_body_json(resp, simplifyVector = FALSE), error = function(e) NULL)
    if (!is.list(body$translations) || length(body$translations) != length(batch)) {
      out[idx] <- rep(list(list(text = NA_character_, error = "DeepL returned the wrong number of translations",
        usage = NULL, finish = NA_character_, stage = "content")), length(idx))
      next
    }
    for (g in seq_along(batch)) {
      out[batch[[g]]] <- parse_deepl_document(body$translations[[g]], length(batch[[g]]))
    }
  }
  out
}

# A document whose paragraph structure came back changed is sent again as two
# halves, in parallel with every other such document. A half that fails again
# is halved in turn only while its sibling succeeds, which isolates a problem
# paragraph; when both halves fail the failure is systematic and splitting
# stops. A single paragraph has no structure to lose and is left to the
# ordinary content retry.
translation_deepl_split <- function(jobs, out, items, setup, max_active, on_error) {
  depth <- 0L
  while (length(items)) {
    halves <- unlist(lapply(items, function(item) {
      h <- floor(length(item) / 2)
      list(item[seq_len(h)], item[-seq_len(h)])
    }), recursive = FALSE)
    positions <- unlist(halves)
    local <- lapply(halves, match, positions)
    child <- translation_deepl_send(jobs[positions], local, setup, max_active, on_error)
    for (k in seq_along(positions)) {
      pos <- positions[k]
      if (is.null(child[[k]])) next
      parent <- out[[pos]]
      parent$group_reduction <- depth
      record <- translation_attempt(jobs[[pos]], parent, parent$error, 0L)
      child[[k]]$group_reduction <- depth + 1L
      child[[k]]$prior_attempts <- c(parent$prior_attempts, list(record))
      out[[pos]] <- child[[k]]
    }
    failed <- vapply(halves, function(half) isTRUE(out[[half[1]]]$structure_failure), logical(1))
    items <- list()
    # Halves come in sibling pairs: 1 and 2, 3 and 4, ...
    for (first in seq(1L, length(halves), by = 2L)) {
      pair <- c(first, first + 1L)
      if (sum(failed[pair]) == 1L) {
        half <- halves[[pair[failed[pair]]]]
        if (length(half) > 1L) items[[length(items) + 1L]] <- half
      }
    }
    depth <- depth + 1L
  }
  out
}

parse_deepl_document <- function(value, n) {
  if (n == 1L) return(list(parse_deepl_translation(value)))
  paragraphs <- tryCatch({
    root <- xml2::read_xml(value$text, options = "NONET")
    nodes <- xml2::xml_children(root)
    if (xml2::xml_name(root) != "qlm" || length(nodes) != n ||
        any(xml2::xml_name(nodes) != "p") ||
        !identical(xml2::xml_attr(nodes, "id"), as.character(seq_len(n))) ||
        any(nzchar(trimws(xml2::xml_text(xml2::xml_find_all(root, "./text()")))))) {
      stop("unexpected document XML structure")
    }
    lapply(nodes, function(node) {
      xml2::xml_set_name(node, "qlm")
      as.character(node)
    })
  }, error = function(e) NULL)
  lapply(seq_len(n), function(i) {
    part <- value
    part$text <- if (is.null(paragraphs)) NA_character_ else paragraphs[[i]]
    # DeepL bills the complete document once, not once per paragraph.
    if (i > 1L) part$billed_characters <- NULL
    out <- parse_deepl_translation(part)
    # A changed paragraph structure is repaired by halving the document
    # rather than by the ordinary content retry.
    out$structure_failure <- is.null(paragraphs)
    out
  })
}

parse_deepl_translation <- function(value) {
  text <- tryCatch({
    if (!rlang::is_string(value$text)) stop("missing text")
    # NONET prevents network access; entity expansion and DTD loading are off.
    root <- xml2::read_xml(value$text, options = "NONET")
    if (xml2::xml_name(root) != "qlm" ||
        any(!xml2::xml_name(xml2::xml_find_all(root, ".//*")) %in% "keep")) {
      stop("unexpected XML structure")
    }
    xml2::xml_text(root)
  }, error = function(e) NA_character_)
  list(text = text, error = if (is.na(text)) "DeepL returned invalid translation XML" else NA_character_,
    usage = list(billed_characters = value$billed_characters),
    reported_model = value$model_type_used,
    detected_language = value$detected_source_language, finish = NA_character_, stage = "content")
}
