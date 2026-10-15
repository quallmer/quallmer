test_that("chat translation preserves structure, identifiers and provenance", {
  seen <- mock_translation_chat(function(text) sub("Bonjour", "Hello", text, fixed = TRUE))
  x <- c(a = "  Bonjour TERM\n \nBonjour encore  ", b = "Bonjour")
  out <- qlm_translate(x, model = "openai/test", protect = "TERM", context = "Interview",
                        instructions = "Keep the register.", params = ellmer::params(max_tokens = 100))
  expect_s3_class(out, "qlm_translation")
  expect_s3_class(out, "qlm_preprocessed")
  expect_identical(as.character(out), c(a = "  Hello TERM\n \nHello encore  ", b = "Hello"))
  prov <- attr(out, "provenance")
  expect_identical(prov$source_text, unname(x))
  expect_equal(prov$status, rep("ok", 2))
  expect_equal(prov$reported_model, rep("model-snapshot", 2))
  expect_equal(prov$detected_language, rep(NA_character_, 2))
  expect_equal(prov$source_hash, vapply(unname(x), translation_hash, "", USE.NAMES = FALSE))
  expect_equal(lengths(prov$attempts), c(2, 1))
  expect_equal(prov$settings[[1]]$params$max_tokens, 100)
  prompts <- lapply(seen$prompts, jsonlite::fromJSON)
  expect_equal(prompts[[1]]$background, "Interview")
  expect_null(prompts[[1]]$preceding_source_segment)
  expect_equal(prompts[[2]]$preceding_source_segment, "Bonjour TERM")
  expect_null(prompts[[3]]$preceding_source_segment)
})

test_that("DeepL translation runs with XML protection and no secret in provenance", {
  seen <- mock_translation_deepl(function(text) sub("Bonjour", "Hello", text, fixed = TRUE))
  out <- qlm_translate(c(a = "Bonjour TERM", b = "Bonjour & <world>"),
    model = "deepl/quality_optimized", target_lang = "en-GB", protect = "TERM",
    instructions = "Keep the register.", context = "Interview", api_key = "secret:fx")
  expect_equal(as.character(out), c(a = "Hello TERM", b = "Hello & <world>"))
  expect_length(seen$requests, 1)
  body <- seen$requests[[1]]$body$data
  expect_equal(body$context, "Interview")
  expect_equal(body$ignore_tags, list("keep"))
  prov <- attr(out, "provenance")
  expect_equal(prov$detected_language, c("FR", "FR"))
  expect_equal(prov$base_url, rep("https://api-free.deepl.com", 2))
  expect_true(all(vapply(prov$attempts, function(a) a[[1]]$usage$billed_characters > 0, logical(1))))
  expect_false(grepl("secret:fx", paste(capture.output(str(prov)), collapse = ""), fixed = TRUE))
})

test_that("input and backend options are validated before requests", {
  seen <- mock_translation_deepl()
  expect_error(qlm_translate("hello"), "model")
  expect_error(qlm_translate(character(), "openai/test"), "non-empty")
  expect_error(qlm_translate(c(a = "x", a = "y"), "openai/test"), "unique")
  expect_error(qlm_translate("x", "openai/test", chunk_size = 0), "positive")
  expect_error(qlm_translate("x", "openai/test", max_active = 0), "positive")
  expect_error(qlm_translate("x", "openai/test", glossary = "y"), "named")
  expect_error(qlm_translate("x", "deepl/quality_optimized", params = ellmer::params(temperature = 0)), "params")
  expect_error(qlm_translate("x", "deepl/quality_optimized", glossary = c(a = "b")), "not implemented")
  expect_error(qlm_translate("x", "deepl/quality_optimized", instructions = rep("a", 11)), "at most 10")
  expect_error(qlm_translate("x", "deepl/quality_optimized", instructions = paste(rep("a", 301), collapse = "")), "300")
  expect_error(qlm_translate("x", "openai/test", temperature = 0), "must be empty")
  expect_length(seen$requests, 0)
})

