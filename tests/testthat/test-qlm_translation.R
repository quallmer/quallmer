test_that("translations print corpus summaries and quoted text previews", {
  skip_if_not_installed("quanteda")
  mock_translation_chat()
  out <- quanteda::corpus(qlm_translate(c(first = "Hello\nworld", second = "Bonjour"), "openai/test"))
  printed <- capture.output(result <- print(out, max_ndoc = 1, max_nchar = 5))
  expect_identical(result, out)
  expect_identical(printed, c(
    "corpus (qlm_translation) of 2 documents (18 characters).",
    "first :", '"Hello..."', "",
    "[ reached max_ndoc ... 1 more document ]"
  ))
  expect_identical(capture.output(print(out, max_ndoc = 0)), printed[1])
  expect_identical(capture.output(print(out, max_ndoc = 0, show_summary = FALSE)), character())
  expect_identical(capture.output(print(out, max_ndoc = -1, max_nchar = -1,
                                        show_summary = FALSE)),
                   c("first :", '"Hello world"', "", "second :", '"Bonjour"', ""))
  expect_error(print(out, max_ndoc = NA), "max_ndoc")
  expect_error(print(out, max_nchar = -2), "max_nchar")
  expect_error(print(out, show_summary = NA), "show_summary")
})

test_that("translation summaries count user docvars and format large counts", {
  skip_if_not_installed("quanteda")
  skip_if_not_installed("quanteda")
  mock_translation_chat()
  input <- quanteda::corpus(c(example = strrep("é", 1234)),
                            docvars = data.frame(language = "French"))
  out <- quanteda::corpus(qlm_translate(input, "openai/test"))
  expect_output(print(out, max_ndoc = 0),
                "corpus (qlm_translation) of 1 document (1,234 characters) and 1 docvar.",
                fixed = TRUE)
  out[[1]] <- NA_character_
  expect_output(print(out), "<NA: set to NA by assignment>", fixed = TRUE)
  expect_output(print(out, max_ndoc = 0), "(0 characters)", fixed = TRUE)
  expect_output(print(out[integer()], max_ndoc = 0),
                "corpus (qlm_translation) of 0 documents (0 characters) and 1 docvar.",
                fixed = TRUE)
})
