mock_google_translation <- function(responder = NULL, env = parent.frame()) {
  withr::local_envvar(c(GOOGLE_TRANSLATE_API_KEY = "google-test-key",
    GOOGLE_CLOUD_PROJECT = "translation-test"), .local_envir = env)
  testthat::local_mocked_bindings(req_throttle = function(req, ...) req,
                                 .package = "httr2", .env = env)
  seen <- new.env(parent = emptyenv())
  seen$requests <- list()
  httr2::local_mocked_responses(function(req) {
    seen$requests[[length(seen$requests) + 1L]] <- req
    if (!is.null(responder)) return(responder(req$body$data))
    httr2::response_json(body = list(data = list(translations = list(list(
      translatedText = req$body$data$q[[1]], model = "translation-llm",
      detectedSourceLanguage = "fr")))))
  }, env = env)
  seen
}

test_that("Google selects the native transport without affecting Gemini", {
  expect_equal(translation_adapter("google-translate/translation-llm", NULL, NULL, NULL)$name,
               "google-translate")
  expect_error(translation_adapter("google-translate/unknown", NULL, NULL, NULL), "requires")
  expect_error(translation_adapter("google-translate/translation-llm", "generic", NULL, NULL), "requires")
  expect_error(translation_adapter("google/gemini-test", "google-translate", NULL, NULL), "requires")
})

test_that("Google credentials prefer explicit keys then the environment then keyring", {
  withr::local_envvar(c(GOOGLE_TRANSLATE_API_KEY = "environment-key"))
  local_mocked_bindings(google_translation_keyring_key = function() stop("unexpected keyring lookup"))
  expect_identical(google_translation_api_key("explicit-key"), "explicit-key")
  expect_identical(google_translation_api_key(), "environment-key")
  withr::local_envvar(c(GOOGLE_TRANSLATE_API_KEY = ""))
  local_mocked_bindings(google_translation_keyring_key = function() "saved-key")
  expect_identical(google_translation_api_key(), "saved-key")
  expect_identical(Sys.getenv("GOOGLE_TRANSLATE_API_KEY"), "")
  local_mocked_bindings(google_translation_keyring_key = function() NULL)
  expect_error(google_translation_api_key(), "No Google Translation API key")
  expect_error(google_translation_api_key(" "), "No Google Translation API key")
})

test_that("Google keyring support is optional and contains backend failures", {
  lookup <- google_translation_keyring_key
  mockery::stub(lookup, "requireNamespace", function(...) FALSE)
  expect_null(lookup())
  mockery::stub(lookup, "requireNamespace", function(...) TRUE)
  mockery::stub(lookup, "keyring::key_get", function(service) {
    expect_identical(service, "google-translate")
    "saved-key"
  })
  expect_identical(lookup(), "saved-key")
  mockery::stub(lookup, "keyring::key_get", function(...) stop("private backend details"))
  expect_null(lookup())
})

test_that("Google sends complete documents and records detection without credentials", {
  seen <- mock_google_translation()
  input <- c(first = "Premiere partie.\n\nDeuxieme partie.", second = "Bonjour.")
  result <- qlm_translate(input, "google-translate/translation-llm", to = "en-GB")
  expect_identical(unname(as.character(result)), unname(input))
  expect_length(seen$requests, 2)
  body <- seen$requests[[1]]$body$data
  expect_identical(body$q, unname(as.list(input[1])))
  expect_equal(body$target, "en-GB")
  expect_equal(body$format, "text")
  expect_null(body$source)
  expect_equal(body$model,
    "projects/translation-test/locations/us-central1/models/general/translation-llm")
  expect_equal(seen$requests[[1]]$headers[["x-goog-api-key"]], "google-test-key")
  provenance <- translation_provenance(result)
  expect_equal(provenance$status, rep("ok", 2))
  expect_equal(provenance$detected_language, rep("fr", 2))
  expect_equal(provenance$reported_model, rep("translation-llm", 2))
  expect_equal(provenance$settings[[1]]$text_unit, "document")
  expect_false(grepl("google-test-key", paste(capture.output(str(provenance)), collapse = "")))
  expect_equal(nrow(provenance$attempts[[1]]), 1)
})

