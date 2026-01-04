test_that("qlm_trail() requires at least one object", {
  expect_error(
    qlm_trail(),
    "At least one object must be provided"
  )
})


test_that("qlm_trail() validates object types", {
  bad_obj <- list(foo = "bar")
  class(bad_obj) <- "not_a_quallmer_object"

  expect_error(
    qlm_trail(bad_obj),
    "All objects must be quallmer objects"
  )
})


test_that("qlm_trail() extracts single coded object info", {
  # Create a mock qlm_coded object
  coded <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded) <- c("qlm_coded", "data.frame")

  attr(coded, "run") <- list(
    name = "run1",
    call = quote(qlm_code(data, codebook)),
    parent = NULL,
    metadata = list(
      timestamp = as.POSIXct("2024-01-01 12:00:00"),
      n_units = 3
    ),
    chat_args = list(name = "openai/gpt-4o"),
    codebook = list(name = "sentiment")
  )

  trail <- qlm_trail(coded)

  expect_s3_class(trail, "qlm_trail")
  expect_true(trail$complete)
  expect_length(trail$runs, 1)
  expect_equal(names(trail$runs)[1], "run1")
  expect_null(trail$runs[[1]]$parent)
})


test_that("qlm_trail() reconstructs chain from multiple objects", {
  # Create parent coded object
  coded1 <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded1) <- c("qlm_coded", "data.frame")
  attr(coded1, "run") <- list(
    name = "run1",
    call = quote(qlm_code(data, codebook)),
    parent = NULL,
    metadata = list(timestamp = as.POSIXct("2024-01-01 12:00:00")),
    chat_args = list(name = "openai/gpt-4o"),
    codebook = list(name = "sentiment")
  )

  # Create child coded object (replicate)
  coded2 <- data.frame(.id = 1:3, polarity = c("pos", "pos", "pos"))
  class(coded2) <- c("qlm_coded", "data.frame")
  attr(coded2, "run") <- list(
    name = "run2",
    call = quote(qlm_replicate(coded1)),
    parent = "run1",
    metadata = list(timestamp = as.POSIXct("2024-01-01 13:00:00")),
    chat_args = list(name = "anthropic/claude-sonnet-4"),
    codebook = list(name = "sentiment")
  )

  trail <- qlm_trail(coded2, coded1)

  expect_s3_class(trail, "qlm_trail")
  expect_true(trail$complete)
  expect_length(trail$runs, 2)

  # Should be ordered parent first
  expect_equal(names(trail$runs), c("run1", "run2"))
  expect_null(trail$runs$run1$parent)
  expect_equal(trail$runs$run2$parent, "run1")
})


test_that("qlm_trail() handles incomplete chains", {
  # Create coded object with parent reference but parent not provided
  coded <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded) <- c("qlm_coded", "data.frame")
  attr(coded, "run") <- list(
    name = "run2",
    parent = "run1",  # Parent not in provided objects
    metadata = list(timestamp = as.POSIXct("2024-01-01 13:00:00")),
    chat_args = list(name = "openai/gpt-4o"),
    codebook = list(name = "sentiment")
  )

  trail <- qlm_trail(coded)

  expect_s3_class(trail, "qlm_trail")
  expect_false(trail$complete)  # Should be marked incomplete
  expect_length(trail$runs, 1)
})


test_that("qlm_trail() handles comparison objects with multiple parents", {
  # Create two coded objects
  coded1 <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded1) <- c("qlm_coded", "data.frame")
  attr(coded1, "run") <- list(
    name = "run1",
    parent = NULL,
    metadata = list(timestamp = as.POSIXct("2024-01-01 12:00:00"))
  )

  coded2 <- data.frame(.id = 1:3, polarity = c("pos", "pos", "pos"))
  class(coded2) <- c("qlm_coded", "data.frame")
  attr(coded2, "run") <- list(
    name = "run2",
    parent = NULL,
    metadata = list(timestamp = as.POSIXct("2024-01-01 13:00:00"))
  )

  # Create comparison object
  comp <- list(measure = "alpha", value = 0.8)
  class(comp) <- "qlm_comparison"
  attr(comp, "run") <- list(
    name = "comparison_abc123",
    parent = c("run1", "run2"),  # Multiple parents
    metadata = list(timestamp = as.POSIXct("2024-01-01 14:00:00"))
  )

  trail <- qlm_trail(comp, coded1, coded2)

  expect_s3_class(trail, "qlm_trail")
  expect_true(trail$complete)
  expect_length(trail$runs, 3)

  # Comparison should have both parents
  expect_equal(trail$runs$comparison_abc123$parent, c("run1", "run2"))
})


