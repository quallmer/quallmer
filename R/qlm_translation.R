# Histories are per document so that subsetting, concatenation and retries
# can combine documents with different preprocessing chains safely.
preprocessing_history <- function(x, compact = FALSE) {
  if (!is_qlm_preprocessed(x)) return(rep(list(list()), length(translation_texts(x))))
  provenance <- if (is_qlm_translation(x)) translation_provenance(x) else attr(x, "provenance")
  stage <- if (is_qlm_translation(x)) "translation" else "transcription"
  lapply(seq_len(nrow(provenance)), function(i) {
    row <- provenance[i, , drop = FALSE]
    history <- if ("history" %in% names(row)) row$history[[1]] else list()
    row$history <- NULL
    row$source_text <- NULL
    steps <- c(history, list(list(stage = stage, provenance = row)))
    if (compact) lapply(steps, compact_preprocessing_step) else steps
  })
}

is_qlm_preprocessed <- function(x) {
  # Saved transcript vectors made before the shared parent existed still
  # carry valid provenance and must keep it when they are translated.
  inherits(x, "qlm_preprocessed") || inherits(x, "qlm_transcript") || is_qlm_translation(x)
}

compact_preprocessing_step <- function(step) {
  row <- step$provenance
  row$source_text <- NULL
  if ("attempts" %in% names(row)) {
    row$attempts[[1]] <- lapply(row$attempts[[1]], compact_translation_attempt)
  }
  step$provenance <- row
  step
}

compact_translation_attempt <- function(attempt) {
  context <- attempt[["neighbouring_context", exact = TRUE]]
  if (!is.null(context)) {
    attempt$neighbouring_context_hash <- translation_hash(context)
  }
  attempt$neighbouring_context <- NULL
  attempt$markers <- NULL
  attempt
}

preprocessing_record <- function(x) {
  stats::setNames(preprocessing_history(x, compact = TRUE), translation_ids(x))
}

preprocessing_lines <- function(records) {
  if (!length(records)) return(character())
  lines <- c("**Text preprocessing:**", "")
  for (id in names(records)) {
    for (step in records[[id]]) {
      row <- step$provenance
      if (step$stage == "translation") {
        lines <- c(lines, paste0("- `", id, "`: translated with `", row$model,
          "` (", row$adapter, ") to ", row$target_lang, "; status: ", row$status,
          "; source SHA-256: `", row$source_hash, "`; output SHA-256: `", row$output_hash, "`."))
      } else {
        lines <- c(lines, paste0("- `", id, "`: transcribed with `", row$model,
          "`; source SHA-256: `", row$sha256, "`; status: ", row$status, "."))
      }
    }
  }
  c(lines, "")
}
