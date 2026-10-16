test_that("adapter selection uses exact model IDs and explicit overrides", {
  expect_equal(translation_adapter("deepl/quality_optimized", NULL, NULL, NULL)$name, "deepl")
  expect_error(translation_adapter("deepl/nope", NULL, NULL, NULL), "Unknown DeepL")
  expect_error(translation_adapter("deepl/quality_optimized", "generic", NULL, NULL), "incompatible")
  expect_error(translation_adapter("ollama/anything", "deepl", NULL, NULL), "incompatible")
  for (id in c("qwen-mt-plus", "qwen-mt-flash", "qwen-mt-lite")) {
    expect_equal(translation_adapter(paste0("dashscope/", id), NULL, NULL, NULL)$name, "qwen-mt")
    expect_equal(translation_adapter(paste0("dashscope/", id), "generic", NULL, NULL)$name, "generic")
  }
  expect_equal(translation_adapter("dashscope/qwen-mt-future", NULL, NULL, NULL)$name, "generic")
  expect_error(translation_adapter("ollama/local-name", "hy-mt2", NULL, NULL), "not implemented")
})

test_that("DeepL XML escapes source markup and protects opaque markers", {
  masked <- mask_translation_terms("A < B & TERM", "TERM")
  xml <- translation_deepl_text(list(list(text = masked$text, marker_prefix = masked$prefix)))
  expect_match(xml, "&lt;")
  expect_match(xml, "&amp;")
  expect_match(xml, "<keep>")
  out <- parse_deepl_translation(list(text = xml, detected_source_language = "EN",
    model_type_used = "quality_optimized", billed_characters = 12))
  expect_identical(out$text, masked$text)
  expect_equal(out$usage$billed_characters, 12)
  expect_equal(out$detected_language, "EN")
  expect_match(parse_deepl_translation(list(text = "<broken>"))$error, "XML")
  expect_match(parse_deepl_translation(list(text = "<qlm><p>bad</p></qlm>"))$error, "XML")
})

test_that("DeepL packs at most 50 texts and accounts for JSON bytes", {
  selected <- translation_adapter("deepl/quality_optimized", NULL, NULL, NULL)
  settings <- list(target_lang = "en-GB", source_lang = "de", context = "background",
                   instructions = "Keep the register.")
  setup <- translation_setup(selected, settings, "test:fx", NULL, 60)
  expect_equal(setup$base_url, "https://api-free.deepl.com")
  jobs <- rep(list(list(text = "Hallo", marker_prefix = "QLMKEEP", context = NULL)), 51)
  batches <- translation_deepl_batches(jobs, setup)
  expect_equal(lengths(batches), c(50, 1))
  body <- translation_deepl_body(jobs, list(1L), setup)
  expect_type(body$text, "list")
  expect_equal(body$context, "background")
  expect_equal(body$source_lang, "DE")
  expect_equal(body$target_lang, "EN-GB")
  expect_equal(body$custom_instructions, list("Keep the register."))
  jobs[[2]]$context <- "preceding source"
  expect_equal(lengths(translation_deepl_batches(jobs[1:3], setup)), 3)
  setup$settings$context <- paste(rep("字", 50000), collapse = "")
  expect_error(translation_deepl_batches(jobs[1], setup), "128 KiB")
})

test_that("DeepL divides a document only when its encoded body exceeds the limit", {
  adapter <- translation_adapter("deepl/quality_optimized", NULL, NULL, NULL)
  setup <- translation_setup(adapter, list(target_lang = "en"), "test", NULL, 60)
  jobs <- rep(list(list(text = strrep("字", 16000), marker_prefix = "QLMKEEP",
                       document = 1L, context = NULL)), 4)
  batches <- translation_deepl_batches(jobs, setup)
  expect_identical(batches, list(list(1:2), list(3:4)))
  for (batch in batches) {
    body <- translation_deepl_body(jobs, batch, setup)
    expect_length(body$text, 1)
    expect_lte(translation_body_bytes(body), 131072)
  }
})

test_that("DeepL request sizes are computed exactly without re-encoding", {
  adapter <- translation_adapter("deepl/quality_optimized", NULL, NULL, NULL)
  setup <- translation_setup(adapter, list(target_lang = "en", context = "Ctx \"quoted\""), "test", NULL, 60)
  masked <- mask_translation_terms("Größe & <Maß> TERM \"zitiert\"\r\nnext\ttab\001", "TERM")
  job <- list(text = masked$text, marker_prefix = masked$prefix)
  jobs <- c(rep(list(job), 12), list(list(text = "字", marker_prefix = "QLMKEEP")))
  inner <- vapply(jobs, function(job) translation_json_bytes(translation_deepl_inner(job)), 0)
  base <- translation_body_bytes(translation_deepl_body(jobs, list(), setup))
  for (items in list(list(1L), list(1:2), list(1:12), list(1L, 2:3, 4:13))) {
    expected <- base + sum(vapply(items, function(i) translation_deepl_item_bytes(inner[i]), 0)) +
      length(items) - 1
    expect_equal(translation_body_bytes(translation_deepl_body(jobs, items, setup)), expected)
  }
  xml <- translation_deepl_text(jobs[1:2])
  parsed <- xml2::read_xml(xml)
  expect_identical(xml2::xml_text(xml2::xml_find_all(parsed, "./p"))[1], masked$text |>
    sub(pattern = "\001", replacement = "\uFFFD", fixed = TRUE))
  expect_length(xml2::xml_find_all(parsed, ".//keep"), 2)
})

