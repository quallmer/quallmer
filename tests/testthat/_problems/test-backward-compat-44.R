# Extracted from test-backward-compat.R:44

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "quallmer", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
skip_if_not_installed("ellmer")
withr::local_options(lifecycle_verbosity = "quiet")
type_obj <- ellmer::type_object(
    score = ellmer::type_number("Score")
  )
codebook <- qlm_codebook(
    name = "New Codebook",
    system_prompt = "Test prompt",
    type_def = type_obj
  )
