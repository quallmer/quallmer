# Extracted from test-qlm_results.R:105

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "quallmer", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
skip_if_not_installed("ellmer")
type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))
codebook <- qlm_codebook("Test", "Test prompt", type_obj)
mock_results <- data.frame(id = 1:2, score = c(0.5, 0.8))
mock_coded <- new_qlm_coded(
    codebook = codebook,
    settings = list(model_name = "test/model"),
    results = mock_results,
    metadata = list(timestamp = Sys.time(), n_units = 2)
  )
with_mocked_bindings(
    requireNamespace = function(package, quietly = TRUE) FALSE,
    {
      expect_error(
        qlm_results(mock_coded, format = "tibble"),
        "Package.*tibble.*is required"
      )
    }
  )
