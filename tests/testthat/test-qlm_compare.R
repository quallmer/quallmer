test_that("qlm_compare validates inputs correctly", {
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

  # Should error with only one object
  expect_error(
    qlm_compare(mock_coded1, by = "score"),
    "At least two.*qlm_coded.*objects"
  )

  # Should error with non-qlm_coded objects
  expect_error(
    qlm_compare(mock_coded1, list(a = 1), by = "score"),
    "must be.*qlm_coded.*objects"
  )
})


test_that("qlm_compare checks for 'by' variable", {
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

  # Should error if 'by' variable doesn't exist
  expect_error(
    qlm_compare(mock_coded1, mock_coded2, by = "nonexistent"),
    "Variable.*nonexistent.*not found"
  )
})


test_that("qlm_compare works with matching units", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("irr")

  type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  # Create two coded objects with same units
  mock_results1 <- data.frame(id = 1:5, score = c(1, 2, 3, 1, 2))
  mock_coded1 <- new_qlm_coded(
    results = mock_results1,
    codebook = codebook,
    data = paste0("text", 1:5),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 5)
  )

  mock_results2 <- data.frame(id = 1:5, score = c(1, 2, 2, 1, 3))
  mock_coded2 <- new_qlm_coded(
    results = mock_results2,
    codebook = codebook,
    data = paste0("text", 1:5),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 5)
  )

  # Compare using alpha
  comparison <- qlm_compare(mock_coded1, mock_coded2, by = "score", measure = "alpha")

  expect_true(inherits(comparison, "qlm_comparison"))
  expect_equal(comparison$measure, "alpha")
  expect_true(is.numeric(comparison$value))
  expect_equal(comparison$subjects, 5)
  expect_equal(comparison$raters, 2)
  expect_true(!is.null(comparison$detail))
})


test_that("qlm_compare handles Cohen's kappa for 2 raters", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("irr")

  type_obj <- ellmer::type_object(
    category = ellmer::type_string("Category")
  )
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  # Create categorical data
  mock_results1 <- data.frame(id = 1:10, category = rep(c("A", "B"), 5))
  mock_coded1 <- new_qlm_coded(
    results = mock_results1,
    codebook = codebook,
    data = paste0("text", 1:10),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10)
  )

  mock_results2 <- data.frame(id = 1:10, category = c(rep("A", 8), "B", "B"))
  mock_coded2 <- new_qlm_coded(
    results = mock_results2,
    codebook = codebook,
    data = paste0("text", 1:10),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10)
  )

  # Compare using kappa (should use Cohen's for 2 raters)
  comparison <- qlm_compare(mock_coded1, mock_coded2,
                           by = "category",
                           measure = "kappa")

  expect_equal(comparison$measure, "kappa")
  expect_equal(comparison$raters, 2)
  expect_true(is.numeric(comparison$value))
})


test_that("qlm_compare handles Fleiss' kappa for 3+ raters", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("irr")

  type_obj <- ellmer::type_object(
    category = ellmer::type_string("Category")
  )
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  # Create three coded objects
  mock_results1 <- data.frame(id = 1:8, category = rep(c("A", "B"), 4))
  mock_coded1 <- new_qlm_coded(
    results = mock_results1,
    codebook = codebook,
    data = paste0("text", 1:8),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 8)
  )

  mock_results2 <- data.frame(id = 1:8, category = c(rep("A", 6), "B", "B"))
  mock_coded2 <- new_qlm_coded(
    results = mock_results2,
    codebook = codebook,
    data = paste0("text", 1:8),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 8)
  )

  mock_results3 <- data.frame(id = 1:8, category = c(rep("A", 7), "B"))
  mock_coded3 <- new_qlm_coded(
    results = mock_results3,
    codebook = codebook,
    data = paste0("text", 1:8),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 8)
  )

  # Compare using kappa (should use Fleiss' for 3 raters)
  comparison <- qlm_compare(mock_coded1, mock_coded2, mock_coded3,
                           by = "category",
                           measure = "kappa")

  expect_equal(comparison$measure, "kappa")
  expect_equal(comparison$raters, 3)
  expect_true(is.numeric(comparison$value))
})


test_that("qlm_compare computes percent agreement", {
  skip_if_not_installed("ellmer")

  type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  # Create two coded objects with high agreement
  mock_results1 <- data.frame(id = 1:5, score = c(1, 2, 3, 1, 2))
  mock_coded1 <- new_qlm_coded(
    results = mock_results1,
    codebook = codebook,
    data = paste0("text", 1:5),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 5)
  )

  mock_results2 <- data.frame(id = 1:5, score = c(1, 2, 3, 1, 3))  # 4/5 agree
  mock_coded2 <- new_qlm_coded(
    results = mock_results2,
    codebook = codebook,
    data = paste0("text", 1:5),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 5)
  )

  # Compare using agreement
  comparison <- qlm_compare(mock_coded1, mock_coded2,
                           by = "score",
                           measure = "agreement")

  expect_equal(comparison$measure, "agreement")
  expect_equal(comparison$value, 0.8)  # 4 out of 5
})


test_that("qlm_compare handles mismatched units", {
  skip_if_not_installed("ellmer")

  type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  # Create objects with different units
  mock_results1 <- data.frame(id = 1:3, score = c(1, 2, 3))
  mock_coded1 <- new_qlm_coded(
    results = mock_results1,
    codebook = codebook,
    data = c("text1", "text2", "text3"),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 3)
  )

  mock_results2 <- data.frame(id = 4:6, score = c(1, 2, 3))  # Different IDs
  mock_coded2 <- new_qlm_coded(
    results = mock_results2,
    codebook = codebook,
    data = c("text4", "text5", "text6"),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 3)
  )

  # Should error with no common units
  expect_error(
    qlm_compare(mock_coded1, mock_coded2, by = "score"),
    "No common units"
  )
})


test_that("print.qlm_comparison displays correctly", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("irr")

  type_obj <- ellmer::type_object(score = ellmer::type_number("Score"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  mock_results1 <- data.frame(id = 1:5, score = c(1, 2, 3, 1, 2))
  mock_coded1 <- new_qlm_coded(
    results = mock_results1,
    codebook = codebook,
    data = paste0("text", 1:5),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 5)
  )

  mock_results2 <- data.frame(id = 1:5, score = c(1, 2, 2, 1, 3))
  mock_coded2 <- new_qlm_coded(
    results = mock_results2,
    codebook = codebook,
    data = paste0("text", 1:5),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 5)
  )

  comparison <- qlm_compare(mock_coded1, mock_coded2, by = "score", measure = "alpha")

  # Capture print output
  output <- capture.output(print(comparison))

  expect_true(any(grepl("Inter-rater reliability", output)))
  expect_true(any(grepl("Measure.*alpha", output)))
  expect_true(any(grepl("Subjects.*5", output)))
  expect_true(any(grepl("Raters.*2", output)))
})