test_that("qlm_trail() handles validation objects", {
  # Create coded object
  coded <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded) <- c("qlm_coded", "data.frame")
  attr(coded, "run") <- list(
    name = "run1",
    parent = NULL,
    metadata = list(timestamp = as.POSIXct("2024-01-01 12:00:00"))
  )

  # Create validation object
  valid <- list(accuracy = 0.9)
  class(valid) <- "qlm_validation"
  attr(valid, "run") <- list(
    name = "validation_xyz789",
    parent = "run1",
    metadata = list(timestamp = as.POSIXct("2024-01-01 14:00:00"))
  )

  trail <- qlm_trail(valid, coded)

  expect_s3_class(trail, "qlm_trail")
  expect_true(trail$complete)
  expect_length(trail$runs, 2)
  expect_equal(trail$runs$validation_xyz789$parent, "run1")
})


test_that("print.qlm_trail() handles single run", {
  coded <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded) <- c("qlm_coded", "data.frame")
  attr(coded, "run") <- list(
    name = "run1",
    parent = NULL,
    metadata = list(timestamp = as.POSIXct("2024-01-01 12:00:00")),
    chat_args = list(name = "openai/gpt-4o")
  )

  trail <- qlm_trail(coded)

  # Should print without error
  output <- capture.output(print(trail))
  expect_true(any(grepl("quallmer trail", output)))
  expect_true(any(grepl("run1", output)))
})


test_that("print.qlm_trail() handles multiple runs", {
  coded1 <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded1) <- c("qlm_coded", "data.frame")
  attr(coded1, "run") <- list(
    name = "run1",
    parent = NULL,
    metadata = list(timestamp = as.POSIXct("2024-01-01 12:00:00")),
    chat_args = list(name = "openai/gpt-4o"),
    codebook = list(name = "sentiment")
  )

  coded2 <- data.frame(.id = 1:3, polarity = c("pos", "pos", "pos"))
  class(coded2) <- c("qlm_coded", "data.frame")
  attr(coded2, "run") <- list(
    name = "run2",
    parent = "run1",
    metadata = list(timestamp = as.POSIXct("2024-01-01 13:00:00")),
    chat_args = list(name = "anthropic/claude-sonnet-4"),
    codebook = list(name = "sentiment")
  )

  trail <- qlm_trail(coded2, coded1)

  output <- capture.output(print(trail))
  expect_true(any(grepl("2 runs", output)))
  expect_true(any(grepl("run1", output)))
  expect_true(any(grepl("run2", output)))
  expect_true(any(grepl("original", output)))
  expect_true(any(grepl("parent: run1", output)))
})


test_that("print.qlm_trail() warns about incomplete chains", {
  coded <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded) <- c("qlm_coded", "data.frame")
  attr(coded, "run") <- list(
    name = "run2",
    parent = "run1",  # Missing
    metadata = list(timestamp = as.POSIXct("2024-01-01 13:00:00"))
  )

  trail <- qlm_trail(coded)

  output <- capture.output(print(trail))
  expect_true(any(grepl("full chain", output)))
})


test_that("qlm_trail_save() validates input", {
  bad_obj <- list(foo = "bar")

  expect_error(
    qlm_trail_save(bad_obj, "test.rds"),
    "must be a.*qlm_trail"
  )
})


test_that("qlm_trail_save() saves RDS file", {
  coded <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded) <- c("qlm_coded", "data.frame")
  attr(coded, "run") <- list(
    name = "run1",
    parent = NULL,
    metadata = list(timestamp = as.POSIXct("2024-01-01 12:00:00"))
  )

  trail <- qlm_trail(coded)

  temp_file <- tempfile(fileext = ".rds")
  withr::defer(unlink(temp_file))

  result <- qlm_trail_save(trail, temp_file)

  expect_true(file.exists(temp_file))
  expect_equal(result, temp_file)

  # Verify we can read it back
  loaded <- readRDS(temp_file)
  expect_s3_class(loaded, "qlm_trail")
  expect_equal(loaded$runs, trail$runs)
})


test_that("qlm_trail_export() validates input", {
  bad_obj <- list(foo = "bar")

  expect_error(
    qlm_trail_export(bad_obj, "test.json"),
    "must be a.*qlm_trail"
  )
})


