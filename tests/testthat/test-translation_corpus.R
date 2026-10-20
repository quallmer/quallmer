test_that("character input converts to a corpus with namespaced provenance", {
  skip_if_not_installed("quanteda")
  mock_translation_chat()
  translated <- qlm_translate(c(a = "one", b = "two"), "openai/test")
  out <- quanteda::corpus(translated)
  expect_s3_class(out, "corpus")
  expect_false(inherits(out, "qlm_translation"))
  expect_null(attr(out, "provenance", exact = TRUE))
  metadata <- attr(out, "meta")
  expect_named(metadata$user, "quallmer")
  expect_identical(metadata$user$quallmer$translation, attr(translated, "provenance"))
  expect_identical(metadata$system$package, "quallmer")
  expect_identical(metadata$system$`package-version`, utils::packageVersion("quallmer"))
  expect_identical(metadata$system$created, Sys.Date())
  expect_named(attr(out, "docvars"), c("docname_", "docid_", "segid_"))
  expect_identical(attr(out, "docvars")$docname_, c("a", "b"))
  expect_identical(quanteda::docnames(out), c("a", "b"))
  expect_error(quanteda::corpus(translated, unused = TRUE), "empty")
})

test_that("corpus input retains docvars and existing metadata exactly", {
  skip_if_not_installed("quanteda")
  mock_translation_chat(function(text) paste("translated", text))
  input <- quanteda::corpus(c(a = "one", b = "two"),
    docvars = data.frame(group = factor(c("A", "B")),
      date = as.Date(c("2020-01-01", "2020-01-02")),
      number = c(1L, 2L)), meta = list(project = "Study"))
  quanteda::meta(input, "quallmer") <- list(custom = "preserve me")
  metadata <- attr(input, "meta")
  metadata$object$summary <- list(hash = "old text", data = data.frame(old = 1))
  attr(input, "meta") <- metadata
  translated <- qlm_translate(input, "openai/test")
  expect_identical(inputs(translated), input)
  out <- quanteda::corpus(translated)
  expect_identical(as.character(out), c(a = "translated one", b = "translated two"))
  expect_identical(attr(out, "docvars"), attr(input, "docvars"))
  expect_identical(quanteda::docvars(out), quanteda::docvars(input))
  expect_identical(quanteda::meta(out, type = "system"), metadata$system)
  expect_identical(translation_user_metadata(attr(out, "meta")), metadata$user)
  expect_identical(quanteda::meta(out, "quallmer")$custom, "preserve me")
  expect_identical(attr(out, "meta")$object$unit, metadata$object$unit)
  expect_identical(attr(out, "meta")$object$summary, list(hash = character(), data = NULL))
})

test_that("subsetting, renaming and combining keep corpus docvars aligned", {
  skip_if_not_installed("quanteda")
  mock_translation_chat()
  input <- quanteda::corpus(c(a = "one", b = "two", c = "three"),
    docvars = data.frame(group = c("A", "B", "C")), meta = list(project = "Study"))
  translated <- qlm_translate(input, "openai/test")
  subset <- translated[c(3, 1)]
  expect_identical(quanteda::docvars(quanteda::corpus(subset))$group, c("C", "A"))
  expect_identical(levels(attr(subset, "corpus")$docvars$docid_), c("a", "c"))
  expect_identical(quanteda::docnames(inputs(subset)), c("c", "a"))
  names(subset) <- c("x", "y")
  expect_identical(quanteda::docnames(quanteda::corpus(subset)), c("x", "y"))
  expect_identical(quanteda::docvars(quanteda::corpus(subset))$group, c("C", "A"))
  combined <- c(translated["b"], subset)
  expect_identical(quanteda::docvars(quanteda::corpus(combined))$group, c("B", "C", "A"))
  plain <- qlm_translate(c(d = "four"), "openai/test")
  expect_error(c(translated["a"], plain), "different user metadata")
  other <- input
  quanteda::meta(other, "project") <- "Other study"
  expect_error(c(translated["a"], qlm_translate(other["b"], "openai/test")),
               "different user metadata")
})

test_that("translated corpora interoperate with quanteda", {
  skip_if_not_installed("quanteda")
  mock_translation_chat()
  input <- quanteda::corpus(c(a = "one text", b = "two texts"),
    docvars = data.frame(group = c("A", "B")), meta = list(project = "Study"))
  out <- quanteda::corpus(qlm_translate(input, "openai/test"))
  subset <- quanteda::corpus_subset(out, group == "B")
  expect_identical(quanteda::docnames(subset), "b")
  expect_equal(quanteda::docvars(subset)$group, "B")
  expect_identical(quanteda::meta(subset, type = "system"), quanteda::meta(out, type = "system"))
  expect_no_warning(tokens <- quanteda::tokens(out))
  expect_identical(quanteda::docvars(tokens), quanteda::docvars(out))
  expect_identical(quanteda::meta(tokens, "project"), "Study")
})

test_that("translations of translations keep the corpus and the full history", {
  skip_if_not_installed("quanteda")
  mock_translation_chat()
  input <- quanteda::corpus(c(a = "one", b = "two"),
    docvars = data.frame(group = c("A", "B")), meta = list(project = "Study"))
  again <- qlm_translate(qlm_translate(input, "openai/test"), "openai/test", to = "fr")
  expect_identical(quanteda::docvars(quanteda::corpus(again)), quanteda::docvars(input))
  expect_length(preprocessing_record(again)$b, 2)
})

test_that("corpus variables survive coding and replication without copying source provenance", {
  skip_if_not_installed("quanteda")
  mock_translation_chat()
  input <- quanteda::corpus(c(a = "one", b = "two"),
    docvars = data.frame(group = c("A", "B")), meta = list(project = "Study"))
  translated <- qlm_translate(input, "openai/test")
  runner <- text_runner(tibble::tibble(score = c(1, 2)))
  coded <- runner(translated, score_codebook(), model = "openai/gpt-4o-mini")
  expect_identical(qlm_meta(coded, "corpus_docvars"), attr(input, "docvars"))
  expect_identical(qlm_meta(coded, "corpus_meta")$user, list(project = "Study"))
  expect_identical(inputs(coded), as.character(translated))
  # A converted corpus is ordinary quanteda input: its covariates are kept,
  # but the translation record in its metadata is not copied into the run.
  converted <- runner(quanteda::corpus(translated), score_codebook(), model = "openai/gpt-4o-mini")
  expect_null(attr(converted, "meta")$user$preprocessing)
  expect_identical(qlm_meta(converted, "corpus_meta")$user, list(project = "Study"))
  replicate <- qlm_replicate
  mockery::stub(replicate, "qlm_code", runner)
  copied <- replicate(coded, model = "openai/gpt-4o-mini")
  expect_identical(qlm_meta(copied, "corpus_docvars"), qlm_meta(coded, "corpus_docvars"))
  expect_identical(qlm_meta(copied, "corpus_meta"), qlm_meta(coded, "corpus_meta"))
})

test_that("a corpus quallmer field that is not a list fails before any requests", {
  skip_if_not_installed("quanteda")
  seen <- mock_translation_chat()
  input <- quanteda::corpus(c(a = "one"))
  quanteda::meta(input, "quallmer") <- "existing field"
  expect_error(qlm_translate(input, "openai/test"), "must be a list")
  expect_length(seen$prompts, 0)
})
