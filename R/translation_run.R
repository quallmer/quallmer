# High-level scheduling keeps each request associated with its source position.
# Paragraphs are never joined inside a prompt in this conservative first pass.
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
          segment = s, context = previous, marker_prefix = paragraph$marker_prefix,
          markers = paragraph$markers))
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
      on_error, repair = !stopped)
    attempts[[d]] <- c(attempts[[d]], checked$attempts)
    values[[d]][[paste(job$paragraph, job$segment, sep = ":")]] <- checked$text
    if (!is.na(checked$error)) {
      errors[d] <- paste(unique(c(if (!is.na(errors[d])) errors[d], checked$error)), collapse = "; ")
      status[d] <- if (is.null(outcome) && status[d] != "failed") "unsubmitted" else "failed"
      if (on_error == "stop") cli::cli_abort("Translation failed: {checked$error}")
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
  } else translation_chat_jobs(jobs, setup, max_active, rpm, on_error)
}

finish_translation_job <- function(job, outcome, setup, max_active, rpm,
                                   on_error, repair = TRUE, depth = 0L) {
  if (is.null(outcome)) {
    return(list(text = NA_character_, error = "not submitted after an earlier translation failed",
                attempts = list()))
  }
  reason <- outcome$error %||% NA_character_
  truncated <- identical(outcome$finish, "max_tokens")
  if (truncated) reason <- "the model reached its output token limit"
  if (is.na(reason) && !is.null(outcome$finish) && !is.na(outcome$finish) &&
      !identical(outcome$finish, "success")) {
    reason <- paste0("the model did not complete its response: ", outcome$finish)
  }
  if (is.na(reason)) reason <- validate_translation_text(outcome$text, job) %||% NA_character_
  attempt <- translation_attempt(job, outcome, reason, depth)
  if (is.na(reason)) {
    return(list(text = restore_translation_terms(trimws(outcome$text), job$markers),
                error = NA_character_, attempts = list(attempt)))
  }
  # Transport errors already receive transport retries. Content failures get
  # one repair; truncation gets at most two halvings. No semantic guess is
  # made from provider-specific input-limit error messages.
  transport_ok <- is.na(outcome$error %||% NA_character_) || identical(outcome$stage, "content")
  can_reduce <- truncated && depth < 2L && nchar(job$text) > 1L
  can_retry <- !truncated && transport_ok && depth == 0L
  if (!repair || (!can_reduce && !can_retry)) {
    return(list(text = NA_character_, error = reason, attempts = list(attempt)))
  }
  if (can_reduce) {
    pieces <- tryCatch(split_translation_segment(job$text,
      max(1L, floor(nchar(job$text) / 2L)), job$marker_prefix), error = function(e) NULL)
    if (is.null(pieces) || length(pieces) < 2L) {
      return(list(text = NA_character_, error = reason, attempts = list(attempt)))
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
  attempts <- list(attempt)
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

translation_attempt <- function(job, outcome, error, reduction) {
  list(paragraph = job$paragraph, segment = job$segment, start = job$start,
    end = job$end, split = job$split, marker_prefix = job$marker_prefix,
    markers = job$markers, neighbouring_context = job$context,
    timestamp = Sys.time(), reduction = reduction, finish = outcome$finish,
    reported_model = outcome$reported_model, detected_language = outcome$detected_language,
    usage = outcome$usage, warnings = outcome$warnings, error = error,
    protection_ok = is.na(error))
}
