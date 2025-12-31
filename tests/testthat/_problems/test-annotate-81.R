# Extracted from test-annotate.R:81

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
    try(
      annotate(texts, tsk, model_name = "openai", fake_arg = 123),
      silent = TRUE
    ),
    "not recognized"
  )
