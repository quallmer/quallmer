test_that("character input produces a corpus with empty user docvars and namespaced provenance", {
  mock_translation_chat()
  out <- qlm_translate(c(a = "one", b = "two"), "openai/test")
  expect_s3_class(out, "corpus")
  expect_null(attr(out, "provenance", exact = TRUE))
  metadata <- qlm_meta(out, type = "all")
  expect_named(metadata$user, "quallmer")
  expect_named(metadata$user$quallmer, "translation")
  expect_null(metadata$object$translation)
  expect_identical(metadata$user$quallmer$translation, translation_provenance(out))
  expect_identical(metadata$system$package, "quallmer")
  expect_identical(metadata$system$`package-version`, utils::packageVersion("quallmer"))
  expect_identical(metadata$system$created, Sys.Date())
  expect_named(attr(out, "docvars"), c("docname_", "docid_", "segid_"))
  expect_identical(attr(out, "docvars")$docname_, c("a", "b"))
  expect_identical(names(as.character(out)), c("a", "b"))
  expect_named(attributes(as.character(out)), "names")
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
  out <- qlm_translate(input, "openai/test")
  expect_identical(as.character(out), c(a = "translated one", b = "translated two"))
  expect_identical(attr(out, "docvars"), attr(input, "docvars"))
  expect_identical(quanteda::docvars(out), quanteda::docvars(input))
  expect_identical(quanteda::meta(out, type = "system"), metadata$system)
  expect_identical(translation_user_metadata(attr(out, "meta")), metadata$user)
  expect_identical(quanteda::meta(out, "quallmer")$custom, "preserve me")
  expect_identical(attr(out, "meta")$object$unit, metadata$object$unit)
  expect_identical(attr(out, "meta")$object$summary, list(hash = character(), data = NULL))
  expect_identical(as.character(input), c(a = "one", b = "two"))
})

test_that("quanteda subsetting, renaming, corpus construction and tokenization interoperate", {
  skip_if_not_installed("quanteda")
  mock_translation_chat()
  input <- quanteda::corpus(c(a = "one text", b = "two texts"),
    docvars = data.frame(group = c("A", "B")), meta = list(project = "Study"))
  out <- qlm_translate(input, "openai/test")
  subset <- quanteda::corpus_subset(out, group == "B")
  expect_identical(names(subset), "b")
  expect_equal(translation_provenance(subset)$.id, "b")
  expect_equal(quanteda::docvars(subset)$group, "B")
  expect_identical(quanteda::meta(subset, type = "system"), quanteda::meta(out, type = "system"))
  quanteda::docnames(subset) <- "renamed"
  expect_identical(names(subset), "renamed")
  expect_equal(translation_provenance(subset)$.id, "renamed")
  expect_equal(quanteda::docvars(subset)$group, "B")
  expect_no_warning(rebuilt <- quanteda::corpus(out))
  expect_identical(translation_provenance(rebuilt), translation_provenance(out))
  expect_no_warning(tokens <- quanteda::tokens(out))
  expect_identical(quanteda::docvars(tokens), quanteda::docvars(out))
  expect_identical(quanteda::meta(tokens, "quallmer")$translation, translation_provenance(out))
  expect_identical(quanteda::meta(tokens, "project"), "Study")
  # Corpus construction may drop the quallmer subclass; keyed metadata still
  # supplies the history when the result is translated or coded again.
  again <- qlm_translate(rebuilt["b"], "openai/test")
  expect_length(preprocessing_record(again)$b, 2)
  expect_equal(quanteda::docvars(again)$group, "B")
})

test_that("corpus variables survive coding and replication without copying source provenance twice", {
  skip_if_not_installed("quanteda")
  mock_translation_chat()
  input <- quanteda::corpus(c(a = "one", b = "two"),
    docvars = data.frame(group = c("A", "B")), meta = list(project = "Study"))
  translated <- qlm_translate(input, "openai/test")
  runner <- text_runner(tibble::tibble(score = c(1, 2)))
  coded <- runner(translated, score_codebook(), model = "openai/gpt-4o-mini")
  expect_identical(qlm_meta(coded, "corpus_docvars"), attr(input, "docvars"))
  expect_identical(qlm_meta(coded, "corpus_meta")$user, list(project = "Study"))
  expect_null(attr(inputs(coded), "meta", exact = TRUE))
  replicate <- qlm_replicate
  mockery::stub(replicate, "qlm_code", runner)
  copied <- replicate(coded, model = "openai/gpt-4o-mini")
  expect_identical(qlm_meta(copied, "corpus_docvars"), qlm_meta(coded, "corpus_docvars"))
  expect_identical(qlm_meta(copied, "corpus_meta"), qlm_meta(coded, "corpus_meta"))
})

test_that("replacement preserves destination docvars and metadata", {
  skip_if_not_installed("quanteda")
  mock_translation_chat()
  input <- quanteda::corpus(c(a = "one", b = "two"),
    docvars = data.frame(group = c("A", "B")), meta = list(project = "Study"))
  out <- qlm_translate(input, "openai/test")
  replacement <- qlm_translate(c(retry = "retranslated"), "openai/test")
  out["b"] <- replacement
  expect_equal(as.character(out)["b"], c(b = "retranslated"))
  expect_identical(quanteda::docvars(out), quanteda::docvars(input))
  expect_equal(translation_provenance(out)$.id, c("a", "b"))
  expect_identical(translation_user_metadata(attr(out, "meta")), quanteda::meta(input))
  combined <- c(out["a"], out["b"])
  expect_identical(quanteda::docvars(combined), quanteda::docvars(input))
  quanteda::meta(out, "project") <- "Other study"
  expect_error(c(out["a"], combined["b"]), "different corpus user metadata")
})

test_that("metadata namespace collisions fail before any requests", {
  skip_if_not_installed("quanteda")
  seen <- mock_translation_chat()
  input <- quanteda::corpus(c(a = "one"))
  quanteda::meta(input, "quallmer") <- "existing field"
  expect_error(qlm_translate(input, "openai/test"), "must be a list")
  quanteda::meta(input, "quallmer") <- list(translation = "existing field")
  expect_error(qlm_translate(input, "openai/test"), "incompatible")
  expect_length(seen$prompts, 0)
})