test_that("DeepL packing of a long document is linear", {
  adapter <- translation_adapter("deepl/quality_optimized", NULL, NULL, NULL)
  setup <- translation_setup(adapter, list(target_lang = "en"), "test", NULL, 60)
  jobs <- lapply(seq_len(3000), function(i) list(text = strrep("Le conseil municipal. ", 4),
    marker_prefix = "QLMKEEP", document = 1L))
  elapsed <- system.time(batches <- translation_deepl_batches(jobs, setup))[["elapsed"]]
  expect_lt(elapsed, 10)
  expect_identical(unlist(batches), seq_len(3000))
  for (batch in batches) {
    expect_length(batch, 1)
    expect_lte(translation_body_bytes(translation_deepl_body(jobs, batch, setup)), 131072)
  }
})

test_that("DeepL document XML validates paragraph identities and accounts for usage once", {
  jobs <- list(list(text = "one", marker_prefix = "QLMKEEP"),
               list(text = "two", marker_prefix = "QLMKEEP"))
  value <- list(text = translation_deepl_text(jobs), billed_characters = 6,
                detected_source_language = "EN")
  result <- parse_deepl_document(value, 2)
  expect_equal(vapply(result, `[[`, "", "text"), c("one", "two"))
  expect_equal(result[[1]]$usage$billed_characters, 6)
  expect_null(result[[2]]$usage$billed_characters)
  for (xml in c('<qlm><p id="2">two</p><p id="1">one</p></qlm>',
                '<qlm><p id="1">one</p></qlm>',
                '<qlm>extra<p id="1">one</p><p id="2">two</p></qlm>',
                '<qlm><p id="1"><other>one</other></p><p id="2">two</p></qlm>')) {
    value$text <- xml
    result <- parse_deepl_document(value, 2)
    expect_true(any(vapply(result, function(x) !is.na(x$error), logical(1))))
  }
})

test_that("DeepL requests authenticate through the header, not the body", {
  adapter <- translation_adapter("deepl/quality_optimized", NULL, NULL, NULL)
  setup <- translation_setup(adapter, list(target_lang = "en"), "test-key", NULL, 60)
  req <- translation_deepl_request(list(list(text = "Hallo", marker_prefix = "QLMKEEP", context = NULL)),
                                   list(1L), setup)
  expect_equal(req$url, "https://api.deepl.com/v2/translate")
  expect_equal(bearer_of(req), "DeepL-Auth-Key test-key")
  expect_false(grepl("test-key", jsonlite::toJSON(req$body$data), fixed = TRUE))
  expect_equal(req$policies$retry_max_tries, 3)
})

test_that("explicit and environment keys take precedence over keyring", {
  withr::local_envvar(c(DEEPL_API_KEY = "environment-key"))
  testthat::local_mocked_bindings(deepl_keyring_key = function() {
    stop("keyring must not be accessed")
  })
  expect_identical(deepl_api_key("explicit-key"), "explicit-key")
  expect_identical(deepl_api_key(), "environment-key")
  expect_error(deepl_api_key(""), "No DeepL API key")
})

test_that("missing or empty environment keys fall back to the saved deepl key", {
  calls <- 0L
  testthat::local_mocked_bindings(deepl_keyring_key = function() {
    calls <<- calls + 1L
    "saved-key:fx"
  })
  withr::local_envvar(c(DEEPL_API_KEY = NA_character_))
  expect_identical(deepl_api_key(), "saved-key:fx")
  Sys.setenv(DEEPL_API_KEY = "")
  adapter <- translation_adapter("deepl/quality_optimized", NULL, NULL, NULL)
  setup <- translation_setup(adapter, list(target_lang = "en"), NULL, NULL, 60)
  expect_equal(setup$base_url, "https://api-free.deepl.com")
  expect_identical(setup$api_key, "saved-key:fx")
  expect_identical(Sys.getenv("DEEPL_API_KEY"), "")
  expect_equal(calls, 2L)
})

test_that("keyring remains optional and unavailable credentials give useful errors", {
  withr::local_envvar(c(DEEPL_API_KEY = NA_character_))
  lookup <- deepl_keyring_key
  mockery::stub(lookup, "requireNamespace", function(...) FALSE)
  expect_null(lookup())
  testthat::local_mocked_bindings(deepl_keyring_key = function() NULL)
  expect_error(deepl_api_key(), "DEEPL_API_KEY")
  expect_error(deepl_api_key(), "keyring::key_set")
})

test_that("keyring lookup uses the deepl service and contains backend failures", {
  # Stubbing both calls prevents loading keyring or touching a real store,
  # including when the suggested package is absent from the test machine.
  lookup <- deepl_keyring_key
  mockery::stub(lookup, "requireNamespace", function(...) TRUE)
  mockery::stub(lookup, "keyring::key_get", function(service) {
    expect_identical(service, "deepl")
    "saved-key"
  })
  expect_identical(lookup(), "saved-key")
  mockery::stub(lookup, "keyring::key_get", function(...) stop("locked store: sensitive details"))
  expect_null(lookup())
})