test_that("qlm_trail_export() creates valid JSON", {
  coded <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded) <- c("qlm_coded", "data.frame")
  attr(coded, "run") <- list(
    name = "run1",
    parent = NULL,
    call = quote(qlm_code(data, codebook)),
    metadata = list(
      timestamp = as.POSIXct("2024-01-01 12:00:00"),
      n_units = 3,
      quallmer_version = "0.2",
      R_version = "4.3.0"
    ),
    chat_args = list(
      name = "openai/gpt-4o",
      temperature = 0.5
    ),
    codebook = list(name = "sentiment")
  )

  trail <- qlm_trail(coded)

  temp_file <- tempfile(fileext = ".json")
  withr::defer(unlink(temp_file))

  result <- qlm_trail_export(trail, temp_file)

  expect_true(file.exists(temp_file))
  expect_equal(result, temp_file)

  # Verify it's valid JSON
  json_data <- jsonlite::fromJSON(temp_file)
  expect_true(json_data$complete)
  expect_equal(json_data$n_runs, 1)
  expect_equal(json_data$runs[[1]]$name, "run1")
  expect_equal(json_data$runs[[1]]$model, "openai/gpt-4o")
  expect_equal(json_data$runs[[1]]$temperature, 0.5)
  expect_equal(json_data$runs[[1]]$codebook_name, "sentiment")
})


test_that("qlm_trail_report() validates input", {
  bad_obj <- list(foo = "bar")

  expect_error(
    qlm_trail_report(bad_obj, "test.qmd"),
    "must be a.*qlm_trail"
  )
})


test_that("qlm_trail_report() validates file extension", {
  coded <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded) <- c("qlm_coded", "data.frame")
  attr(coded, "run") <- list(name = "run1", parent = NULL)

  trail <- qlm_trail(coded)

  expect_error(
    qlm_trail_report(trail, "test.txt"),
    "must have.*qmd.*Rmd"
  )
})


test_that("qlm_trail_report() creates Quarto document", {
  coded <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded) <- c("qlm_coded", "data.frame")
  attr(coded, "run") <- list(
    name = "run1",
    parent = NULL,
    call = quote(qlm_code(data, codebook)),
    metadata = list(
      timestamp = as.POSIXct("2024-01-01 12:00:00"),
      n_units = 3,
      quallmer_version = "0.2",
      ellmer_version = "0.4.0",
      R_version = "4.3.0"
    ),
    chat_args = list(
      name = "openai/gpt-4o",
      temperature = 0.5
    ),
    codebook = list(name = "sentiment")
  )

  trail <- qlm_trail(coded)

  temp_file <- tempfile(fileext = ".qmd")
  withr::defer(unlink(temp_file))

  result <- qlm_trail_report(trail, temp_file)

  expect_true(file.exists(temp_file))
  expect_equal(result, temp_file)

  # Read and verify content
  content <- readLines(temp_file)
  expect_true(any(grepl("quallmer trail", content)))
  expect_true(any(grepl("Trail Summary", content)))
  expect_true(any(grepl("Timeline", content)))
  expect_true(any(grepl("run1", content)))
  expect_true(any(grepl("format: html", content)))
})


test_that("qlm_trail_report() creates RMarkdown document", {
  coded <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded) <- c("qlm_coded", "data.frame")
  attr(coded, "run") <- list(
    name = "run1",
    parent = NULL,
    call = quote(qlm_code(data, codebook)),
    metadata = list(
      timestamp = as.POSIXct("2024-01-01 12:00:00"),
      n_units = 3
    ),
    chat_args = list(name = "openai/gpt-4o"),
    codebook = list(name = "sentiment")
  )

  trail <- qlm_trail(coded)

  temp_file <- tempfile(fileext = ".Rmd")
  withr::defer(unlink(temp_file))

  result <- qlm_trail_report(trail, temp_file)

  expect_true(file.exists(temp_file))

  # Read and verify content
  content <- readLines(temp_file)
  expect_true(any(grepl("output: html_document", content)))
  expect_false(any(grepl("format: html", content)))  # Should use Rmd format
})


