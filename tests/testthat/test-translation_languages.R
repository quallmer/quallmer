test_that("language tags are normalised and anything else is refused", {
  expect_identical(normalise_language_tag("EN", "x"), "en")
  expect_identical(normalise_language_tag("en-gb", "x"), "en-GB")
  expect_identical(normalise_language_tag("zh_hant_tw", "x"), "zh-Hant-TW")
  expect_identical(normalise_language_tag("es-419", "x"), "es-419")
  expect_identical(normalise_language_tag("yue", "x"), "yue")
  expect_null(normalise_language_tag(NULL, "x"))
  for (bad in c("English", "e", "en-GB-x-private", "en-", "en GB", "zh-Hant-TW-extra")) {
    expect_error(normalise_language_tag(bad, "target_lang"), "language tag")
  }
  expect_error(normalise_language_tag("English", "target_lang"), "app-subtags")
})

test_that("DeepL receives its own codes and refuses variants it lacks", {
  codes <- function(target, source = NULL) translation_provider_languages("deepl", target, source)
  expect_identical(codes("en")$target, "EN")
  expect_identical(codes("en-GB", "de")[c("target", "source")], list(target = "EN-GB", source = "DE"))
  expect_identical(codes("es-419")$target, "ES-419")
  expect_identical(codes("zh-TW")$target, "ZH-HANT")
  expect_identical(codes("zh-CN")$target, "ZH-HANS")
  expect_identical(codes("zh-Hant")$target, "ZH-HANT")
  expect_identical(codes("no")$target, "NB")
  expect_identical(codes("fil")$target, "TL")
  # A source is the bare language: DeepL takes variants only as targets
  expect_identical(codes("en", "pt-BR")$source, "PT")
  expect_error(codes("en-AU"), "en-GB")
  expect_error(codes("fr-BE"), "fr-CA")
})

test_that("Google and Qwen-MT receive their own codes", {
  google <- function(tag) translation_provider_languages("google-translate", tag, NULL)$target
  expect_identical(google("zh-CN"), "zh-Hans")
  expect_identical(google("zh-TW"), "zh-Hant")
  expect_identical(google("tl"), "fil")
  expect_identical(google("pt-BR"), "pt-BR")
  qwen <- function(tag, source = NULL) translation_provider_languages("qwen-mt", tag, source)
  expect_identical(qwen("zh-TW")$target, "zh_tw")
  expect_identical(qwen("zh-Hans")$target, "zh")
  expect_null(qwen("zh-Hans")$variant)
  expect_identical(qwen("pt-BR")[c("target", "variant")], list(target = "pt", variant = "pt-BR"))
  expect_null(qwen("pt")$variant)
  expect_identical(qwen("en")$source, "auto")
  expect_identical(qwen("en", "fil")$source, "tl")
  expect_identical(translation_provider_languages("generic", "en-GB", "fr")$target, "en-GB")
})

test_that("qlm_translate() normalises tags, records both codes and checks before requests", {
  seen <- mock_translation_deepl()
  out <- qlm_translate("Bonjour", "deepl/quality_optimized", api_key = "k",
                       target_lang = "en_gb", source_lang = "FR")
  settings <- attr(out, "provenance")$settings[[1]]
  expect_identical(settings$target_lang, "en-GB")
  expect_identical(settings$provider_languages$target, "EN-GB")
  expect_identical(attr(out, "provenance")$target_lang, "en-GB")
  expect_equal(seen$requests[[1]]$body$data$target_lang, "EN-GB")
  expect_equal(seen$requests[[1]]$body$data$source_lang, "FR")
  expect_error(qlm_translate("Bonjour", "deepl/quality_optimized", api_key = "k",
                             target_lang = "en-AU"), "no target variant")
  expect_error(qlm_translate("Bonjour", "openai/test", target_lang = "English"), "language tag")
  expect_length(seen$requests, 1)
})
