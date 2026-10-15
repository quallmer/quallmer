test_that("adapter selection uses exact model IDs and explicit overrides", {
  expect_equal(translation_adapter("deepl/quality_optimized", NULL, NULL, NULL)$name, "deepl")
  expect_error(translation_adapter("deepl/nope", NULL, NULL, NULL), "Unknown DeepL")
  expect_error(translation_adapter("deepl/quality_optimized", "generic", NULL, NULL), "incompatible")
  expect_error(translation_adapter("ollama/anything", "deepl", NULL, NULL), "incompatible")
  for (id in c("qwen-mt-plus", "qwen-mt-flash", "qwen-mt-lite")) {
    expect_error(translation_adapter(paste0("dashscope/", id), NULL, NULL, NULL), "not implemented")
    expect_equal(translation_adapter(paste0("dashscope/", id), "generic", NULL, NULL)$name, "generic")
  }
  expect_equal(translation_adapter("dashscope/qwen-mt-future", NULL, NULL, NULL)$name, "generic")
  expect_error(translation_adapter("ollama/local-name", "hy-mt2", NULL, NULL), "not implemented")
})

test_that("DeepL XML escapes source markup and protects opaque markers", {
  masked <- mask_translation_terms("A < B & TERM", "TERM")
  xml <- translation_xml(masked$text, masked$prefix)
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
  body <- translation_deepl_body(jobs[1], setup)
  expect_type(body$text, "list")
  expect_equal(body$context, "background")
  expect_equal(body$source_lang, "DE")
  expect_equal(body$target_lang, "EN-GB")
  expect_equal(body$custom_instructions, list("Keep the register."))
  jobs[[2]]$context <- "preceding source"
  expect_equal(lengths(translation_deepl_batches(jobs[1:3], setup)), c(1, 1, 1))
  setup$settings$context <- paste(rep("字", 50000), collapse = "")
  expect_error(translation_deepl_batches(jobs[1], setup), "128 KiB")
})

test_that("DeepL requests authenticate through the header, not the body", {
  adapter <- translation_adapter("deepl/quality_optimized", NULL, NULL, NULL)
  setup <- translation_setup(adapter, list(target_lang = "en"), "test-key", NULL, 60)
  req <- translation_deepl_request(list(list(text = "Hallo", marker_prefix = "QLMKEEP", context = NULL)), setup)
  expect_equal(req$url, "https://api.deepl.com/v2/translate")
  expect_equal(bearer_of(req), "DeepL-Auth-Key test-key")
  expect_false(grepl("test-key", jsonlite::toJSON(req$body$data), fixed = TRUE))
  expect_equal(req$policies$retry_max_tries, 3)
})
