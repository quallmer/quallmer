test_that("chat translation preserves structure, identifiers and provenance", {
  seen <- mock_translation_chat(function(text) sub("Bonjour", "Hello", text, fixed = TRUE))
  x <- c(a = "  Bonjour TERM\n \nBonjour encore  ", b = "Bonjour")
  out <- qlm_translate(x, model = "openai/test", protect = "TERM", context = "Interview",
                        instructions = "Keep the register.", params = ellmer::params(max_tokens = 100))
  expect_s3_class(out, "qlm_translation")
  expect_s3_class(out, "qlm_preprocessed")
  expect_identical(as.character(out), c(a = "  Hello TERM\n \nHello encore  ", b = "Hello"))
  prov <- translation_provenance(out)
  expect_identical(prov$source_text, unname(x))
  expect_equal(prov$status, rep("ok", 2))
  expect_equal(prov$detected_language, rep(NA_character_, 2))
  expect_equal(prov$source_hash, vapply(unname(x), translation_hash, "", USE.NAMES = FALSE))
  expect_equal(lengths(prov$attempts), c(2, 1))
  expect_equal(prov$settings[[1]]$params$max_tokens, 100)
  expect_equal(prov$settings[[1]]$chunk_size, 200)
  # Both paragraphs of a document go in one request, by ID; usage is
  # recorded once per request
  expect_equal(seen$calls, 1)
  expect_length(seen$units, 2)
  expect_equal(seen$units[[1]]$background, "Interview")
  expect_null(seen$units[[1]]$preceding_source_text)
  expect_equal(vapply(seen$units[[1]]$paragraphs, `[[`, "", "id"), c("1", "2"))
  expect_length(seen$units[[2]]$paragraphs, 1)
  attempts <- prov$attempts[[1]]
  expect_gt(attempts[[1]]$usage$input_tokens, 0)
  expect_null(attempts[[2]]$usage)
  expect_identical(attempts[[1]]$group_size, 2L)
})

test_that("chat groups respect the size budget and carry the preceding text", {
  seen <- mock_translation_chat()
  doc <- paste(sprintf("Paragraph %02d.", 1:10), collapse = "\n\n")
  expect_no_warning(out <- qlm_translate(c(a = doc), "openai/test", chunk_size = 40))
  expect_identical(unname(as.character(out)), doc)
  expect_equal(seen$calls, 1)
  expect_equal(lengths(lapply(seen$units, `[[`, "paragraphs")), c(3, 3, 3, 1))
  expect_null(seen$units[[1]]$preceding_source_text)
  expect_equal(seen$units[[2]]$preceding_source_text, "Paragraph 03.")
  expect_equal(attr(out, "provenance")$attempts[[1]][[4]]$neighbouring_context, "Paragraph 03.")
})

test_that("a group with wrong paragraph IDs is halved", {
  seen <- mock_translation_chat()
  calls <- 0L
  testthat::local_mocked_bindings(structured_chat_turns = function(chat, prompts, type, batch = FALSE,
                                                                   execution_args = list()) {
    calls <<- calls + 1L
    lapply(prompts, function(prompt) {
      unit <- jsonlite::fromJSON(prompt, simplifyVector = FALSE)
      translations <- lapply(unit$paragraphs, function(p) list(id = p$id, text = p$text))
      # A group of four loses a paragraph; smaller groups come back whole
      if (length(translations) == 4L) translations <- translations[-2]
      json_turn(list(translations = translations))
    })
  })
  doc <- paste(c("one", "two", "three", "four"), collapse = "\n\n")
  out <- qlm_translate(c(a = doc), "openai/test")
  expect_identical(unname(as.character(out)), doc)
  expect_equal(calls, 2)
  attempts <- attr(out, "provenance")$attempts[[1]]
  expect_match(attempts[[1]]$error, "paragraph IDs")
  expect_equal(attempts[[2]]$group_reduction, 1L)
})

