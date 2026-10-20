# High-level scheduling keeps each request associated with its source position.
# Chat prompts use individual segments; DeepL combines them into document XML.
run_translation_plans <- function(plans, setup, max_active, rpm, on_error) {
  jobs <- list()
  first_missing <- which(vapply(plans, is.null, logical(1)))[1]
  for (d in seq_along(plans)) {
    if (on_error == "return" && !is.na(first_missing) && d > first_missing) next
    previous <- NULL
    for (p in seq_along(plans[[d]])) {
      paragraph <- plans[[d]][[p]]
      for (s in seq_along(paragraph$pieces)) {
        piece <- paragraph$pieces[[s]]
        if (!nzchar(piece$text)) next
        jobs[[length(jobs) + 1L]] <- c(piece, list(document = d, paragraph = p,
          segment = s, context = if (setup$adapter$name == "generic") previous else NULL,
          marker_prefix = paragraph$marker_prefix,
          markers = paragraph$markers,
          document_text = identical(setup$adapter$name, "google-translate")))
        previous <- restore_translation_terms(piece$text, paragraph$markers)
      }
    }
  }
  # Request packing errors, including oversized background, are found before
  # any request is sent. The same check runs for reduced retry segments.
  if (setup$adapter$name == "deepl" && length(jobs)) {
    translation_deepl_batches(jobs, setup)
  }
  outcomes <- if (length(jobs)) translation_jobs(jobs, setup, max_active, rpm, on_error) else list()
  depths <- integer(length(jobs))
  if (on_error == "continue" && length(jobs)) {
    # Content repairs go out together, so they run in parallel and DeepL
    # packs the paragraphs of one document into one text again. The other
    # policies stop at the first failure, so they repair in order below.
    checks <- lapply(seq_along(jobs), function(i) {
      if (!is.null(outcomes[[i]])) check_translation_outcome(jobs[[i]], outcomes[[i]], setup, 0L)
    })
    retry <- which(vapply(checks, function(check) isTRUE(check$can_retry), logical(1)))
    if (length(retry)) {
      retried <- translation_jobs(jobs[retry], setup, max_active, rpm, on_error)
      for (k in seq_along(retry)) {
        i <- retry[k]
        if (is.null(retried[[k]])) next
        retried[[k]]$prior_attempts <- c(checks[[i]]$attempts, retried[[k]]$prior_attempts)
        outcomes[[i]] <- retried[[k]]
        depths[i] <- 1L
      }
    }
  }
  attempts <- rep(list(list()), length(plans))
  text <- rep(NA_character_, length(plans))
  errors <- rep(NA_character_, length(plans))
  status <- rep("ok", length(plans))
  values <- rep(list(list()), length(plans))
  stopped <- FALSE
  for (i in seq_along(jobs)) {
    job <- jobs[[i]]
    d <- job$document
    outcome <- outcomes[[i]]
    # All pool outcomes have already arrived. Only further repair requests
    # are withheld once a terminal failure triggers return.
    checked <- finish_translation_job(job, outcome, setup, max_active, rpm,
      on_error, repair = !stopped, depth = depths[i])
    attempts[[d]] <- c(attempts[[d]], checked$attempts)
    values[[d]][[paste(job$paragraph, job$segment, sep = ":")]] <- checked$text
    if (!is.na(checked$error)) {
      errors[d] <- paste(unique(c(if (!is.na(errors[d])) errors[d], checked$error)), collapse = "; ")
      status[d] <- if (is.null(outcome) && status[d] != "failed") "unsubmitted" else "failed"
      if (on_error == "stop") {
        id <- names(plans)[d] %||% paste0("text", d)
        cli::cli_abort("Translation failed for {.val {id}}: {checked$error}",
          translation_id = id, translation_attempts = attempts[[d]])
      }
      if (on_error == "return") stopped <- TRUE
    }
  }
  for (d in seq_along(plans)) {
    if (on_error == "return" && !is.na(first_missing) && d > first_missing) {
      status[d] <- "unsubmitted"
      errors[d] <- "not submitted after an earlier source text was missing"
      next
    }
    if (is.null(plans[[d]])) {
      status[d] <- "failed"
      errors[d] <- "source text is missing"
      if (on_error == "stop") cli::cli_abort("Translation failed: source text is missing.")
      next
    }
    if (status[d] != "ok") next
    paragraphs <- character(length(plans[[d]]))
    for (p in seq_along(plans[[d]])) {
      paragraph <- plans[[d]][[p]]
      segments <- character(length(paragraph$pieces))
      for (s in seq_along(paragraph$pieces)) {
        piece <- paragraph$pieces[[s]]
        translated <- if (nzchar(piece$text)) values[[d]][[paste(p, s, sep = ":")]] else ""
        segments[s] <- paste0(piece$before, translated, piece$after)
      }
      paragraphs[p] <- paste0(paste0(segments, collapse = ""), paragraph$separator)
    }
    text[d] <- paste0(paragraphs, collapse = "")
  }
  warnings <- unique(unlist(lapply(attempts, function(a) unlist(lapply(a, `[[`, "warnings")))))
  for (warning in warnings) cli::cli_warn(warning)
  list(text = text, status = status, error = errors, attempts = attempts)
}

