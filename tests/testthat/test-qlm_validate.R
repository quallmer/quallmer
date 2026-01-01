test_that("qlm_validate validates inputs correctly", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  # Create mock qlm_coded object
  type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  mock_results <- data.frame(id = 1:10, category = rep(c("A", "B"), 5))
  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = paste0("text", 1:10),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10)
  )

  # Create gold standard
  gold <- data.frame(.id = 1:10, category = rep(c("A", "B"), 5))

  # Should error with non-qlm_coded object
  expect_error(
    qlm_validate(list(a = 1), gold, by = "category"),
    "must be a.*qlm_coded.*object"
  )

  # Should error with non-data.frame gold
  expect_error(
    qlm_validate(mock_coded, list(a = 1), by = "category"),
    "must be a data frame"
  )

  # Should error if .id missing from gold
  gold_no_id <- data.frame(category = rep(c("A", "B"), 5))
  expect_error(
    qlm_validate(mock_coded, gold_no_id, by = "category"),
    "must contain.*\\.id.*column"
  )

  # Should error if 'by' variable doesn't exist in x
  expect_error(
    qlm_validate(mock_coded, gold, by = "nonexistent"),
    "Variable.*nonexistent.*not found"
  )

  # Should error if 'by' variable doesn't exist in gold
  gold_wrong_var <- data.frame(.id = 1:10, other = rep(c("A", "B"), 5))
  expect_error(
    qlm_validate(mock_coded, gold_wrong_var, by = "category"),
    "Variable.*category.*not found.*gold"
  )
})

test_that("qlm_validate handles mismatched IDs", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  mock_results <- data.frame(id = 1:5, category = rep(c("A", "B"), length.out = 5))
  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = paste0("text", 1:5),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 5)
  )

  # Gold with different IDs
  gold <- data.frame(.id = 6:10, category = rep(c("A", "B"), length.out = 5))

  # Should error with no matching IDs
  expect_error(
    qlm_validate(mock_coded, gold, by = "category"),
    "No matching units found"
  )
})

test_that("qlm_validate warns about NA values", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  mock_results <- data.frame(id = 1:10, category = c(rep(c("A", "B"), 4), NA, NA))
  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = paste0("text", 1:10),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10)
  )

  gold <- data.frame(.id = 1:10, category = rep(c("A", "B"), 5))

  # Should warn about NA values
  expect_warning(
    qlm_validate(mock_coded, gold, by = "category"),
    "Missing values detected"
  )
})

test_that("qlm_validate computes metrics correctly - perfect predictions", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  # Perfect predictions
  mock_results <- data.frame(id = 1:10, category = rep(c("A", "B"), 5))
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

  # Check structure
  expect_true(inherits(validation, "qlm_validation"))
  expect_equal(validation$accuracy, 1.0)
  expect_equal(validation$precision, 1.0)
  expect_equal(validation$recall, 1.0)
  expect_equal(validation$f1, 1.0)
  expect_equal(validation$n, 10)
  expect_equal(length(validation$classes), 2)
  expect_true(all(c("A", "B") %in% validation$classes))
})

test_that("qlm_validate computes metrics correctly - imperfect predictions", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  # Imperfect predictions
  mock_results <- data.frame(
    id = 1:10,
    category = c(rep("A", 7), rep("B", 3))  # 7A, 3B
  )
  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = paste0("text", 1:10),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10)
  )

  gold <- data.frame(.id = 1:10, category = rep(c("A", "B"), 5))  # 5A, 5B

  validation <- qlm_validate(mock_coded, gold, by = "category")

  # Should have lower metrics than perfect
  expect_true(validation$accuracy < 1.0)
  expect_true(validation$accuracy >= 0.5)  # Should be at least as good as random
  expect_true(is.numeric(validation$precision))
  expect_true(is.numeric(validation$recall))
  expect_true(is.numeric(validation$f1))
  expect_true(is.numeric(validation$kappa))
})

