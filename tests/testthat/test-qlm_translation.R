test_that("translation methods keep provenance aligned and record edits", {
  mock_translation_chat()
  out <- qlm_translate(c(a = "one", b = "two"), "openai/test")
  subset <- out[c("b", "a")]
  expect_equal(translation_provenance(subset)$source_text, c("two", "one"))
  expect_identical(names(as.character(subset)), c("b", "a"))
  names(subset) <- c("x", "y")
  expect_equal(translation_provenance(subset)$.id, c("x", "y"))
  expect_error(out[c(1, 1)], "unique")
  combined <- c(out, subset)
  expect_length(combined, 4)
  expect_equal(translation_provenance(combined)$source_text, c("one", "two", "two", "one"))
  expect_error(c(out, out), "unique")
  expect_error(c(out, "plain"), "Every argument")
  out["a"] <- "edited"
  expect_equal(translation_provenance(out)$status, c("edited", "ok"))
  expect_equal(translation_provenance(out)$output_hash[1], translation_hash("edited"))
  out[["b"]] <- NA_character_
  expect_equal(translation_provenance(out)$status, c("edited", "failed"))
  out["a"] <- subset[1]
  expect_equal(translation_provenance(out)$source_text[1], "two")
  expect_identical(names(out), c("a", "b"))
  expect_error(out["new"] <- "extra", "cannot be extended")
  expect_output(print(out), "qlm_translation")
  expect_null(attr(as.character(out), "provenance"))
  file <- tempfile(fileext = ".rds")
  saveRDS(out, file)
  expect_identical(readRDS(file), out)
})

test_that("translations print corpus summaries and quoted text previews", {
  mock_translation_chat()
  out <- qlm_translate(c(first = "Hello\nworld", second = "Bonjour"), "openai/test")
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
  mock_translation_chat()
  input <- quanteda::corpus(c(example = strrep("é", 1234)),
                            docvars = data.frame(language = "French"))
  out <- qlm_translate(input, "openai/test")
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