test_that("Google keeps protection markers, explicit languages and corpus metadata", {
  seen <- mock_google_translation()
  skip_if_not_installed("quanteda")
  input <- quanteda::corpus(c(a = "Bonjour TERM.\n\nSuite.", b = "Autre."),
                            docvars = data.frame(group = c(1, 2)))
  quanteda::meta(input, field = "note") <- "original"
  result <- qlm_translate(input, "google-translate/translation-llm", from = "fr",
    protect = "TERM", project_id = "explicit-project", region = "global")
  expect_identical(as.character(result), as.character(input))
  expect_identical(attr(quanteda::corpus(result), "docvars"), attr(input, "docvars"))
  expect_identical(quanteda::meta(quanteda::corpus(result), type = "system"), quanteda::meta(input, type = "system"))
  expect_identical(quanteda::meta(quanteda::corpus(result), type = "user", field = "note"), "original")
  expect_equal(seen$requests[[1]]$body$data$source, "fr")
  expect_match(seen$requests[[1]]$body$data$model, "projects/explicit-project/locations/global/")
  expect_match(seen$requests[[1]]$body$data$q[[1]], "QLMKEEP")
})

test_that("Google checks options before requests and requires a project", {
  seen <- mock_google_translation()
  for (arg in c("context", "instructions", "glossary", "params")) {
    value <- switch(arg, params = ellmer::params(temperature = 0.1),
                    glossary = c(a = "b"), "unsupported")
    expect_error(do.call(qlm_translate, c(list(x = "Bonjour",
      model = "google-translate/translation-llm"), setNames(list(value), arg))), "does not support")
  }
  expect_error(qlm_translate("Bonjour", "google-translate/translation-llm", formality = "more"),
               "not an argument for Google Translation")
  withr::local_envvar(c(GOOGLE_CLOUD_PROJECT = ""))
  expect_error(qlm_translate("Bonjour", "google-translate/translation-llm"), "project_id")
  expect_length(seen$requests, 0)
  expect_error(qlm_translate("Bonjour", "google-translate/translation-llm",
    project_id = "translation-test", base_url = "https://example.org"), "explicit")
})

test_that("six multi-paragraph documents require six Google requests", {
  seen <- mock_google_translation()
  input <- setNames(rep(paste(rep(strrep("a", 140), 82), collapse = "\n\n"), 6),
                    c("deu_1996", "fra", "spa", "cmn_hans", "hin", "rus"))
  result <- qlm_translate(input, "google-translate/translation-llm")
  expect_length(seen$requests, 6)
  expect_identical(unname(as.character(result)), unname(input))
  expect_equal(vapply(translation_provenance(result)$attempts, nrow, 1L), rep(1L, 6))
})

test_that("Google splits only oversized documents within character and byte limits", {
  seen <- mock_google_translation()
  input <- c(large = strrep("a", 60001), unicode = strrep("\U0001f600", 29000),
             escaped = strrep("\001", 20000))
  result <- qlm_translate(input, "google-translate/translation-llm")
  expect_identical(unname(as.character(result)), unname(input))
  expect_gt(length(seen$requests), length(input))
  for (req in seen$requests) {
    expect_lte(nchar(req$body$data$q[[1]]), 30000)
    expect_lte(translation_body_bytes(req$body$data), 100000)
  }
})

test_that("Google retains successful documents after transport or content failures", {
  seen <- mock_google_translation(function(body) {
    if (body$q[[1]] == "bad") return(httr2::response_json(status_code = 403,
      body = list(error = list(message = "Blocked google-test-key"))))
    httr2::response_json(body = list(data = list(translations = list(list(
      translatedText = body$q[[1]], model = "translation-llm")))))
  })
  expect_warning(result <- qlm_translate(c(a = "good", b = "bad", c = "good"),
    "google-translate/translation-llm"), "1 of 3")
  expect_identical(unname(as.character(result)), c("good", NA_character_, "good"))
  provenance <- translation_provenance(result)
  expect_equal(provenance$status, c("ok", "failed", "ok"))
  expect_match(provenance$.error[2], "REDACTED", fixed = TRUE)
  expect_false(grepl("google-test-key", provenance$.error[2], fixed = TRUE))
  for (body in list(NULL, "invalid", list(data = list(translations = list())),
                   list(data = list(translations = list(list(translatedText = "")))))) {
    expect_match(parse_google_translation(httr2::response_json(body = body), "key")$error, "invalid")
  }
})

test_that("Google sets the languages of each document's request", {
  seen <- mock_google_translation()
  out <- qlm_translate(c(a = "Bonjour", b = "Guten Tag"), "google-translate/translation-llm",
                       from = c("fra", NA), to = c("en", "zh-TW"))
  bodies <- lapply(seen$requests, function(req) req$body$data)
  pairs <- vapply(bodies, function(b) paste(b$source %||% "none", b$target), "")
  expect_setequal(pairs, c("fr en", "none zh-Hant"))
  expect_identical(translation_provenance(out)$target_lang, c("en", "zh-TW"))
})
