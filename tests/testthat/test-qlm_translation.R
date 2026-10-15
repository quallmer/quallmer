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
