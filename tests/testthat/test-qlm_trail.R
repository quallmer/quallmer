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
  expect_true(any(grepl("quallmer Provenance Trail", content)))
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