test_that("qlm_trail_report() accepts boolean flags for comparisons/validations", {
  coded <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded) <- c("qlm_coded", "data.frame")
  attr(coded, "run") <- list(name = "run1", parent = NULL)

  trail <- qlm_trail(coded)
  temp_file <- tempfile(fileext = ".qmd")

  # Should work with TRUE/FALSE flags
  expect_no_error(
    qlm_trail_report(trail, temp_file, include_comparisons = TRUE, include_validations = FALSE)
  )
  expect_true(file.exists(temp_file))
})


test_that("qlm_trail_report() validates robustness parameter", {
  coded <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded) <- c("qlm_coded", "data.frame")
  attr(coded, "run") <- list(name = "run1", parent = NULL)

  trail <- qlm_trail(coded)
  temp_file <- tempfile(fileext = ".qmd")

  # Should error with invalid robustness object
  expect_error(
    qlm_trail_report(trail, temp_file, robustness = data.frame(x = 1)),
    "qlm_robustness"
  )
})


test_that("qlm_trail_report() includes comparison metrics", {
  # Create coded objects
  coded1 <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded1) <- c("qlm_coded", "data.frame")
  attr(coded1, "run") <- list(name = "run1", parent = NULL)

  coded2 <- data.frame(.id = 1:3, polarity = c("pos", "pos", "pos"))
  class(coded2) <- c("qlm_coded", "data.frame")
  attr(coded2, "run") <- list(name = "run2", parent = NULL)

  # Create comparison object with data (nominal level)
  comparison <- list(
    level = "nominal",
    subjects = 3,
    raters = 2,
    alpha_nominal = 0.85,
    kappa = 0.82,
    kappa_type = "Cohen's",
    percent_agreement = 0.90
  )
  class(comparison) <- "qlm_comparison"
  attr(comparison, "run") <- list(
    name = "comparison1",
    parent = c("run1", "run2")
  )

  trail <- qlm_trail(coded1, coded2, comparison)

  temp_file <- tempfile(fileext = ".qmd")
  withr::defer(unlink(temp_file))

  qlm_trail_report(trail, temp_file, include_comparisons = TRUE)

  content <- readLines(temp_file)
  content_str <- paste(content, collapse = " ")

  # Check for comparison section
  expect_true(any(grepl("Inter-rater Reliability Comparisons", content)))
  expect_true(any(grepl("Krippendorff", content)))  # "Krippendorff's alpha"
  expect_true(any(grepl("0\\.85", content)))  # alpha_nominal value
})


test_that("qlm_trail_report() includes validation metrics", {
  # Create coded object
  coded <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded) <- c("qlm_coded", "data.frame")
  attr(coded, "run") <- list(name = "run1", parent = NULL)

  # Create validation object with data (nominal level)
  validation <- list(
    level = "nominal",
    n = 3,
    classes = c("pos", "neg"),
    average = "macro",
    accuracy = 0.90,
    precision = 0.88,
    recall = 0.85,
    f1 = 0.86,
    kappa = 0.80,
    rho = NULL,
    tau = NULL,
    r = NULL,
    icc = NULL,
    mae = NULL,
    rmse = NULL
  )
  class(validation) <- "qlm_validation"
  attr(validation, "run") <- list(
    name = "validation1",
    parent = "run1"
  )

  trail <- qlm_trail(coded, validation)

  temp_file <- tempfile(fileext = ".qmd")
  withr::defer(unlink(temp_file))

  qlm_trail_report(trail, temp_file, include_validations = TRUE)

  content <- readLines(temp_file)

  # Check for validation section
  expect_true(any(grepl("Validation Against Gold Standard", content)))
  expect_true(any(grepl("0\\.90", content)))  # accuracy
  expect_true(any(grepl("0\\.88", content)))  # precision
})


test_that("qlm_trail_report() includes robustness metrics", {
  # Create coded objects
  coded1 <- data.frame(.id = 1:3, score = c(3, 2, 4))
  class(coded1) <- c("qlm_coded", "data.frame")
  attr(coded1, "run") <- list(name = "run1", parent = NULL)

  coded2 <- data.frame(.id = 1:3, score = c(3.2, 2.1, 4.3))
  class(coded2) <- c("qlm_coded", "data.frame")
  attr(coded2, "run") <- list(name = "run2", parent = NULL)

  # Create robustness object
  robustness <- data.frame(
    run = "run2",
    statistic = "mean_score",
    value = 3.2,
    reference_value = 3.0,
    abs_diff = 0.2,
    pct_diff = 6.67,
    stringsAsFactors = FALSE
  )
  class(robustness) <- c("qlm_robustness", "data.frame")
  attr(robustness, "reference") <- "run1"

  trail <- qlm_trail(coded1, coded2)

  temp_file <- tempfile(fileext = ".qmd")
  withr::defer(unlink(temp_file))

  qlm_trail_report(trail, temp_file, robustness = robustness)

  content <- readLines(temp_file)

  # Check for robustness section
  expect_true(any(grepl("Downstream Analysis Robustness", content)))
  expect_true(any(grepl("Reference run: run1", content)))
  expect_true(any(grepl("mean_score", content)))
  expect_true(any(grepl("6\\.67", content)))  # percent change
})


