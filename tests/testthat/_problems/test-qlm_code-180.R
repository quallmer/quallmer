# Extracted from test-qlm_code.R:180

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "quallmer", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
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
output <- capture.output(print(mock_coded))
expect_true(any(grepl("quallmer coded object", output)))
expect_true(any(grepl("Codebook", output)))
expect_true(any(grepl("Model", output)))
expect_true(any(grepl("Units.*3", output)))
