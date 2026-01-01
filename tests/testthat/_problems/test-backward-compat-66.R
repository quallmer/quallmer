# Extracted from test-backward-compat.R:66

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "quallmer", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
skip_if_not_installed("ellmer")
type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))
withr::local_options(lifecycle_verbosity = "warning")
expect_warning(
    task("Test", "Prompt", type_obj),
    "deprecated.*task.*qlm_codebook"
  )