test_that("qlm_trail_report() includes all metrics together", {
  # Create coded objects
  coded1 <- data.frame(.id = 1:3, score = c(3, 2, 4))
  class(coded1) <- c("qlm_coded", "data.frame")
  attr(coded1, "run") <- list(name = "run1", parent = NULL)

  coded2 <- data.frame(.id = 1:3, score = c(3.2, 2.1, 4.3))
  class(coded2) <- c("qlm_coded", "data.frame")
  attr(coded2, "run") <- list(name = "run2", parent = NULL)

  # Create comparison with data (interval level)
  comparison <- list(
    level = "interval",
    subjects = 3,
    raters = 2,
    alpha_interval = 0.93,
    icc = 0.95,
    r = 0.96,
    percent_agreement = 0.85
  )
  class(comparison) <- "qlm_comparison"
  attr(comparison, "run") <- list(name = "comp1", parent = c("run1", "run2"))

  # Create robustness
  robustness <- data.frame(
    run = "run2",
    statistic = "mean_score",
    value = 3.2,
    reference_value = 3.0,
    abs_diff = 0.2,
    pct_diff = 6.67,
    stringsAsFactors = FALSE
  )
  class(robustness) <- c("qlm_robustness", "data.frame")
  attr(robustness, "reference") <- "run1"

  trail <- qlm_trail(coded1, coded2, comparison)

  temp_file <- tempfile(fileext = ".qmd")
  withr::defer(unlink(temp_file))

  qlm_trail_report(trail, temp_file, include_comparisons = TRUE, robustness = robustness)

  content <- readLines(temp_file)

  # Check all sections present
  expect_true(any(grepl("Assessment Metrics", content)))
  expect_true(any(grepl("Inter-rater Reliability Comparisons", content)))
  expect_true(any(grepl("Downstream Analysis Robustness", content)))
  expect_true(any(grepl("ICC", content, ignore.case = TRUE)))  # ICC in comparison
  expect_true(any(grepl("mean_score", content)))
})


test_that("qlm_trail() handles complex branching workflow", {
  # Create three initial coded objects
  coded1 <- data.frame(.id = 1:3, polarity = c("pos", "neg", "pos"))
  class(coded1) <- c("qlm_coded", "data.frame")
  attr(coded1, "run") <- list(
    name = "run1",
    parent = NULL,
    metadata = list(timestamp = as.POSIXct("2024-01-01 12:00:00"))
  )

  coded2 <- data.frame(.id = 1:3, polarity = c("pos", "pos", "pos"))
  class(coded2) <- c("qlm_coded", "data.frame")
  attr(coded2, "run") <- list(
    name = "run2",
    parent = NULL,
    metadata = list(timestamp = as.POSIXct("2024-01-01 13:00:00"))
  )

  coded3 <- data.frame(.id = 1:3, polarity = c("neg", "neg", "pos"))
  class(coded3) <- c("qlm_coded", "data.frame")
  attr(coded3, "run") <- list(
    name = "run3",
    parent = NULL,
    metadata = list(timestamp = as.POSIXct("2024-01-01 14:00:00"))
  )

  # Create comparison of first two
  comp1 <- list(measure = "alpha", value = 0.8)
  class(comp1) <- "qlm_comparison"
  attr(comp1, "run") <- list(
    name = "comp1",
    parent = c("run1", "run2"),
    metadata = list(timestamp = as.POSIXct("2024-01-01 15:00:00"))
  )

  # Create validation of third against first
  valid1 <- list(accuracy = 0.7)
  class(valid1) <- "qlm_validation"
  attr(valid1, "run") <- list(
    name = "valid1",
    parent = c("run3", "run1"),  # run3 validated against run1
    metadata = list(timestamp = as.POSIXct("2024-01-01 16:00:00"))
  )

  trail <- qlm_trail(coded1, coded2, coded3, comp1, valid1)

  expect_s3_class(trail, "qlm_trail")
  expect_true(trail$complete)
  expect_length(trail$runs, 5)

  # All objects should be present
  expect_true("run1" %in% names(trail$runs))
  expect_true("run2" %in% names(trail$runs))
  expect_true("run3" %in% names(trail$runs))
  expect_true("comp1" %in% names(trail$runs))
  expect_true("valid1" %in% names(trail$runs))
})


