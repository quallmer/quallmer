# Extracted from test-annotate.R:82

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "quallmer", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
skip_if_not_installed("ellmer")
type_obj <- ellmer::type_object(
    score = ellmer::type_number("A score")
  )
tsk <- task(
    name = "Test",
    system_prompt = "Test prompt",
    type_def = type_obj
  )
texts <- c("Hello", "World")
expect_warning(
    suppressMessages(
      tryCatch(
        annotate(texts, tsk, model_name = "openai", fake_arg = 123),
        error = function(e) NULL
      )
    ),
    "not recognized"
  )
