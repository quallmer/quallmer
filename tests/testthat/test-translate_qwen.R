test_that("Qwen-MT uses native options, groups paragraphs and preserves provenance", {
  seen <- mock_translation_qwen()
  input <- c(a = "  Bonjour TERM\r\n \r\nEncore TERM  ", b = "你好\n\n世界")
  out <- qlm_translate(input, "dashscope/qwen-mt-plus", target_lang = "en-GB",
    context = "Human rights", instructions = "Keep the register.",
    protect = "TERM", glossary = c(droits = "rights"),
    params = ellmer::params(temperature = 0.2, max_tokens = 1000))
  expect_identical(as.character(out), input)
  expect_length(seen$requests, 2)
  body <- seen$requests[[1]]$body$data
  expect_identical(body$model, "qwen-mt-plus")
  expect_false(body$stream)
  expect_length(body$messages, 1)
  expect_identical(body$messages[[1]]$role, "user")
  expect_false(startsWith(body$messages[[1]]$content, "{"))
  expect_equal(body$translation_options$source_lang, "auto")
  expect_equal(body$translation_options$target_lang, "en")
  expect_equal(body$translation_options$terms[[1]], list(source = "droits", target = "rights"))
  expect_true(all(vapply(body$translation_options$terms[-1], function(term) {
    identical(term$source, term$target)
  }, logical(1))))
  expect_match(body$translation_options$domains, "Write in the en-GB regional variant", fixed = TRUE)
  expect_match(body$translation_options$domains, "Human rights", fixed = TRUE)
  expect_equal(body$temperature, 0.2)
  expect_equal(body$max_tokens, 1000)
  expect_equal(bearer_of(seen$requests[[1]]), "Bearer qwen-test-key")
  p <- translation_provenance(out)
  expect_equal(p$adapter, rep("qwen-mt", 2))
  expect_true(all(is.na(p$detected_language)))
  expect_equal(p$reported_model, rep("qwen-mt-plus", 2))
  attempts <- p$attempts[[1]]
  expect_equal(attempts$group_size[1], 2)
  expect_equal(attempts$input_tokens[1] + attempts$output_tokens[1], 10)
  expect_true(is.na(attempts$input_tokens[2]))
  expect_true(is.na(attempts$neighbouring_context[2]))
  expect_false(grepl("qwen-test-key", paste(capture.output(str(p)), collapse = ""), fixed = TRUE))
})

test_that("Qwen-MT reduces rejected paragraph groups and retains rejected attempts", {
  seen <- mock_translation_qwen(function(body) {
    text <- body$messages[[1]]$content
    if (qwen_test_group_size(body) > 2L) {
      return(httr2::response_json(status_code = 400, body = list(error = list(
        message = "InternalError.Algo.InvalidParameter: Range of input length should be [1, 8192]"))))
    }
    httr2::response_json(body = list(model = "qwen-mt-plus", id = "group-request",
      choices = list(list(message = list(content = text), finish_reason = "stop")),
      usage = list(prompt_tokens = 5, completion_tokens = 5, total_tokens = 10)))
  })
  input <- c(a = "one\n\ntwo\n\nthree\n\nfour")
  out <- qlm_translate(input, "dashscope/qwen-mt-plus")
  expect_identical(as.character(out), input)
  expect_length(seen$requests, 3)
  attempts <- translation_provenance(out)$attempts[[1]]
  expect_equal(nrow(attempts), 8)
  expect_equal(sum(attempts$input_tokens + attempts$output_tokens, na.rm = TRUE), 20)
  expect_equal(sum(!is.na(attempts$error)), 4)
  expect_equal(attempts$group_size[1], 4)
})

test_that("Qwen-MT can reduce an oversized individual paragraph more than twice", {
  seen <- mock_translation_qwen(function(body) {
    text <- body$messages[[1]]$content
    if (nchar(text) > 10L) {
      return(httr2::response_json(status_code = 400, body = list(error = list(
        message = "Range of input length should be [1, 8192]"))))
    }
    httr2::response_json(body = list(choices = list(list(
      message = list(content = text), finish_reason = "stop"))))
  })
  input <- c(a = strrep("x", 80))
  out <- qlm_translate(input, "dashscope/qwen-mt-plus", on_error = "stop")
  expect_identical(as.character(out), input)
  expect_length(seen$requests, 15)
  attempts <- translation_provenance(out)$attempts[[1]]
  expect_equal(max(attempts$reduction), 3)
})

test_that("Qwen-MT preserves boundaries when translated whitespace changes", {
  seen <- mock_translation_qwen(function(body) {
    text <- gsub("\n\n", " ", body$messages[[1]]$content, fixed = TRUE)
    httr2::response_json(body = list(choices = list(list(
      message = list(content = text), finish_reason = "stop"))))
  })
  input <- c(a = "one\n \n two")
  out <- qlm_translate(input, "dashscope/qwen-mt-plus")
  expect_identical(as.character(out), input)
  expect_length(seen$requests, 1)
  expect_true(is.na(translation_provenance(out)$attempts[[1]]$error[1]))
})

