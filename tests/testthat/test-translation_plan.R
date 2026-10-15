test_that("paragraph separators and edge whitespace are retained locally", {
  for (separator in c("\n\n", "\r\n\r\n", "\n \t\n", "\r\r")) {
    text <- paste0("  alpha", separator, "beta  ")
    plan <- translation_plan(text, 4000, NULL)
    expect_length(plan, 2)
    expect_identical(plan[[1]]$separator, separator)
    expect_identical(plan[[1]]$pieces[[1]]$before, "  ")
    expect_identical(plan[[2]]$pieces[[1]]$after, "  ")
  }
  expect_length(translation_plan("alpha\r\nbeta", 4000, NULL), 1)
  expect_length(translation_plan("alpha\nbeta", 4000, NULL), 1)
  expect_null(translation_plan(NA_character_, 4000, NULL))
})

test_that("splitting is reversible and handles unbroken Unicode text", {
  texts <- c("One sentence. Another sentence.", "one two three four five",
             paste(rep("文字", 30), collapse = ""), "  \t  ", "", "👩‍🔬👩‍🔬👩‍🔬")
  for (text in texts) {
    parts <- split_translation_segment(text, 10, "QLMKEEP")
    rebuilt <- paste0(vapply(parts, function(p) paste0(p$before, p$text, p$after), ""), collapse = "")
    expect_identical(rebuilt, text)
    expect_true(all(vapply(parts, function(p) nchar(p$text) <= 10, logical(1))))
  }
})

test_that("protection covers every occurrence and restoration is literal", {
  text <- "C:\\data & C:\\data"
  masked <- mask_translation_terms(text, "C:.data")
  expect_length(masked$markers, 2)
  expect_identical(restore_translation_terms(masked$text, masked$markers), text)
  at_end <- mask_translation_terms("hello TERM", "TERM")
  expect_identical(restore_translation_terms(at_end$text, at_end$markers), "hello TERM")
  only <- mask_translation_terms("TERM", "TERM")
  expect_identical(restore_translation_terms(only$text, only$markers), "TERM")
  job <- list(text = masked$text, marker_prefix = masked$prefix)
  expect_null(validate_translation_text(masked$text, job))
  expect_match(validate_translation_text(paste(masked$text, names(masked$markers)[1]), job), "markers")
  expect_match(validate_translation_text("no terms", job), "markers")
  expect_match(validate_translation_text("a\n\nb", job), "paragraph")
  expect_error(mask_translation_terms("word", c("word", "ord")), "overlap")
  expect_error(mask_translation_terms("word", "^"), "empty")
  expect_error(suppressWarnings(mask_translation_terms("word", "[")), "Invalid")
})

test_that("chunking never cuts a protection marker", {
  masked <- mask_translation_terms("prefix TERM suffix", "TERM")
  parts <- split_translation_segment(masked$text, 30, masked$prefix)
  rebuilt <- paste0(vapply(parts, function(p) paste0(p$before, p$text, p$after), ""), collapse = "")
  expect_identical(rebuilt, masked$text)
  expect_equal(sum(vapply(parts, function(p) length(translation_markers(p$text, masked$prefix)), integer(1))), 1)
  expect_error(split_translation_segment(masked$text, 5, masked$prefix), "too small")
})
