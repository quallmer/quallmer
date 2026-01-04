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
    input_type = "text",
    chat_args = list(name = "test/model"),
    execution_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
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
    input_type = "text",
    chat_args = list(name = "test/model"),
    execution_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 5),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
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
    input_type = "text",
    chat_args = list(name = "test/model"),
    execution_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
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
    input_type = "text",
    chat_args = list(name = "test/model"),
    execution_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
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
    input_type = "text",
    chat_args = list(name = "test/model"),
    execution_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
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
    input_type = "text",
    chat_args = list(name = "test/model"),
    execution_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 12),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
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
    input_type = "text",
    chat_args = list(name = "test/model"),
    execution_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 20),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
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
    input_type = "text",
    chat_args = list(name = "test/model"),
    execution_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
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
    input_type = "text",
    chat_args = list(name = "test/model"),
    execution_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 12),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
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
    input_type = "text",
    chat_args = list(name = "test/model"),
    execution_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
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
    input_type = "text",
    chat_args = list(name = "test/model"),
    execution_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
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
    input_type = "text",
    chat_args = list(name = "test/model1"),
    execution_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
  )

  # Create second qlm_coded object (gold standard)
  mock_results2 <- data.frame(id = 1:10, category = rep(c("A", "B"), 5))
  mock_coded2 <- new_qlm_coded(
    results = mock_results2,
    codebook = codebook,
    data = paste0("text", 1:10),
    input_type = "text",
    chat_args = list(name = "test/model2"),
    execution_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
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
    input_type = "text",
    chat_args = list(name = "test/model1"),
    execution_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
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
    input_type = "text",
    chat_args = list(name = "test/model2"),
    execution_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
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

test_that("qlm_validate ordinal level computes only appropriate metrics", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(rating = ellmer::type_integer("Rating"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  # Create mock ratings data (1-5 scale)
  mock_results <- data.frame(
    id = 1:20,
    rating = c(1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 2, 3, 4, 5, 1, 3, 4, 5, 1, 2)
  )
  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = paste0("text", 1:20),
    input_type = "text",
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 20),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
  )

  # Gold standard - slightly different ratings
  gold <- data.frame(
    .id = 1:20,
    rating = c(1, 2, 3, 4, 5, 2, 3, 4, 5, 4, 2, 3, 3, 5, 1, 3, 4, 4, 2, 2)
  )

  # Validate with ordinal level
  validation <- qlm_validate(mock_coded, gold, by = "rating", level = "ordinal")

  expect_true(inherits(validation, "qlm_validation"))
  expect_equal(validation$level, "ordinal")

  # Should have rho, tau, mae for ordinal data
  expect_true(is.numeric(validation$rho))
  expect_true(is.numeric(validation$tau))
  expect_true(is.numeric(validation$mae))

  # Should NOT have nominal metrics
  expect_null(validation$accuracy)
  expect_null(validation$precision)
  expect_null(validation$recall)
  expect_null(validation$f1)
  expect_null(validation$kappa)

  # Should NOT have interval metrics
  expect_null(validation$pearson)
  expect_null(validation$icc)
  expect_null(validation$rmse)

  # Should NOT have by_class or confusion for ordinal data
  expect_null(validation$by_class)
  expect_null(validation$confusion)
})

test_that("qlm_validate ordinal correlation measures work correctly", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(rating = ellmer::type_integer("Rating"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  # Create mock data with strong positive correlation
  mock_results <- data.frame(
    id = 1:10,
    rating = c(1, 2, 3, 4, 5, 1, 2, 3, 4, 5)  # Predictions
  )
  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = paste0("text", 1:10),
    input_type = "text",
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
  )

  # Gold standard - same rankings, slightly different values
  gold <- data.frame(
    .id = 1:10,
    rating = c(1, 2, 3, 4, 5, 2, 3, 4, 5, 5)  # Truth
  )

  # Validate with ordinal
  validation_ordinal <- qlm_validate(mock_coded, gold, by = "rating", level = "ordinal")

  # Should have high correlations due to similar rankings
  expect_true(is.numeric(validation_ordinal$rho))
  expect_true(is.numeric(validation_ordinal$tau))
  expect_true(validation_ordinal$rho > 0.8)
  expect_true(validation_ordinal$tau > 0.6)

  # MAE should be small
  expect_true(is.numeric(validation_ordinal$mae))
  expect_true(validation_ordinal$mae < 1.0)
})

