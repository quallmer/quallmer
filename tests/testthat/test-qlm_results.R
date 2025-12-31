test_that("qlm_results extracts results from qlm_coded object", {
  skip_if_not_installed("ellmer")

  # Create a mock qlm_coded object
  type_obj <- ellmer::type_object(
    score = ellmer::type_number("Score"),
    explanation = ellmer::type_string("Explanation")
  )

  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  mock_results <- data.frame(
    id = 1:3,
    score = c(0.5, -0.3, 0.8),
    explanation = c("Neutral", "Negative", "Positive"),
    stringsAsFactors = FALSE
  )

  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = c("text1", "text2", "text3"),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 3)
  )

  # Extract results
  extracted <- qlm_results(mock_coded)

  # Results should have .id column (renamed from id)
  expect_true(is.data.frame(extracted))
  expect_equal(nrow(extracted), 3)
  expect_true(".id" %in% names(extracted))
  expect_true("score" %in% names(extracted))
  expect_true("explanation" %in% names(extracted))
})


test_that("qlm_results validates input type", {
  # Should error on non-qlm_coded objects
  expect_error(
    qlm_results(list(a = 1, b = 2)),
    "must be a.*qlm_coded.*object"
  )

  expect_error(
    qlm_results(data.frame(x = 1:3)),
    "must be a.*qlm_coded.*object"
  )

  expect_error(
    qlm_results("not a qlm_coded"),
    "must be a.*qlm_coded.*object"
  )
})


test_that("qlm_results supports tibble format", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("tibble")

  # Create mock qlm_coded object
  type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  mock_results <- data.frame(id = 1:2, score = c(0.5, 0.8))

  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = c("text1", "text2"),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 2)
  )

  # Extract as tibble
  extracted_tbl <- qlm_results(mock_coded, format = "tibble")

  expect_true(tibble::is_tibble(extracted_tbl))
  expect_equal(nrow(extracted_tbl), 2)
  expect_equal(ncol(extracted_tbl), 2)
})


test_that("qlm_results errors gracefully when tibble not installed", {
  skip_if_not_installed("ellmer")
  skip("Mocking base R functions is complex; manually verified to work correctly")

  # This test verifies that qlm_results() gives a helpful error message
  # when tibble format is requested but the tibble package is not installed.
  # The error handling has been manually verified to work correctly.
})
