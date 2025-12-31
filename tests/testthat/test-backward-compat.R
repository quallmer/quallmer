test_that("old task() objects work with new qlm_code()", {
  skip_if_not_installed("ellmer")

  # Suppress deprecation warnings for this test
  withr::local_options(lifecycle_verbosity = "quiet")

  type_obj <- ellmer::type_object(
    score = ellmer::type_number("Score")
  )

  # Create old-style task
  old_task <- task(
    name = "Old Task",
    system_prompt = "Test prompt",
    type_def = type_obj
  )

  # qlm_code() should accept old task objects
  # We can't actually run it without API calls, but we can test the conversion logic
  expect_true(inherits(old_task, "task"))

  # When passed to qlm_code, it should be converted via as_qlm_codebook
  converted <- as_qlm_codebook(old_task)
  expect_true(inherits(converted, "qlm_codebook"))
  expect_true(inherits(converted, "task"))
})


test_that("new qlm_codebook objects work with old annotate()", {
  skip_if_not_installed("ellmer")

  # Suppress deprecation warnings
  withr::local_options(lifecycle_verbosity = "quiet")

  type_obj <- ellmer::type_object(
    score = ellmer::type_number("Score")
  )

  # Create new-style codebook
  codebook <- qlm_codebook(
    name = "New Codebook",
    instructions = "Test prompt",
    schema = type_obj
  )

  # annotate() should accept qlm_codebook because it inherits from "task"
  expect_true(inherits(codebook, "task"))
  expect_true(inherits(codebook, "qlm_codebook"))

  # The dual class inheritance allows it to pass the inherits(task, "task") check
  # in the old annotate() function
})


test_that("task() shows deprecation warning", {
  skip_if_not_installed("ellmer")

  type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))

  # Should warn when lifecycle verbosity allows it
  withr::local_options(lifecycle_verbosity = "warning")

  lifecycle::expect_deprecated(
    task("Test", "Prompt", type_obj)
  )
})


test_that("annotate() shows deprecation warning", {
  skip_if_not_installed("ellmer")

  withr::local_options(lifecycle_verbosity = "warning")

  type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))
  codebook <- qlm_codebook("Test", "Prompt", type_obj)

  # annotate() should show deprecation warning
  # We expect it to fail because we can't actually call APIs,
  # but the warning should come first
  lifecycle::expect_deprecated(
    tryCatch(
      annotate(c("test"), codebook, model_name = "test/model"),
      error = function(e) NULL
    )
  )
})


test_that("deprecation warnings can be suppressed", {
  skip_if_not_installed("ellmer")

  # Suppress warnings
  withr::local_options(lifecycle_verbosity = "quiet")

  type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))

  # Should not warn when suppressed
  expect_no_warning(
    task("Test", "Prompt", type_obj)
  )
})


test_that("predefined tasks work with both old and new APIs", {
  skip_if_not_installed("ellmer")

  # Predefined tasks return qlm_codebook objects
  sentiment_cb <- task_sentiment()

  # Should work as both task and qlm_codebook
  expect_true(inherits(sentiment_cb, "task"))
  expect_true(inherits(sentiment_cb, "qlm_codebook"))

  # Both APIs should accept it
  # (We can't test actual execution, but we can verify the types are compatible)
})


test_that("qlm_code validates codebook argument", {
  skip_if_not_installed("ellmer")

  # Should error on non-task/non-codebook objects
  expect_error(
    qlm_code(c("test"), codebook = list(name = "fake"), model = "test"),
    "must be created using.*qlm_codebook"
  )

  expect_error(
    qlm_code(c("test"), codebook = "not a codebook", model = "test"),
    "must be created using.*qlm_codebook"
  )
})


test_that("conversion preserves all task attributes", {
  skip_if_not_installed("ellmer")

  withr::local_options(lifecycle_verbosity = "quiet")

  type_obj <- ellmer::type_object(
    score = ellmer::type_number("Score"),
    explanation = ellmer::type_string("Explanation")
  )

  # Create task with image input type
  old_task <- task(
    name = "Image Task",
    system_prompt = "Analyze this image.",
    type_def = type_obj,
    input_type = "image"
  )

  # Convert to qlm_codebook
  converted <- as_qlm_codebook(old_task)

  # Should preserve all attributes
  expect_equal(converted$name, "Image Task")
  expect_equal(converted$system_prompt, "Analyze this image.")
  expect_equal(converted$type_def, type_obj)
  expect_equal(converted$input_type, "image")
})
