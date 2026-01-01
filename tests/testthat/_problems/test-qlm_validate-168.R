# Extracted from test-qlm_validate.R:168

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "quallmer", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
skip_if_not_installed("ellmer")
skip_if_not_installed("yardstick")
type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
codebook <- qlm_codebook("Test", "Test prompt", type_obj)
mock_results <- data.frame(
    id = 1:10,
    category = c(rep("A", 6), rep("B", 4))  # 6A, 4B
  )
mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = paste0("text", 1:10),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10)
  )
gold <- data.frame(.id = 1:10, category = rep(c("A", "B"), 5))
validation <- qlm_validate(mock_coded, gold, by = "category")
expect_true(validation$accuracy < 1.0)
expect_true(validation$accuracy > 0.5)
