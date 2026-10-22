test_that("language tags are normalised and anything else is refused", {
  expect_identical(normalise_language_tag("EN", "x"), "en")
  expect_identical(normalise_language_tag("en-gb", "x"), "en-GB")
  expect_identical(normalise_language_tag("zh_hant_tw", "x"), "zh-Hant-TW")
  expect_identical(normalise_language_tag("es-419", "x"), "es-419")
  expect_identical(normalise_language_tag("yue", "x"), "yue")
  expect_null(normalise_language_tag(NULL, "x"))
  for (bad in c("English", "e", "en-GB-x-private", "en-", "en GB", "zh-Hant-TW-extra")) {
    expect_error(normalise_language_tag(bad, "to"), "language tag")
  }
  expect_error(normalise_language_tag("English", "to"), "app-subtags")
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
                       to = "en_gb", from = "FR")
  settings <- attr(out, "provenance")$settings[[1]]
  expect_identical(settings$target_lang, "en-GB")
  expect_identical(settings$provider_languages$target, "EN-GB")
  expect_identical(attr(out, "provenance")$target_lang, "en-GB")
  expect_equal(seen$requests[[1]]$body$data$target_lang, "EN-GB")
  expect_equal(seen$requests[[1]]$body$data$source_lang, "FR")
  expect_error(qlm_translate("Bonjour", "deepl/quality_optimized", api_key = "k",
                             to = "en-AU"), "no target variant")
  expect_error(qlm_translate("Bonjour", "openai/test", to = "English"), "language tag")
  expect_length(seen$requests, 1)
})

test_that("an explicit Chinese script wins over the region", {
  deepl <- function(tag) translation_provider_languages("deepl", tag, NULL)$target
  google <- function(tag) translation_provider_languages("google-translate", tag, NULL)$target
  qwen <- function(tag) translation_provider_languages("qwen-mt", tag, NULL)$target
  for (tag in c("zh-Hans-HK", "zh-Hans-TW", "zh-Hans-MO")) {
    expect_identical(deepl(tag), "ZH-HANS")
    expect_identical(google(tag), "zh-Hans")
    expect_identical(qwen(tag), "zh")
  }
  for (tag in c("zh-Hant-CN", "zh-Hant-SG")) {
    expect_identical(deepl(tag), "ZH-HANT")
    expect_identical(google(tag), "zh-Hant")
    expect_identical(qwen(tag), "zh_tw")
  }
  # The region supplies the script only when none is given
  expect_identical(deepl("zh-HK"), "ZH-HANT")
  expect_identical(deepl("zh-SG"), "ZH-HANS")
})

test_that("three-letter ISO 639-3 codes become their two-letter codes where one exists", {
  expect_identical(normalise_language_tag("fra", "from"), "fr")
  expect_identical(normalise_language_tag("DEU", "from"), "de")
  # 639-2/B spellings, and macrolanguage members
  expect_identical(normalise_language_tag("ger", "from"), "de")
  expect_identical(normalise_language_tag("cmn", "from"), "zh")
  expect_identical(normalise_language_tag("cmn-Hant", "to"), "zh-Hant")
  expect_identical(normalise_language_tag("por_br", "to"), "pt-BR")
  # No two-letter code: passed on, so that a provider can refuse it
  expect_identical(normalise_language_tag("kmb", "from"), "kmb")
  expect_identical(normalise_language_tag("yue", "from"), "yue")
})

test_that("language vectors are recycled, normalised and checked once per value", {
  vec <- function(...) translation_language_vector(..., n = 3L)
  expect_identical(vec("EN", "to", allow_missing = FALSE), rep("en", 3))
  expect_identical(vec(c("fra", "deu", "fra"), "from", allow_missing = FALSE),
                   c("fr", "de", "fr"))
  expect_identical(vec(factor(c("fra", "kmb", "fra")), "from", allow_missing = TRUE),
                   c("fr", "kmb", "fr"))
  # NA means detect, and only `from` may be missing
  expect_identical(vec(c("fra", NA, "deu"), "from", allow_missing = TRUE),
                   c("fr", NA, "de"))
  expect_identical(vec(NULL, "from", allow_missing = TRUE), rep(NA_character_, 3))
  expect_identical(vec(NA, "from", allow_missing = TRUE), rep(NA_character_, 3))
  expect_error(vec(c("fr", NA, "de"), "to", allow_missing = FALSE), "missing")
  expect_error(vec(c("fr", "de"), "from", allow_missing = TRUE), "length 1 or one tag")
  expect_error(vec(c("fr", "English", "de"), "from", allow_missing = TRUE), "language tag")
  expect_error(vec(1:3, "to", allow_missing = FALSE), "language tag")
})

test_that("each text has its own recorded and provider languages", {
  languages <- translation_document_languages("deepl", c("en-GB", "en-GB", "fr"),
                                              c("de", NA, "de"))
  expect_length(languages, 3)
  expect_identical(languages[[1]]$provider_languages, list(target = "EN-GB", source = "DE"))
  expect_null(languages[[2]]$source_lang)
  expect_null(languages[[2]]$provider_languages$source)
  expect_identical(languages[[3]]$provider_languages$target, "FR")
  # An unsupported variant fails for the text that asks for it
  expect_error(translation_document_languages("deepl", c("en", "en-AU"), c(NA, NA)),
               "no target variant")
})
