# Extracted from test-annotate.R:91

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
warned <- FALSE
warn_msg <- NULL
result <- tryCatch(
    withCallingHandlers(
      suppressMessages(
        annotate(texts, tsk, model_name = "openai", fake_arg = 123)
      ),
      warning = function(w) {
        warned <<- TRUE
        warn_msg <<- conditionMessage(w)
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) NULL
  )
expect_true(warned, info = "Expected a warning about unrecognized arguments")
expect_match(warn_msg, "not recognized", info = "Warning message should mention unrecognized arguments")
