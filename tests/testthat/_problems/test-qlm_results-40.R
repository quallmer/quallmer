# Extracted from test-qlm_results.R:40

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "quallmer", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
expect_error(
    qlm_results(list(a = 1, b = 2)),
    "must be a `qlm_coded` object"
  )