translation_jobs <- function(jobs, setup, max_active, rpm, on_error) {
  if (setup$adapter$name == "deepl") {
    translation_deepl_jobs(jobs, setup, max_active, rpm, on_error)
  } else if (setup$adapter$name == "google-translate") {
    translation_google_jobs(jobs, setup, max_active, on_error)
  } else if (setup$adapter$name == "qwen-mt") {
    translation_qwen_jobs(jobs, setup, max_active, rpm, on_error)
  } else translation_chat_jobs(jobs, setup, max_active, rpm, on_error)
}

finish_translation_job <- function(job, outcome, setup, max_active, rpm,
                                   on_error, repair = TRUE, depth = 0L) {
  if (is.null(outcome)) {
    return(list(text = NA_character_, error = "not submitted after an earlier translation failed",
                attempts = list()))
  }
  check <- check_translation_outcome(job, outcome, setup, depth)
  reason <- check$reason
  attempts <- check$attempts
  if (is.na(reason)) {
    return(list(text = restore_translation_terms(trimws(outcome$text), job$markers),
                error = NA_character_, attempts = attempts))
  }
  can_reduce <- check$can_reduce
  if (!repair || (!can_reduce && !check$can_retry)) {
    return(list(text = NA_character_, error = reason, attempts = attempts))
  }
  if (can_reduce) {
    pieces <- tryCatch(split_translation_segment(job$text,
      max(1L, floor(nchar(job$text) / 2L)), job$marker_prefix), error = function(e) NULL)
    if (is.null(pieces) || length(pieces) < 2L) {
      return(list(text = NA_character_, error = reason, attempts = attempts))
    }
    reduced <- lapply(pieces, function(piece) {
      child <- job
      child[names(piece)] <- piece
      child$start <- job$start + piece$start - 1L
      child$end <- job$start + piece$end - 1L
      child
    })
  } else {
    pieces <- list(list(before = "", after = ""))
    reduced <- list(job)
  }
  outputs <- character(length(reduced))
  for (i in seq_along(reduced)) {
    if (!nzchar(reduced[[i]]$text)) {
      outputs[i] <- paste0(pieces[[i]]$before, pieces[[i]]$after)
      next
    }
    retry <- translation_jobs(reduced[i], setup, max_active, rpm, on_error)[[1]]
    checked <- finish_translation_job(reduced[[i]], retry, setup, max_active, rpm,
      on_error, repair = TRUE, depth = depth + 1L)
    attempts <- c(attempts, checked$attempts)
    if (!is.na(checked$error)) {
      return(list(text = NA_character_, error = checked$error, attempts = attempts))
    }
    outputs[i] <- paste0(pieces[[i]]$before, checked$text, pieces[[i]]$after)
  }
  list(text = paste0(outputs, collapse = ""), error = NA_character_, attempts = attempts)
}

# What went wrong with an outcome, if anything, and which repair it allows.
# Transport errors already receive transport retries. Content failures get
# one repair; chat truncation gets at most two halvings. Qwen-MT also
# recognises its explicit native input-length rejection, with eight levels.
# A DeepL document whose paragraph structure changed was already repaired by
# halving and gets no further retry.
check_translation_outcome <- function(job, outcome, setup, depth) {
  reason <- outcome$error %||% NA_character_
  truncated <- identical(outcome$finish, "max_tokens")
  input_too_long <- isTRUE(outcome$input_too_long)
  if (truncated) reason <- "the model reached its output token limit"
  if (is.na(reason) && !is.null(outcome$finish) && !is.na(outcome$finish) &&
      !identical(outcome$finish, "success")) {
    reason <- paste0("the model did not complete its response: ", outcome$finish)
  }
  if (is.na(reason)) reason <- validate_translation_text(outcome$text, job) %||% NA_character_
  attempt <- translation_attempt(job, outcome, reason, depth)
  transport_ok <- is.na(outcome$error %||% NA_character_) || identical(outcome$stage, "content")
  limit <- if (setup$adapter$name == "qwen-mt") 8L else 2L
  list(reason = reason,
       attempts = c(outcome$prior_attempts %||% list(), list(attempt)),
       can_reduce = (truncated || input_too_long) && depth < limit && nchar(job$text) > 1L,
       can_retry = !is.na(reason) && !truncated && !input_too_long && transport_ok &&
         depth == 0L && !isTRUE(outcome$structure_failure))
}

translation_attempt <- function(job, outcome, error, reduction) {
  list(paragraph = job$paragraph, segment = job$segment, start = job$start,
    end = job$end, split = job$split, marker_prefix = job$marker_prefix,
    markers = job$markers, neighbouring_context = outcome$neighbouring_context,
    timestamp = Sys.time(), reduction = reduction, finish = outcome$finish,
    reported_model = outcome$reported_model, detected_language = outcome$detected_language,
    usage = outcome$usage, warnings = outcome$warnings, error = error,
    request_id = outcome$request_id, group_size = outcome$group_size,
    boundary_prefix = outcome$boundary_prefix,
    group_reduction = outcome$group_reduction,
    protection_ok = is.na(error))
}