test_that("Qwen-MT does not reduce unrelated HTTP 400s and redacts keys", {
  seen <- mock_translation_qwen(function(body) httr2::response_json(
    status_code = 400, body = list(error = list(message = "Invalid target qwen-test-key"))))
  expect_error(qlm_translate(c(a = "one\n\ntwo"), "dashscope/qwen-mt-plus", on_error = "stop"),
               "Invalid target \\[REDACTED\\]")
  expect_length(seen$requests, 1)
})

test_that("Qwen-MT validates native settings before making requests", {
  seen <- mock_translation_qwen()
  expect_error(qlm_translate("one", "dashscope/qwen-mt-plus", formality = "more"), "instructions")
  expect_error(qlm_translate("one", "dashscope/qwen-mt-plus",
    params = ellmer::params(reasoning_effort = "low")), "Unsupported Qwen-MT")
  expect_error(qlm_translate("one", "dashscope/qwen-mt-plus", params = list(temperature = 2)), "Invalid")
  expect_error(qlm_translate("one", "dashscope/qwen-plus", adapter = "qwen-mt"), "model identifier")
  withr::local_envvar(c(DASHSCOPE_API_KEY = ""))
  expect_error(qlm_translate("one", "dashscope/qwen-mt-plus"), "No Qwen-MT API key")
  expect_length(seen$requests, 0)
})

test_that("Qwen-MT keeps corpus metadata and groups many paragraphs within documents", {
  skip_if_not_installed("quanteda")
  seen <- mock_translation_qwen()
  text <- paste(sprintf("Paragraph %02d.", 1:82), collapse = "\n\n")
  input <- quanteda::corpus(c(a = text, b = text),
    docvars = data.frame(language = factor(c("French", "German"))),
    meta = list(project = "UDHR test"))
  out <- qlm_translate(input, "dashscope/qwen-mt-plus")
  expect_identical(as.character(out), as.character(input))
  expect_lt(length(seen$requests), 10)
  expect_identical(attr(quanteda::corpus(out), "docvars"), attr(input, "docvars"))
  expect_identical(quanteda::meta(quanteda::corpus(out), "project"), "UDHR test")
  expect_identical(quanteda::meta(quanteda::corpus(out), type = "system"), quanteda::meta(input, type = "system"))
  expect_identical(quanteda::docvars(quanteda::tokens(quanteda::corpus(out))), quanteda::docvars(input))
})

test_that("Qwen-MT accepts new blank lines within one source paragraph", {
  seen <- mock_translation_qwen(function(body) {
    text <- gsub("\n", "\n\n", body$messages[[1]]$content, fixed = TRUE)
    httr2::response_json(body = list(choices = list(list(
      message = list(content = text), finish_reason = "stop"))))
  })
  input <- c(hindi = "First preamble statement.\nSecond preamble statement.")
  out <- qlm_translate(input, "dashscope/qwen-mt-plus", on_error = "stop")
  expect_identical(as.character(out), input)
  expect_length(seen$requests, 1)
  expect_identical(translation_provenance(out)$status, "ok")
})

test_that("Qwen-MT validates boundary identity and order rather than paragraph counts", {
  jobs <- lapply(c("one", "two", "three"), function(text) list(text = text))
  boundaries <- translation_qwen_boundaries(jobs)
  text <- translation_qwen_text(jobs, boundaries)
  expect_identical(translation_qwen_parts(gsub("\n\n", " ", text, fixed = TRUE),
                                          3, boundaries), c("one", "two", "three"))
  first <- boundaries$tokens[1]
  second <- boundaries$tokens[2]
  expect_null(translation_qwen_parts(gsub(first, "", text, fixed = TRUE), 3, boundaries))
  expect_null(translation_qwen_parts(gsub(first, paste0(first, first), text, fixed = TRUE),
                                      3, boundaries))
  reversed <- paste("one", second, "two", first, "three")
  expect_null(translation_qwen_parts(reversed, 3, boundaries))
  empty <- paste("one", first, second, "three")
  expect_null(translation_qwen_parts(empty, 3, boundaries))
})

test_that("Qwen-MT boundaries cannot collide with literal source text", {
  testthat::local_mocked_bindings(translation_hash = function(x) strrep("a", 64))
  mock_translation_qwen()
  input <- c(a = "literal QLMPaaaaaaaaaaaa_1END\n\nanother paragraph")
  out <- qlm_translate(input, "dashscope/qwen-mt-plus")
  expect_identical(as.character(out), input)
})

test_that("Qwen-MT retries lost boundary markers as smaller groups", {
  seen <- mock_translation_qwen(function(body) {
    text <- gsub("QLMP[0-9a-f]+_[0-9]+END", "", body$messages[[1]]$content)
    httr2::response_json(body = list(choices = list(list(
      message = list(content = text), finish_reason = "stop"))))
  })
  input <- c(a = "one\n\ntwo")
  out <- qlm_translate(input, "dashscope/qwen-mt-plus")
  expect_identical(as.character(out), input)
  expect_length(seen$requests, 3)
  expect_match(translation_provenance(out)$attempts[[1]]$error[1], "boundary markers")
})