test_that("qlm_validate handles average parameter correctly", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  mock_results <- data.frame(id = 1:12, category = rep(c("A", "B", "C"), 4))
  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = paste0("text", 1:12),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 12)
  )

  gold <- data.frame(.id = 1:12, category = rep(c("A", "B", "C"), 4))

  # Test different averaging methods
  val_macro <- qlm_validate(mock_coded, gold, by = "category", average = "macro")
  expect_equal(val_macro$average, "macro")
  expect_null(val_macro$by_class)

  val_micro <- qlm_validate(mock_coded, gold, by = "category", average = "micro")
  expect_equal(val_micro$average, "micro")
  expect_null(val_micro$by_class)

  val_weighted <- qlm_validate(mock_coded, gold, by = "category", average = "weighted")
  expect_equal(val_weighted$average, "weighted")
  expect_null(val_weighted$by_class)

  val_none <- qlm_validate(mock_coded, gold, by = "category", average = "none")
  expect_equal(val_none$average, "none")
  expect_false(is.null(val_none$by_class))
  expect_true(inherits(val_none$by_class, "tbl_df"))
  expect_true("class" %in% names(val_none$by_class))
  expect_true("precision" %in% names(val_none$by_class))
  expect_true("recall" %in% names(val_none$by_class))
  expect_true("f1" %in% names(val_none$by_class))
})

test_that("qlm_validate handles single measure correctly", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  mock_results <- data.frame(id = 1:10, category = rep(c("A", "B"), 5))
  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = paste0("text", 1:10),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10)
  )

  gold <- data.frame(.id = 1:10, category = rep(c("A", "B"), 5))

  # Test individual measures
  val_acc <- qlm_validate(mock_coded, gold, by = "category", measure = "accuracy")
  expect_false(is.null(val_acc$accuracy))
  expect_true(is.null(val_acc$precision))
  expect_true(is.null(val_acc$recall))
  expect_true(is.null(val_acc$f1))
  expect_true(is.null(val_acc$kappa))

  val_prec <- qlm_validate(mock_coded, gold, by = "category", measure = "precision")
  expect_true(is.null(val_prec$accuracy))
  expect_false(is.null(val_prec$precision))
  expect_true(is.null(val_prec$recall))
  expect_true(is.null(val_prec$f1))
  expect_true(is.null(val_prec$kappa))

  val_rec <- qlm_validate(mock_coded, gold, by = "category", measure = "recall")
  expect_true(is.null(val_rec$accuracy))
  expect_true(is.null(val_rec$precision))
  expect_false(is.null(val_rec$recall))
  expect_true(is.null(val_rec$f1))
  expect_true(is.null(val_rec$kappa))

  val_f1 <- qlm_validate(mock_coded, gold, by = "category", measure = "f1")
  expect_true(is.null(val_f1$accuracy))
  expect_true(is.null(val_f1$precision))
  expect_true(is.null(val_f1$recall))
  expect_false(is.null(val_f1$f1))
  expect_true(is.null(val_f1$kappa))

  val_kappa <- qlm_validate(mock_coded, gold, by = "category", measure = "kappa")
  expect_true(is.null(val_kappa$accuracy))
  expect_true(is.null(val_kappa$precision))
  expect_true(is.null(val_kappa$recall))
  expect_true(is.null(val_kappa$f1))
  expect_false(is.null(val_kappa$kappa))
})

test_that("qlm_validate handles multiclass correctly", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  # 4-class problem
  mock_results <- data.frame(
    id = 1:20,
    category = rep(c("A", "B", "C", "D"), 5)
  )
  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = paste0("text", 1:20),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 20)
  )

  gold <- data.frame(.id = 1:20, category = rep(c("A", "B", "C", "D"), 5))

  validation <- qlm_validate(mock_coded, gold, by = "category")

  expect_equal(length(validation$classes), 4)
  expect_true(all(c("A", "B", "C", "D") %in% validation$classes))
})

test_that("print.qlm_validation displays correctly", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  mock_results <- data.frame(id = 1:10, category = rep(c("A", "B"), 5))
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

  # Capture print output
  output <- capture.output(print(validation))

  expect_true(any(grepl("quallmer validation", output)))
  expect_true(any(grepl("n:", output)))
  expect_true(any(grepl("classes:", output)))
  expect_true(any(grepl("average:", output)))
  expect_true(any(grepl("accuracy", output)))
})