test_that("empty and missing sources need no translation requests", {
  seen <- mock_translation_chat()
  expect_warning(out <- qlm_translate(c(empty = "", blank = " \n\n ", missing = NA_character_), "openai/test"), "1 of 3")
  expect_length(seen$prompts, 0)
  expect_equal(as.character(out), c(empty = "", blank = " \n\n ", missing = NA_character_))
  expect_equal(attr(out, "provenance")$status, c("ok", "ok", "failed"))
})

test_that("protection failures get one repair and never return partial translations", {
  calls <- 0L
  mock_translation_chat(function(text) {
    calls <<- calls + 1L
    if (calls == 1L) "lost the marker" else text
  })
  out <- qlm_translate("TERM", "openai/test", protect = "TERM")
  expect_equal(unname(as.character(out)), "TERM")
  expect_equal(calls, 2)
  expect_length(attr(out, "provenance")$attempts[[1]], 2)
})

test_that("terminal validation failures obey each error policy", {
  seen <- mock_translation_chat(function(text) "a\n\nb")
  expect_warning(out <- qlm_translate(c(a = "one", b = "two"), "openai/test", on_error = "return"), "2 of 2")
  expect_true(all(is.na(out)))
  expect_length(seen$prompts, 3) # two initial calls, only the first repaired
  expect_error(suppressWarnings(qlm_translate("one", "openai/test", on_error = "stop")), "Translation failed")
})

test_that("truncation is retried smaller with all attempts recorded", {
  mock_translation_chat(function(text) {
    if (nchar(text) > 5) text_turn(text, finish_reason = "max_tokens") else text
  })
  out <- qlm_translate("abcdefghij", "openai/test", chunk_size = 20)
  expect_equal(unname(as.character(out)), "abcdefghij")
  attempts <- attr(out, "provenance")$attempts[[1]]
  expect_length(attempts, 3)
  expect_equal(vapply(attempts, `[[`, integer(1), "reduction"), c(0L, 1L, 1L))
  expect_match(attempts[[1]]$error, "token limit")
  expect_true(is.na(attempts[[2]]$error))
})

test_that("unsupported parameter warnings are deduplicated and recorded", {
  mock_translation_chat(function(text) {
    warning("Ignoring unsupported parameters: reasoning_tokens")
    text
  })
  expect_warning(out <- qlm_translate(c(a = "one", b = "two"), "openai/test",
    params = ellmer::params(reasoning_tokens = 10)), "Ignoring unsupported parameters")
  prov <- attr(out, "provenance")
  expect_equal(prov$settings[[1]]$params$reasoning_tokens, 10)
  expect_equal(prov$attempts[[1]][[1]]$warnings, "Ignoring unsupported parameters: reasoning_tokens")
})

test_that("transport failures and unsubmitted segments remain aligned", {
  mock_translation_chat(function(text) {
    if (text == "fail") simpleError("endpoint refused") else if (text == "unsent") NULL else text
  })
  expect_warning(out <- qlm_translate(c(a = "ok", b = "fail", c = "unsent"), "openai/test"), "1 of 3")
  expect_equal(attr(out, "provenance")$status, c("ok", "failed", "unsubmitted"))
  expect_equal(as.character(out), c(a = "ok", b = NA_character_, c = NA_character_))
})

