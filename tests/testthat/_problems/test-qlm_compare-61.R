# Extracted from test-qlm_compare.R:61

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "quallmer", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
skip_if_not_installed("ellmer")
type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))
codebook <- qlm_codebook("Test", "Test prompt", type_obj)
mock_results1 <- data.frame(id = 1:3, score = c(1, 2, 3))
mock_coded1 <- new_qlm_coded(
    results = mock_results1,
    codebook = codebook,
    data = c("text1", "text2", "text3"),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 3)
  )
mock_results2 <- data.frame(id = 1:3, score = c(1, 2, 2))
mock_coded2 <- new_qlm_coded(
    results = mock_results2,
    codebook = codebook,
    data = c("text1", "text2", "text3"),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 3)
  )
expect_error(
    qlm_compare(mock_coded1, mock_coded2, by = "nonexistent"),
    "Variable.*nonexistent.*not found"
  )
