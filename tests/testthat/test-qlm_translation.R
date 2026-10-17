test_that("translations are named character vectors with provenance", {
  mock_translation_chat(function(text) paste("translated", text))
  input <- c(a = "one", b = "two")
  out <- qlm_translate(input, "openai/test", instructions = "Keep the register.")
  expect_s3_class(out, "qlm_translation")
  expect_s3_class(out, "qlm_preprocessed")
  expect_false(inherits(out, "qlm_coded"))
  expect_type(out, "character")
  expect_named(out, c("a", "b"))
  expect_identical(as.character(out), c(a = "translated one", b = "translated two"))
  expect_named(attributes(as.character(out)), "names")
  prov <- attr(out, "provenance")
  expect_identical(prov$.id, c("a", "b"))
  expect_identical(prov$source_text, c("one", "two"))
  expect_null(attr(out, "corpus"))
  expect_identical(inputs(out), input)
  path <- tempfile(fileext = ".rds")
  saveRDS(out, path)
  expect_identical(readRDS(path), out)
})

test_that("coding verbs refuse translations", {
  mock_translation_chat()
  out <- qlm_translate(c(a = "one", b = "two"), "openai/test")
  expect_error(qlm_replicate(out), "qlm_coded")
  expect_error(qlm_compare(out, out, by = "translation", level = "nominal"))
})

test_that("subsetting keeps provenance aligned", {
  mock_translation_chat()
  out <- qlm_translate(c(a = "one", b = "two", c = "three"), "openai/test")
  subset <- out[c(3, 1)]
  expect_s3_class(subset, "qlm_translation")
  expect_identical(as.character(subset), c(c = "three", a = "one"))
  expect_identical(attr(subset, "provenance")$.id, c("c", "a"))
  expect_identical(attr(subset, "provenance")$source_text, c("three", "one"))
  expect_identical(out["b"], out[2])
  expect_identical(out[], out)
  expect_error(out[c(1, 1)], "unique")
})

test_that("assignment records edits and carries retried translations", {
  mock_translation_chat()
  out <- qlm_translate(c(a = "one", b = "two"), "openai/test")
  edited <- out
  edited["a"] <- "edited"
  prov <- attr(edited, "provenance")
  expect_identical(prov$status, c("edited", "ok"))
  expect_identical(prov$output_hash[1], translation_hash("edited"))
  expect_identical(prov$source_text, c("one", "two"))
  edited[[2]] <- NA_character_
  prov <- attr(edited, "provenance")
  expect_identical(prov$status, c("edited", "failed"))
  expect_identical(prov$.error[2], "set to NA by assignment")
  expect_true(is.na(prov$output_hash[2]))

  retry <- qlm_translate(c(z = "different source"), "openai/test", to = "fr")
  edited["b"] <- retry
  prov <- attr(edited, "provenance")
  expect_identical(as.character(edited), c(a = "edited", b = "different source"))
  expect_identical(prov$.id, c("a", "b"))
  expect_identical(prov$status, c("edited", "ok"))
  expect_identical(prov$target_lang, c("en", "fr"))
  expect_identical(inputs(edited), c(a = "one", b = "different source"))

  expect_error(edited[3] <- "new", "cannot be extended")
  expect_error(edited[1:2] <- c("x", "y", "z"), "one per position")
  expect_error(edited[[1:2]] <- "x", "one translation")
})

test_that("renaming keeps provenance in step", {
  mock_translation_chat()
  out <- qlm_translate(c(a = "one", b = "two"), "openai/test")
  names(out) <- c("x", "y")
  expect_identical(attr(out, "provenance")$.id, c("x", "y"))
  expect_identical(names(inputs(out)), c("x", "y"))
  expect_error(names(out) <- c("x", "x"), "unique")
  expect_error(names(out) <- "x", "one name per translation")
})

test_that("combining joins runs and refuses colliding names or plain text", {
  mock_translation_chat()
  a <- qlm_translate(c(a = "one"), "openai/test")
  b <- qlm_translate(c(b = "two"), "openai/test", to = "fr")
  out <- c(a, b)
  expect_s3_class(out, "qlm_translation")
  expect_identical(as.character(out), c(a = "one", b = "two"))
  expect_identical(attr(out, "provenance")$target_lang, c("en", "fr"))
  expect_error(c(a, a), "unique")
  expect_error(c(a, c(c = "three")), "must be a")
})

test_that("printing shows the run, previews and failures", {
  mock_translation_chat(function(text) if (text == "bad") simpleError("refused") else text)
  expect_warning(out <- qlm_translate(c(first = "Hello\nworld", second = "bad"), "openai/test"))
  printed <- capture.output(result <- print(out))
  expect_identical(result, out)
  expect_identical(printed, c(
    "<qlm_translation: 2 translations, 1 failed; model openai/test; target en>",
    "first: Hello world",
    "second: <NA: API request failed: refused>"
  ))
  expect_identical(capture.output(print(out, n = 1))[3], "# ... with 1 more")
})

test_that("translation provenance contains no literal API key", {
  mock_translation_deepl()
  out <- qlm_translate("Bonjour", "deepl/quality_optimized", api_key = "literal-secret")
  expect_false(grepl("literal-secret", paste(capture.output(dput(attributes(out))), collapse = "")))
})

test_that("a translation stays within a few times the size of its source", {
  mock_translation_chat()
  sentence <- paste(rep("Une phrase assez longue pour le test.", 10), collapse = " ")
  source <- vapply(1:20, function(d) {
    paste(paste(d, seq_len(20), sentence), collapse = "\n\n")
  }, "")
  names(source) <- paste0("d", 1:20)
  out <- qlm_translate(source, "openai/test", protect = "test")
  attempts <- attr(out, "provenance")$attempts[[1]]
  expect_s3_class(attempts, "data.frame")
  expect_equal(nrow(attempts), 20)
  ratio <- as.numeric(object.size(out)) / sum(nchar(source, "bytes"))
  expect_lt(ratio, 5)
})
