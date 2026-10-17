# Opt-in paid smoke test. Supply DEEPL_API_KEY in the process environment;
# ordinary unit tests never retrieve credentials from the system keychain.
test_that("DeepL combines custom instructions, context and XML protection", {
  skip_on_cran()
  skip_if(!identical(Sys.getenv("QUALLMER_LIVE_TESTS"), "true"), "live tests not enabled")
  skip_if(!nzchar(Sys.getenv("DEEPL_API_KEY")), "DEEPL_API_KEY is not set")
  skip_if_offline()
  out <- qlm_translate(c(example = "Bonjour de quallmer.\n\nMerci beaucoup."),
    model = "deepl/quality_optimized", source_lang = "fr", target_lang = "en-GB",
    protect = "quallmer", instructions = "Preserve the original register.",
    context = "A short greeting from a research software project.", on_error = "stop")
  expect_match(unname(as.character(out)), "quallmer", fixed = TRUE)
  expect_match(unname(as.character(out)), "\n\n", fixed = TRUE)
  provenance <- translation_provenance(out)
  expect_equal(provenance$status, "ok")
  expect_equal(provenance$detected_language, "FR")
  expect_true(all(provenance$attempts[[1]]$protection_ok))
})
