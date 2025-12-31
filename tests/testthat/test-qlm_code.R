test_that("qlm_code validates codebook argument", {
  skip_if_not_installed("ellmer")

  # Should error on invalid codebook objects
  expect_error(
    qlm_code(c("test"), codebook = list(name = "fake"), model = "test"),
    "must be created using.*qlm_codebook"
  )

  expect_error(
    qlm_code(c("test"), codebook = "not valid", model = "test"),
    "must be created using.*qlm_codebook"
  )
})


test_that("qlm_code accepts both task and qlm_codebook objects", {
  skip_if_not_installed("ellmer")

  withr::local_options(lifecycle_verbosity = "quiet")

  type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))

  # Should accept qlm_codebook
  codebook <- qlm_codebook("Test", "Prompt", type_obj)
  expect_true(inherits(codebook, "qlm_codebook"))

  # Should accept old task (will be converted internally)
  old_task <- task("Test", "Prompt", type_obj)
  expect_true(inherits(old_task, "task"))

  # Both should pass validation (we can't test execution without APIs)
  # but we can verify they're accepted as valid input types
})


test_that("qlm_code validates input type matches codebook", {
  skip_if_not_installed("ellmer")

  type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))

  # Text codebook expects character input
  text_codebook <- qlm_codebook("Test", "Prompt", type_obj, input_type = "text")

  # Should error on non-character input
  expect_error(
    qlm_code(x = 123, codebook = text_codebook, model = "test"),
    "expects text input.*character vector"
  )

  expect_error(
    qlm_code(x = list("a", "b"), codebook = text_codebook, model = "test"),
    "expects text input.*character vector"
  )

  # Image codebook also expects character input (file paths)
  image_codebook <- qlm_codebook("Test", "Prompt", type_obj, input_type = "image")

  expect_error(
    qlm_code(x = 123, codebook = image_codebook, model = "test"),
    "expects image file paths.*character vector"
  )
})


test_that("qlm_code returns qlm_coded object structure", {
  skip_if_not_installed("ellmer")

  # We can't test actual execution, but we can verify the structure
  # by examining what new_qlm_coded creates

  type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))
  codebook <- qlm_codebook("Test", "Prompt", type_obj)

  mock_results <- data.frame(id = 1:2, score = c(0.5, 0.8))

  # Add id column to mock_results
  mock_results$id <- 1:2

  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = c("text1", "text2"),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(
      timestamp = Sys.time(),
      n_units = 2,
      ellmer_version = "0.4.0",
      quallmer_version = "0.2.0",
      R_version = "4.3.0"
    )
  )

  # Verify structure - qlm_coded is now a data.frame with attributes
  expect_true(inherits(mock_coded, "qlm_coded"))
  expect_true(inherits(mock_coded, "data.frame"))
  expect_true(is.data.frame(mock_coded))

  # Verify data frame columns (id renamed to .id)
  expect_true(".id" %in% names(mock_coded))
  expect_true("score" %in% names(mock_coded))

  # Verify attributes
  expect_identical(attr(mock_coded, "codebook"), codebook)
  expect_true(is.list(attr(mock_coded, "chat_args")))
  expect_true(is.list(attr(mock_coded, "pcs_args")))
  expect_true(is.list(attr(mock_coded, "metadata")))
})


test_that("qlm_code routes arguments correctly", {
  skip_if_not_installed("ellmer")

  # Test that argument routing logic doesn't crash
  # (Can't test actual routing without API calls)

  type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))
  codebook <- qlm_codebook("Test", "Prompt", type_obj)

  # Get valid argument names
  chat_args <- names(formals(ellmer::chat))
  pcs_args <- names(formals(ellmer::parallel_chat_structured))

  expect_true(length(chat_args) > 0)
  expect_true(length(pcs_args) > 0)

  # Verify some expected arguments exist
  expect_true("name" %in% chat_args)
  expect_true("system_prompt" %in% chat_args)
  expect_true("chat" %in% pcs_args)
  expect_true("prompts" %in% pcs_args)
  expect_true("type" %in% pcs_args)
})


test_that("qlm_code works with predefined tasks", {
  skip_if_not_installed("ellmer")

  # All predefined tasks should be valid codebooks
  tasks <- list(
    task_sentiment(),
    task_stance("climate change"),
    task_ideology("left-right"),
    task_salience(),
    task_fact()
  )

  for (task in tasks) {
    expect_true(inherits(task, "qlm_codebook"))
    expect_true(inherits(task, "task"))
    # All should be accepted by qlm_code (can't test execution)
  }
})


test_that("print.qlm_coded displays correctly", {
  skip_if_not_installed("ellmer")

  type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))
  codebook <- qlm_codebook("Test Codebook", "Test prompt", type_obj)

  mock_results <- data.frame(id = 1:3, score = c(0.5, -0.3, 0.8))

  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = c("text1", "text2", "text3"),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 3)
  )

  # Test that print works without error (delegates to tibble print)
  expect_no_error(print(mock_coded))

  # Verify it's a tibble
  expect_true(tibble::is_tibble(mock_coded))
})
