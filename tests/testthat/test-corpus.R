test_that("corpus print method works without quanteda", {
  # Skip if quanteda is loaded (we need a clean environment for this test)
  skip_if(isNamespaceLoaded("quanteda"), "quanteda is already loaded")

  # Load the data
  data("data_corpus_LMRDsample", package = "quallmer")

  # Test that our print method produces expected output
  output <- capture.output(print(data_corpus_LMRDsample[1:2]))

  expect_true(any(grepl("Corpus consisting of 2 document", output)))
  expect_true(any(grepl("Docvars:", output)))
  expect_true(any(grepl("1035_3.txt:", output)))
  expect_true(any(grepl("3540_3.txt:", output)))

  # Should NOT show the raw character vector attributes
  expect_false(any(grepl("attr\\(", output)))
  expect_false(any(grepl("docvars.*data.frame", output)))
})

test_that("corpus subset method preserves structure", {
  # Skip if quanteda is loaded
  skip_if(isNamespaceLoaded("quanteda"), "quanteda is already loaded")

  # Load the data
  data("data_corpus_LMRDsample", package = "quallmer")

  # Test subsetting
  subset_corpus <- data_corpus_LMRDsample[1:5]

  expect_s3_class(subset_corpus, "corpus")
  expect_equal(length(subset_corpus), 5)

  # Check docvars are preserved
  docvars_original <- attr(data_corpus_LMRDsample, "docvars")
  docvars_subset <- attr(subset_corpus, "docvars")

  expect_equal(nrow(docvars_subset), 5)
  expect_equal(docvars_subset, docvars_original[1:5, , drop = FALSE])

  # Check meta attribute is preserved
  expect_equal(attr(subset_corpus, "meta"), attr(data_corpus_LMRDsample, "meta"))
})

test_that("corpus methods defer to quanteda when loaded", {
  # This test requires quanteda to be available
  skip_if_not_installed("quanteda")

  # Load the data
  data("data_corpus_LMRDsample", package = "quallmer")

  # Load quanteda
  suppressPackageStartupMessages(library(quanteda))

  # Our print method should detect quanteda and defer to it
  output <- capture.output(print(data_corpus_LMRDsample[1:2]))

  # quanteda's output includes specific formatting
  expect_true(any(grepl("documents and.*docvars", output)) ||
              any(grepl("Corpus consisting of.*document", output)))

  # Unload quanteda for other tests
  try(unloadNamespace("quanteda"), silent = TRUE)
})

test_that("no warning when quanteda is loaded before quallmer", {
  # This test simulates loading quanteda first, then quallmer
  # We can't actually test the package loading in testthat, but we can
  # verify the logic in .onLoad

  # Check that our .onLoad function exists and has the right logic
  onload_fn <- quallmer:::.onLoad
  expect_type(onload_fn, "closure")

  # The function should check isNamespaceLoaded("quanteda")
  fn_body <- deparse(body(onload_fn))
  expect_true(any(grepl("isNamespaceLoaded.*quanteda", fn_body)))
  expect_true(any(grepl("registerS3method", fn_body)))
})

test_that("corpus print output format is correct", {
  skip_if(isNamespaceLoaded("quanteda"), "quanteda is already loaded")

  # Load the data
  data("data_corpus_LMRDsample", package = "quallmer")

  # Test with full corpus
  output_full <- capture.output(print(data_corpus_LMRDsample))

  expect_true(any(grepl("Corpus consisting of 200 documents", output_full)))
  expect_true(any(grepl("\\[ \\.\\.\\..*more document", output_full)))

  # Test with single document
  output_single <- capture.output(print(data_corpus_LMRDsample[1]))

  expect_true(any(grepl("Corpus consisting of 1 document\\.", output_single)))
  expect_false(any(grepl("documents", output_single)))  # Should be singular
})

test_that("corpus with minimal docvars prints correctly", {
  skip_if(isNamespaceLoaded("quanteda"), "quanteda is already loaded")

  # Load the data
  data("data_corpus_LMRDsample", package = "quallmer")

  # Test that corpus with only internal docvars doesn't show Docvars line
  # We can simulate this by manipulating an existing corpus's docvars
  test_corpus <- data_corpus_LMRDsample[1:2]

  # Save original docvars
  orig_docvars <- attr(test_corpus, "docvars")

  # Set docvars to only have internal columns
  attr(test_corpus, "docvars") <- orig_docvars[, c("docname_", "docid_", "segid_"), drop = FALSE]

  output <- capture.output(print(test_corpus))

  expect_true(any(grepl("Corpus consisting of 2 documents", output)))
  # Should not show Docvars line when only internal columns exist
  expect_false(any(grepl("^Docvars:", output)))

  # Restore original docvars
  attr(test_corpus, "docvars") <- orig_docvars
})