# Paragraph separators are retained outside the model. Atomic newline tokens
# prevent a single CRLF from backtracking into two newline characters.
translation_paragraph_pattern <- function() {
  "(?>\\r\\n|\\r|\\n)[\\t ]*(?>\\r\\n|\\r|\\n)(?:[\\t ]*(?>\\r\\n|\\r|\\n))*"
}

translation_plan <- function(text, size, protect) {
  if (is.na(text)) return(NULL)
  breaks <- gregexpr(translation_paragraph_pattern(), text, perl = TRUE)[[1]]
  ends <- if (breaks[1] < 0L) integer() else breaks + attr(breaks, "match.length") - 1L
  starts <- c(1L, ends + 1L)
  stops <- c(if (length(ends)) breaks - 1L, nchar(text))
  separators <- if (length(ends)) substring(text, breaks, ends) else character()
  paragraphs <- vector("list", length(starts))
  for (i in seq_along(starts)) {
    raw <- substring(text, starts[i], stops[i])
    masked <- mask_translation_terms(raw, protect)
    pieces <- split_translation_segment(masked$text, size, masked$prefix)
    paragraphs[[i]] <- list(pieces = pieces, markers = masked$markers,
                            marker_prefix = masked$prefix,
                            separator = if (i <= length(separators)) separators[i] else "")
  }
  paragraphs
}

mask_translation_terms <- function(text, protect) {
  prefix <- paste0("QLMKEEP", substr(translation_hash(text), 1L, 12L), "_")
  while (grepl(prefix, text, fixed = TRUE)) prefix <- paste0(prefix, "X")
  spans <- list()
  for (pattern in protect) {
    found <- tryCatch(gregexpr(pattern, text, perl = TRUE)[[1]], error = function(e) {
      cli::cli_abort("Invalid {.arg protect} expression {.val {pattern}}: {conditionMessage(e)}")
    })
    if (found[1] < 0L) next
    widths <- attr(found, "match.length")
    if (any(widths == 0L)) cli::cli_abort("{.arg protect} must not match empty strings.")
    spans <- c(spans, Map(function(a, b) c(start = a, end = a + b - 1L), found, widths))
  }
  if (!length(spans)) return(list(text = text, markers = character(), prefix = prefix))
  spans <- unique(do.call(rbind, spans))
  spans <- spans[order(spans[, "start"]), , drop = FALSE]
  if (nrow(spans) > 1L && any(spans[-1L, "start"] <= spans[-nrow(spans), "end"])) {
    cli::cli_abort("Matches in {.arg protect} must not overlap.")
  }
  markers <- stats::setNames(substring(text, spans[, "start"], spans[, "end"]),
                            paste0(prefix, seq_len(nrow(spans)), "END"))
  for (i in rev(seq_len(nrow(spans)))) {
    text <- paste0(substr(text, 1L, spans[i, "start"] - 1L), names(markers)[i],
                   substring(text, spans[i, "end"] + 1L))
  }
  list(text = text, markers = markers, prefix = prefix)
}

# Each piece keeps edge whitespace locally. Offsets refer to the masked
# paragraph; storing the marker map makes that representation reconstructible.
split_translation_segment <- function(text, size, marker_prefix) {
  pieces <- list()
  offset <- 1L
  while (nzchar(text)) {
    cut <- min(size, nchar(text))
    kind <- "paragraph"
    if (cut < nchar(text)) {
      head <- substr(text, 1L, cut)
      sentence <- gregexpr("[.!?\u3002\uff01\uff1f](?:[[:space:]]|$)", head, perl = TRUE)[[1]]
      space <- gregexpr("[[:space:]]+", head, perl = TRUE)[[1]]
      if (sentence[1] > 0L) {
        cut <- utils::tail(sentence + attr(sentence, "match.length") - 1L, 1L)
        kind <- "sentence"
      } else if (space[1] > 0L && utils::tail(space, 1L) > 1L) {
        cut <- utils::tail(space + attr(space, "match.length") - 1L, 1L)
        kind <- "whitespace"
      } else kind <- "code_point"
      matches <- gregexpr(paste0(marker_prefix, "[0-9]+END"), text, perl = TRUE)[[1]]
      if (matches[1] > 0L) {
        ends <- matches + attr(matches, "match.length") - 1L
        crossing <- which(matches <= cut & ends > cut)
        if (length(crossing)) {
          cut <- matches[crossing[1]] - 1L
          if (cut == 0L) {
            cli::cli_abort("{.arg chunk_size} is too small to hold a protection marker.")
          }
        }
      }
    }
    raw <- substr(text, 1L, cut)
    leading <- regmatches(raw, regexpr("^[[:space:]]*", raw, perl = TRUE))
    trailing <- regmatches(raw, regexpr("[[:space:]]*$", raw, perl = TRUE))
    core <- trimws(raw, whitespace = "[[:space:]]")
    if (!nzchar(core)) {
      leading <- raw
      trailing <- ""
    }
    pieces[[length(pieces) + 1L]] <- list(text = core, before = leading,
      after = trailing, start = offset, end = offset + cut - 1L, split = kind)
    offset <- offset + cut
    text <- substring(text, cut + 1L)
  }
  if (!length(pieces)) {
    pieces <- list(list(text = "", before = "", after = "", start = 1L,
                        end = 0L, split = "paragraph"))
  }
  pieces
}

translation_markers <- function(text, prefix) {
  found <- gregexpr(paste0(prefix, "[0-9]+END"), text, perl = TRUE)
  regmatches(text, found)[[1]]
}

validate_translation_text <- function(text, job) {
  if (!rlang::is_string(text) || !nzchar(trimws(text))) {
    return("the model returned no translation text")
  }
  if (!isTRUE(job$document_text) && grepl(translation_paragraph_pattern(), text, perl = TRUE)) {
    return("the model introduced a paragraph separator inside a segment")
  }
  expected <- sort(translation_markers(job$text, job$marker_prefix))
  actual <- sort(translation_markers(text, job$marker_prefix))
  if (!identical(expected, actual)) {
    return("protected markers were missing, duplicated or changed")
  }
  NULL
}

restore_translation_terms <- function(text, markers) {
  for (marker in names(markers)) {
    start <- regexpr(marker, text, fixed = TRUE)[1]
    if (start > 0L) {
      text <- paste0(substr(text, 1L, start - 1L), markers[[marker]],
                     substring(text, start + nchar(marker)))
    }
  }
  text
}