test_that("qlm_trail_robustness computes downstream analysis differences", {
  skip_if_not_installed("ellmer")

  # Create mock coded objects
  coded1 <- data.frame(
    .id = c("a", "b", "c"),
    score = c(1, 2, 3),
    category = c("pos", "neg", "pos")
  )
  class(coded1) <- c("qlm_coded", "data.frame")
  attr(coded1, "run") <- list(name = "run1")

  # Similar results
  coded2 <- data.frame(
    .id = c("a", "b", "c"),
    score = c(1, 2, 3),
    category = c("pos", "neg", "pos")
  )
  class(coded2) <- c("qlm_coded", "data.frame")
  attr(coded2, "run") <- list(name = "run2")

  # Different results
  coded3 <- data.frame(
    .id = c("a", "b", "c"),
    score = c(2, 3, 4),
    category = c("pos", "neg", "neg")
  )
  class(coded3) <- c("qlm_coded", "data.frame")
  attr(coded3, "run") <- list(name = "run3")

  # Define analysis function
  my_analysis <- function(coded) {
    list(
      mean_score = mean(coded$score, na.rm = TRUE),
      sd_score = sd(coded$score, na.rm = TRUE)
    )
  }

  # Compute robustness
  rob <- qlm_trail_robustness(coded1, coded2, coded3,
                               reference = "run1",
                               analysis_fn = my_analysis)

  expect_s3_class(rob, "qlm_robustness")
  expect_s3_class(rob, "data.frame")
  expect_equal(attr(rob, "reference"), "run1")

  # Check columns
  expect_true("run" %in% names(rob))
  expect_true("statistic" %in% names(rob))
  expect_true("value" %in% names(rob))
  expect_true("reference_value" %in% names(rob))
  expect_true("abs_diff" %in% names(rob))
  expect_true("pct_diff" %in% names(rob))

  # Check run2 (same as run1, so zero difference)
  run2_mean <- rob[rob$run == "run2" & rob$statistic == "mean_score", ]
  expect_equal(run2_mean$abs_diff, 0)
  expect_equal(run2_mean$pct_diff, 0)

  # Check run3 (different, should have non-zero differences)
  run3_mean <- rob[rob$run == "run3" & rob$statistic == "mean_score", ]
  expect_true(run3_mean$abs_diff > 0)
})


test_that("qlm_trail_robustness validates inputs", {
  skip_if_not_installed("ellmer")

  coded1 <- data.frame(.id = c("a", "b"), score = c(1, 2))
  class(coded1) <- c("qlm_coded", "data.frame")
  attr(coded1, "run") <- list(name = "run1")

  my_analysis <- function(coded) list(mean_score = mean(coded$score))

  # Require at least 2 objects
  expect_error(
    qlm_trail_robustness(coded1, reference = "run1", analysis_fn = my_analysis),
    "At least two"
  )

  # Require reference to exist
  coded2 <- data.frame(.id = c("a", "b"), score = c(1, 2))
  class(coded2) <- c("qlm_coded", "data.frame")
  attr(coded2, "run") <- list(name = "run2")

  expect_error(
    qlm_trail_robustness(coded1, coded2, reference = "run999", analysis_fn = my_analysis),
    "not found"
  )

  # Require qlm_coded objects
  not_coded <- data.frame(.id = c("a", "b"), score = c(1, 2))

  expect_error(
    qlm_trail_robustness(coded1, not_coded, reference = "run1", analysis_fn = my_analysis),
    "qlm_coded"
  )

  # Require analysis_fn to be a function
  expect_error(
    qlm_trail_robustness(coded1, coded2, reference = "run1", analysis_fn = "not a function"),
    "must be a function"
  )

  # Require analysis_fn to return named list
  bad_fn <- function(coded) c(1, 2, 3)
  expect_error(
    qlm_trail_robustness(coded1, coded2, reference = "run1", analysis_fn = bad_fn),
    "named list"
  )
})