test_that("preprocessing survives translation, coding and replication", {
  mock_translation_chat()
  transcripts <- fake_transcript(c("a", "b"), c("hello", "world"))
  out <- qlm_translate(transcripts, "openai/test")
  records <- preprocessing_record(out)
  expect_equal(vapply(records$a, `[[`, "", "stage"), c("transcription", "translation"))
  expect_false("source_text" %in% names(records$a[[2]]$provenance))
  runner <- text_runner(tibble::tibble(score = c(1, 2)))
  coded <- runner(out, score_codebook(), model = "openai/gpt-4o-mini")
  expect_null(attr(inputs(coded), "provenance"))
  expect_identical(qlm_meta(coded, "preprocessing", type = "user"), records)
  replicate <- qlm_replicate
  mockery::stub(replicate, "qlm_code", runner)
  copy <- replicate(coded, model = "openai/gpt-4o-mini")
  expect_identical(qlm_meta(copy, "preprocessing", type = "user"), records)
  expect_match(paste(preprocessing_lines(records), collapse = "\n"), "translated with")
  expect_match(paste(preprocessing_lines(records), collapse = "\n"), "transcribed with")
  path <- tempfile("translation-trail")
  trail <- suppressMessages(qlm_trail(coded, path = path))
  expect_identical(trail$runs[[1]]$preprocessing, records)
  expect_match(paste(readLines(paste0(path, ".qmd")), collapse = "\n"), "translated with")
  expect_identical(readRDS(paste0(path, ".rds"))$runs[[1]]$preprocessing, records)
})

test_that("saved transcripts from before the shared parent retain their history", {
  mock_translation_chat()
  transcripts <- fake_transcript("a", "hello")
  class(transcripts) <- c("qlm_transcript", "character")
  out <- qlm_translate(transcripts, "openai/test")
  expect_equal(preprocessing_record(out)$a[[1]]$stage, "transcription")
})

test_that("repeated translation compacts every stage before copying to a coded run", {
  mock_translation_chat()
  first <- qlm_translate(c(a = "one\n\ntwo"), "openai/test", protect = "one")
  second <- qlm_translate(first, "openai/test")
  steps <- preprocessing_record(second)$a
  expect_length(steps, 2)
  for (step in steps) {
    expect_null(step$provenance$source_text)
    for (attempt in step$provenance$attempts[[1]]) {
      expect_null(attempt[["neighbouring_context", exact = TRUE]])
      expect_null(attempt$markers)
    }
  }
})

test_that("missing translated inputs are never coded or retried as coding failures", {
  mock_translation_chat(function(text) if (text == "bad") simpleError("translation refused") else text)
  expect_warning(out <- qlm_translate(c(a = "good", b = "bad"), "openai/test"), "1 of 2")
  calls <- new.env()
  runner <- text_runner(tibble::tibble(score = 1), calls = calls)
  coded <- suppressMessages(runner(out, score_codebook(), model = "openai/gpt-4o-mini"))
  expect_length(calls$prompts, 1)
  expect_true(is_absent_input(coded$.error[[2]]))
  expect_match(conditionMessage(coded$.error[[2]]), "no translation: translation refused")
  expect_true(is_terminal_failure(list(coded$.error[[2]])))
})

test_that("missing input stops new submissions under return and stop", {
  seen <- mock_translation_chat()
  expect_warning(out <- qlm_translate(c(a = "good", b = NA_character_, c = "later"),
    "openai/test", on_error = "return"), "1 of 3")
  expect_length(seen$prompts, 1)
  expect_equal(attr(out, "provenance")$status, c("ok", "failed", "unsubmitted"))
  expect_error(qlm_translate(c("good", NA_character_), "openai/test", on_error = "stop"), "source text is missing")
  expect_length(seen$prompts, 1)
})

test_that("malformed DeepL output is retried once and preserves attempted usage", {
  calls <- 0L
  httr2::local_mocked_responses(function(req) {
    calls <<- calls + 1L
    text <- if (calls == 1) "not XML" else req$body$data$text[[1]]
    httr2::response_json(body = list(translations = list(list(
      text = text, billed_characters = 5, model_type_used = "quality_optimized",
      detected_source_language = "FR"
    ))))
  })
  out <- qlm_translate("Bonjour", "deepl/quality_optimized", api_key = "test")
  expect_equal(unname(as.character(out)), "Bonjour")
  expect_length(attr(out, "provenance")$attempts[[1]], 2)
  expect_equal(calls, 2)
})