test_that("terminal translation errors retain the document ID and attempts", {
  mock_translation_qwen(function(body) httr2::response_json(body = list(
    choices = list(list(message = list(content = ""), finish_reason = "stop")))))
  error <- tryCatch(qlm_translate(c(hin = "one"), "dashscope/qwen-mt-plus",
                                  on_error = "stop"), error = identity)
  expect_s3_class(error, "error")
  expect_identical(error$translation_id, "hin")
  expect_length(error$translation_attempts, 2)
})

test_that("Qwen-MT handles malformed responses and unknown finish reasons", {
  for (body in list(list(), list(choices = list()), list(choices = list("bad")))) {
    values <- parse_qwen_translation(httr2::response_json(body = body), 1, "key")
    expect_match(values[[1]]$error, "empty text")
  }
  values <- parse_qwen_translation(httr2::response_json(body = list(choices = list(list(
    message = list(content = "translation"), finish_reason = "content_filter")))), 1, "key")
  expect_identical(values[[1]]$finish, "content_filter")
})

test_that("Qwen-MT repairs protected markers without repeating a successful group", {
  calls <- 0L
  seen <- mock_translation_qwen(function(body) {
    calls <<- calls + 1L
    text <- body$messages[[1]]$content
    if (calls == 1L) text <- gsub("QLMKEEP[a-z0-9]+_[0-9]+END", "lost", text)
    httr2::response_json(body = list(choices = list(list(
      message = list(content = text), finish_reason = "stop"))))
  })
  input <- c(a = "one TERM\n\ntwo")
  out <- qlm_translate(input, "dashscope/qwen-mt-plus", protect = "TERM")
  expect_identical(as.character(out), input)
  expect_length(seen$requests, 2)
  expect_match(translation_provenance(out)$attempts[[1]]$error[1], "markers")
})

test_that("Qwen-MT reduces truncated groups and accounts for every attempt", {
  seen <- mock_translation_qwen(function(body) {
    text <- body$messages[[1]]$content
    finish <- if (grepl("\n\n", text, fixed = TRUE)) "length" else "stop"
    httr2::response_json(body = list(choices = list(list(
      message = list(content = text), finish_reason = finish)),
      usage = list(prompt_tokens = 5, completion_tokens = 5, total_tokens = 10)))
  })
  input <- c(a = "one\n\ntwo")
  out <- qlm_translate(input, "dashscope/qwen-mt-plus")
  expect_identical(as.character(out), input)
  expect_length(seen$requests, 3)
  attempts <- translation_provenance(out)$attempts[[1]]
  expect_match(attempts$error[1], "output token limit")
  expect_equal(sum(attempts$input_tokens + attempts$output_tokens, na.rm = TRUE), 30)
})

test_that("Qwen-MT return policy withholds later group repairs after a failure", {
  seen <- mock_translation_qwen(function(body) {
    text <- body$messages[[1]]$content
    message <- if (text == "first") "Invalid request" else {
      "Range of input length should be [1, 8192]"
    }
    httr2::response_json(status_code = 400, body = list(error = list(message = message)))
  })
  expect_warning(out <- qlm_translate(c(a = "first", b = "one\n\ntwo"),
    "dashscope/qwen-mt-plus", on_error = "return"), "2 of 2")
  expect_length(seen$requests, 2)
  expect_true(all(is.na(out)))
})

test_that("Qwen-MT grouping observes request-byte targets for different scripts", {
  adapter <- translation_adapter("dashscope/qwen-mt-plus", NULL, NULL, "test")
  settings <- list(target_lang = "en", chunk_size = 4000, group_max_bytes = 6000,
                   provider_languages = translation_provider_languages("qwen-mt", "en", NULL))
  setup <- translation_qwen_setup(adapter, settings, 60)
  jobs <- lapply(1:6, function(i) list(text = strrep("字", 700),
                                      document = 1L, marker_prefix = "QLMKEEP"))
  groups <- translation_qwen_groups(jobs, setup)
  expect_equal(lengths(groups), c(2, 2, 2))
  for (idx in groups) expect_lte(translation_body_bytes(translation_qwen_body(jobs[idx], setup)), 6000)
})

test_that("stopping group repair retains the rejected parent for unprocessed paragraphs", {
  seen <- mock_translation_qwen(function(body) {
    text <- body$messages[[1]]$content
    message <- if (qwen_test_group_size(body) > 2L) {
      "Range of input length should be [1, 8192]"
    } else "Invalid request"
    httr2::response_json(status_code = 400, body = list(error = list(message = message)))
  })
  expect_warning(out <- qlm_translate(c(a = "one\n\ntwo\n\nthree\n\nfour"),
    "dashscope/qwen-mt-plus", on_error = "return"), "1 of 1")
  expect_length(seen$requests, 2)
  attempts <- translation_provenance(out)$attempts[[1]]
  expect_equal(sum(attempts$group_size == 4L), 4)
})
