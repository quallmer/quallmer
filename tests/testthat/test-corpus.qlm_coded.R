test_that("coded translations convert with the original corpus variables", {
  skip_if_not_installed("quanteda")
  mock_translation_chat(function(text) paste("translated", text))
  input <- quanteda::corpus(c(a = "one", b = "two"),
    docvars = data.frame(group = c("A", "B")), meta = list(project = "Study"))
  translated <- qlm_translate(input, "openai/test")
  book <- qlm_codebook("Summaries", "Summarise", ellmer::type_object(summary = ellmer::type_string()))
  runner <- text_runner(tibble::tibble(summary = c("first", "second")))
  coded <- runner(translated, book, model = "openai/test")
  corpus <- quanteda::corpus(coded[2:1, ])
  expect_identical(as.character(corpus), c(b = "second", a = "first"))
  expect_equal(quanteda::docvars(corpus)$group, c("B", "A"))
  expect_identical(quanteda::meta(corpus, type = "system"), quanteda::meta(input, type = "system"))
  expect_identical(quanteda::meta(corpus, "project"), "Study")
  expect_null(quanteda::meta(corpus, "quallmer")$translation)
  expect_identical(quanteda::meta(corpus, "quallmer")$coding$meta$user$preprocessing,
                   preprocessing_record(translated))
})

test_that("ordinary coded objects convert a selected text field with original metadata", {
  skip_if_not_installed("quanteda")
  input <- quanteda::corpus(c(a = "one", b = "two"),
    docvars = data.frame(group = c("A", "B")), meta = list(project = "Study"))
  book <- qlm_codebook("Summaries", "Summarise", ellmer::type_object(
    summary = ellmer::type_string(), alternative = ellmer::type_string()))
  runner <- text_runner(tibble::tibble(summary = c("first", "second"), alternative = c("x", "y")))
  out <- runner(input, book, model = "openai/test")
  expect_error(quanteda::corpus(out), "text_field")
  corpus <- quanteda::corpus(out[2:1, ], text_field = "summary")
  expect_identical(as.character(corpus), c(b = "second", a = "first"))
  expect_equal(quanteda::docvars(corpus)$group, c("B", "A"))
  expect_identical(quanteda::meta(corpus, type = "system"), quanteda::meta(input, type = "system"))
  expect_identical(quanteda::meta(corpus, "project"), "Study")
  expect_equal(quanteda::meta(corpus, "quallmer")$coding$text_field, "summary")
  expect_equal(quanteda::meta(corpus, "quallmer")$coding$other_outputs$alternative, c("y", "x"))
  expect_error(quanteda::corpus(out, text_field = ".id"), "character output")
  expect_error(quanteda::corpus(out, text_field = "unknown"), "character output")
  expect_error(quanteda::corpus(out, text_field = "summary", unused = TRUE), "empty")
  only <- out[c(".id", "summary")]
  expect_identical(as.character(quanteda::corpus(only)), c(a = "first", b = "second"))
})