test_that("qlm_validate nominal level computes all metrics", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  mock_results <- data.frame(
    id = 1:20,
    category = rep(c("A", "B", "C"), length.out = 20)
  )
  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = paste0("text", 1:20),
    input_type = "text",
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 20),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
  )

  gold <- data.frame(
    .id = 1:20,
    category = rep(c("A", "B", "C"), length.out = 20)
  )

  # Validate with nominal level
  validation <- qlm_validate(mock_coded, gold, by = "category", level = "nominal")

  expect_true(inherits(validation, "qlm_validation"))
  expect_equal(validation$level, "nominal")

  # Should have all metrics for nominal data
  expect_true(is.numeric(validation$accuracy))
  expect_true(is.numeric(validation$precision))
  expect_true(is.numeric(validation$recall))
  expect_true(is.numeric(validation$f1))
  expect_true(is.numeric(validation$kappa))
})

test_that("qlm_validate prints appropriate terminology for ordinal vs nominal", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(rating = ellmer::type_integer("Rating"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  mock_results <- data.frame(id = 1:10, rating = c(1, 2, 3, 4, 5, 1, 2, 3, 4, 5))
  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = paste0("text", 1:10),
    input_type = "text",
    chat_args = list(name = "test/model"),
    pcs_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
  )

  gold <- data.frame(.id = 1:10, rating = c(1, 2, 3, 4, 5, 1, 2, 3, 4, 5))

  # Ordinal validation should print "levels" not "classes"
  validation_ordinal <- qlm_validate(mock_coded, gold, by = "rating", level = "ordinal")
  output_ordinal <- capture.output(print(validation_ordinal))
  expect_true(any(grepl("levels:", output_ordinal)))
  expect_false(any(grepl("classes:", output_ordinal)))
  expect_false(any(grepl("average:", output_ordinal)))  # No average for ordinal
  # Should show ordinal metrics with proper labels
  expect_true(any(grepl("Spearman's rho:", output_ordinal)))
  expect_true(any(grepl("Kendall's tau:", output_ordinal)))
  expect_true(any(grepl("MAE:", output_ordinal)))

  # Nominal validation should print "classes" and "average"
  validation_nominal <- qlm_validate(mock_coded, gold, by = "rating", level = "nominal")
  output_nominal <- capture.output(print(validation_nominal))
  expect_true(any(grepl("classes:", output_nominal)))
  expect_true(any(grepl("average:", output_nominal)))
  expect_false(any(grepl("levels:", output_nominal)))
})

test_that("qlm_validate supports non-standard evaluation for by argument", {
  skip_if_not_installed("ellmer")
  skip_if_not_installed("yardstick")

  type_obj <- ellmer::type_object(category = ellmer::type_string("Category"))
  codebook <- qlm_codebook("Test", "Test prompt", type_obj)

  mock_results <- data.frame(id = 1:10, category = rep(c("A", "B"), 5))
  mock_coded <- new_qlm_coded(
    results = mock_results,
    codebook = codebook,
    data = paste0("text", 1:10),
    input_type = "text",
    chat_args = list(name = "test/model"),
    execution_args = list(),
    metadata = list(timestamp = Sys.time(), n_units = 10),
    name = "original",
    call = quote(qlm_code(...)),
    parent = NULL
  )

  gold <- data.frame(.id = 1:10, category = rep(c("A", "B"), 5))

  # Test with unquoted variable name (NSE)
  validation_nse <- qlm_validate(mock_coded, gold, by = category)

  # Test with quoted variable name (traditional)
  validation_quoted <- qlm_validate(mock_coded, gold, by = "category")

  # Both should work and produce identical results
  expect_true(inherits(validation_nse, "qlm_validation"))
  expect_true(inherits(validation_quoted, "qlm_validation"))
  expect_equal(validation_nse$accuracy, validation_quoted$accuracy)
  expect_equal(validation_nse$precision, validation_quoted$precision)
  expect_equal(validation_nse$recall, validation_quoted$recall)
  expect_equal(validation_nse$f1, validation_quoted$f1)
  expect_equal(validation_nse$kappa, validation_quoted$kappa)
  expect_equal(validation_nse$n, validation_quoted$n)
  expect_equal(validation_nse$variable, validation_quoted$variable)
})