test_that("a truncated group is halved before a single segment is", {
  mock_translation_chat()
  calls <- 0L
  testthat::local_mocked_bindings(structured_chat_turns = function(chat, prompts, type, batch = FALSE,
                                                                   execution_args = list()) {
    calls <<- calls + 1L
    lapply(prompts, function(prompt) {
      unit <- jsonlite::fromJSON(prompt, simplifyVector = FALSE)
      if (length(unit$paragraphs) > 2L) return(text_turn("{", finish_reason = "max_tokens"))
      json_turn(list(translations = lapply(unit$paragraphs, function(p) list(id = p$id, text = p$text))))
    })
  })
  doc <- paste(c("one", "two", "three", "four"), collapse = "\n\n")
  out <- qlm_translate(c(a = doc), "openai/test")
  expect_identical(unname(as.character(out)), doc)
  expect_equal(calls, 2)
  attempts <- attr(out, "provenance")$attempts[[1]]
  expect_match(attempts[[1]]$error, "max_tokens|output")
  expect_identical(attempts[[1]]$finish, "max_tokens")
  expect_equal(attempts[[1]]$reduction, 0L)
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
  prov <- translation_provenance(out)
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

test_that("DeepL sends whole documents while retaining local whitespace and markers", {
  seen <- mock_translation_deepl(function(text) gsub("Bonjour", "Hello", text, fixed = TRUE))
  input <- c(a = "  Bonjour TERM\r\n \r\nBonjour TERM  ", b = "Bonjour\n\nencore")
  out <- qlm_translate(input, "deepl/quality_optimized", protect = "TERM", api_key = "test")
  expect_identical(as.character(out), gsub("Bonjour", "Hello", input, fixed = TRUE))
  expect_length(seen$requests, 1)
  expect_length(seen$requests[[1]]$body$data$text, 2)
  xml <- xml2::read_xml(seen$requests[[1]]$body$data$text[[1]])
  expect_length(xml2::xml_find_all(xml, ".//p"), 2)
  expect_length(xml2::xml_find_all(xml, ".//keep"), 2)
  attempts <- translation_provenance(out)$attempts[[1]]
  expect_null(attempts[[1]]$neighbouring_context)
  expect_null(attempts[[2]]$neighbouring_context)
  expect_gt(attempts[[1]]$usage$billed_characters, 0)
  expect_null(attempts[[2]]$usage$billed_characters)
})

test_that("many-paragraph documents fit in a single DeepL request", {
  seen <- mock_translation_deepl()
  input <- stats::setNames(rep(paste(rep("Bonjour à tous.", 82), collapse = "\n\n"), 3),
                          c("French", "German", "Spanish"))
  out <- qlm_translate(input, "deepl/quality_optimized", api_key = "test")
  expect_identical(as.character(out), input)
  expect_length(seen$requests, 1)
  expect_length(seen$requests[[1]]$body$data$text, 3)
  expect_equal(lengths(translation_provenance(out)$attempts), rep(82, 3))
})

test_that("empty and missing sources need no translation requests", {
  seen <- mock_translation_chat()
  expect_warning(out <- qlm_translate(c(empty = "", blank = " \n\n ", missing = NA_character_), "openai/test"), "1 of 3")
  expect_length(seen$prompts, 0)
  expect_equal(as.character(out), c(empty = "", blank = " \n\n ", missing = NA_character_))
  expect_equal(translation_provenance(out)$status, c("ok", "ok", "failed"))
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
  expect_length(translation_provenance(out)$attempts[[1]], 2)
})

test_that("content repairs are sent together rather than one at a time", {
  attempts <- new.env()
  seen <- mock_translation_chat(function(text) {
    attempts[[text]] <- (attempts[[text]] %||% 0L) + 1L
    if (attempts[[text]] == 1L) "lost the marker" else text
  })
  out <- qlm_translate(c(a = "TERM one", b = "TERM two", c = "TERM three"), "openai/test",
                       protect = "TERM")
  expect_identical(as.character(out), c(a = "TERM one", b = "TERM two", c = "TERM three"))
  expect_equal(seen$calls, 2)
  expect_length(seen$prompts, 6)
  expect_equal(lengths(attr(out, "provenance")$attempts), c(2, 2, 2))
})

test_that("a DeepL document with a changed structure is halved to isolate the problem", {
  requests <- 0L
  httr2::local_mocked_responses(function(req) {
    requests <<- requests + 1L
    httr2::response_json(body = list(translations = lapply(req$body$data$text, function(text) {
      # A document containing "poison" among other paragraphs loses one.
      if (grepl("<p ", text, fixed = TRUE) && grepl("poison", text, fixed = TRUE)) {
        text <- sub('<p id="1">[^<]*</p>', "", text)
      }
      list(text = text, billed_characters = nchar(text), detected_source_language = "FR")
    })))
  })
  paragraphs <- sprintf("Paragraphe %d.", 1:20)
  paragraphs[7] <- "poison"
  doc <- paste(paragraphs, collapse = "\n\n")
  out <- qlm_translate(c(a = doc, b = "Bonjour\n\nencore"), "deepl/quality_optimized", api_key = "k")
  expect_identical(as.character(out), c(a = doc, b = "Bonjour\n\nencore"))
  expect_equal(requests, 5)
  # Each paragraph records every failed part that contained it: paragraph 1
  # the whole document and its first half, paragraph 7 each part down to
  # the pair it shared with paragraph 6.
  attempts <- attr(out, "provenance")$attempts[[1]]
  failures <- vapply(attempts, function(a) !is.na(a$error), logical(1))
  paragraph <- vapply(attempts, `[[`, integer(1), "paragraph")
  expect_equal(sum(failures & paragraph == 1L), 2)
  expect_equal(sum(failures & paragraph == 11L), 1)
  expect_equal(sum(failures & paragraph == 7L), 4)
  expect_equal(sum(!failures), 20)
  expect_equal(max(vapply(attempts, function(a) a$group_reduction %||% 0L, integer(1))), 4)
})

test_that("a DeepL structure failure in both halves is not split further or retried", {
  requests <- 0L
  httr2::local_mocked_responses(function(req) {
    requests <<- requests + 1L
    httr2::response_json(body = list(translations = lapply(req$body$data$text, function(text) {
      list(text = sub('<p id="1">[^<]*</p>', "", text), billed_characters = 1)
    })))
  })
  doc <- paste(sprintf("Paragraphe %d.", 1:8), collapse = "\n\n")
  expect_warning(out <- qlm_translate(c(a = doc), "deepl/quality_optimized", api_key = "k"), "1 of 1")
  expect_true(is.na(out))
  expect_equal(requests, 2)
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
  attempts <- translation_provenance(out)$attempts[[1]]
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
  prov <- translation_provenance(out)
  expect_equal(prov$settings[[1]]$params$reasoning_tokens, 10)
  expect_equal(prov$attempts[[1]][[1]]$warnings, "Ignoring unsupported parameters: reasoning_tokens")
})

test_that("transport failures remain aligned with their documents", {
  mock_translation_chat(function(text) {
    if (text == "fail") simpleError("endpoint refused") else if (text == "unsent") NULL else text
  })
  expect_warning(out <- qlm_translate(c(a = "ok", b = "fail", c = "unsent"), "openai/test"), "2 of 3")
  expect_equal(translation_provenance(out)$status, c("ok", "failed", "failed"))
  expect_match(translation_provenance(out)$.error[2], "endpoint refused")
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
  expect_match(conditionMessage(coded$.error[[2]]), "no translation: .*translation refused")
  expect_true(is_terminal_failure(list(coded$.error[[2]])))
})

test_that("missing input stops new submissions under return and stop", {
  seen <- mock_translation_chat()
  expect_warning(out <- qlm_translate(c(a = "good", b = NA_character_, c = "later"),
    "openai/test", on_error = "return"), "1 of 3")
  expect_length(seen$prompts, 1)
  expect_equal(translation_provenance(out)$status, c("ok", "failed", "unsubmitted"))
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
  expect_length(translation_provenance(out)$attempts[[1]], 2)
  expect_equal(calls, 2)
})

test_that("automatic keyring authentication leaves no key in translation metadata", {
  withr::local_envvar(c(DEEPL_API_KEY = NA_character_))
  testthat::local_mocked_bindings(deepl_keyring_key = function() "keyring-secret:fx")
  seen <- mock_translation_deepl()
  out <- qlm_translate("Bonjour", "deepl/quality_optimized")
  expect_equal(unname(as.character(out)), "Bonjour")
  expect_identical(bearer_of(seen$requests[[1]]), "DeepL-Auth-Key keyring-secret:fx")
  expect_false(grepl("keyring-secret", paste(capture.output(dput(attributes(out))), collapse = ""), fixed = TRUE))
  expect_identical(Sys.getenv("DEEPL_API_KEY", unset = NA_character_), NA_character_)
})