test_that("print.qlm_validation displays per-class metrics correctly", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  mock_results <- data.frame(id = 1:12, category = rep(c("A", "B", "C"), 4))
  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = paste0("text", 1:12),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 12)
  )

  gold <- data.frame(.id = 1:12, category = rep(c("A", "B", "C"), 4))

  validation <- qlm_validate(mock_coded, gold, by = "category", average = "none")

  # Capture print output
  output <- capture.output(print(validation))

  expect_true(any(grepl("Global", output)))
  expect_true(any(grepl("By class", output)))
  expect_true(any(grepl("class", output)))
  expect_true(any(grepl("precision", output)))
  expect_true(any(grepl("recall", output)))
})

test_that("qlm_validate handles partial overlap of IDs", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  mock_results <- data.frame(id = 1:10, category = rep(c("A", "B"), 5))
  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = paste0("text", 1:10),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10)
  )

  # Gold with partial overlap (IDs 5-15)
  gold <- data.frame(.id = 5:15, category = rep(c("A", "B"), length.out = 11))

  validation <- qlm_validate(mock_coded, gold, by = "category")

  # Should only include overlapping IDs (5-10 = 6 units)
  expect_equal(validation$n, 6)
})

test_that("qlm_validate handles all NAs error", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  mock_results <- data.frame(id = 1:10, category = rep(NA_character_, 10))
  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = paste0("text", 1:10),
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10)
  )

  gold <- data.frame(.id = 1:10, category = rep(c("A", "B"), 5))

  # Should warn about NAs and error when all values are NA
  expect_error(
    suppressWarnings(qlm_validate(mock_coded, gold, by = "category")),
    "No complete cases found"
  )
})

test_that("qlm_validate accepts qlm_coded object as gold standard", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  # Create first qlm_coded object (predictions)
  mock_results1 <- data.frame(id = 1:10, category = rep(c("A", "B"), 5))
  mock_coded1 <- new_qlm_coded(
    results = mock_results1,
    codebook = codebook,
    data = paste0("text", 1:10),
    chat_args = list(name = "test/model1"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10)
  )

  # Create second qlm_coded object (gold standard)
  mock_results2 <- data.frame(id = 1:10, category = rep(c("A", "B"), 5))
  mock_coded2 <- new_qlm_coded(
    results = mock_results2,
    codebook = codebook,
    data = paste0("text", 1:10),
    chat_args = list(name = "test/model2"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10)
  )

  # Should accept qlm_coded object as gold
  validation <- qlm_validate(mock_coded1, gold = mock_coded2, by = "category")

  expect_true(inherits(validation, "qlm_validation"))
  expect_equal(validation$accuracy, 1.0)  # Perfect match
  expect_equal(validation$n, 10)
})

test_that("qlm_validate with qlm_coded gold handles imperfect predictions", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  # Create predictions
  mock_results1 <- data.frame(
    id = 1:10,
    category = c(rep("A", 7), rep("B", 3))
  )
  mock_coded1 <- new_qlm_coded(
    results = mock_results1,
    codebook = codebook,
    data = paste0("text", 1:10),
    chat_args = list(name = "test/model1"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10)
  )

  # Create gold standard (different predictions)
  mock_results2 <- data.frame(
    id = 1:10,
    category = rep(c("A", "B"), 5)
  )
  mock_coded2 <- new_qlm_coded(
    results = mock_results2,
    codebook = codebook,
    data = paste0("text", 1:10),
    chat_args = list(name = "test/model2"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10)
  )

  validation <- qlm_validate(mock_coded1, gold = mock_coded2, by = "category")

  expect_true(inherits(validation, "qlm_validation"))
  expect_true(validation$accuracy < 1.0)
  expect_true(validation$accuracy >= 0.5)
  expect_true(is.numeric(validation$precision))
  expect_true(is.numeric(validation$recall))
  expect_true(is.numeric(validation$f1))
  expect_true(is.numeric(validation$kappa))
})
