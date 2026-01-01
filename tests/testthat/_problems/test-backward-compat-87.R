# Extracted from test-backward-compat.R:87

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "quallmer", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
skip_if_not_installed("ellmer")
withr::local_options(lifecycle_verbosity = "warning")
type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))
codebook <- qlm_codebook("Test", "Prompt", type_obj)
expect_warning(
    tryCatch(
      annotate(c("test"), codebook, model_name = "test/model"),
      error = function(e) NULL
    ),
    "deprecated.*annotate.*qlm_code"
  )
