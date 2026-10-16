mock_translation_chat <- function(responder = function(text) text, env = parent.frame()) {
  withr::local_envvar(c(OPENAI_API_KEY = "test-key"), .local_envir = env)
  seen <- new.env(parent = emptyenv())
  seen$prompts <- list()
  testthat::local_mocked_bindings(parallel_chat = function(chat, prompts, max_active, rpm, on_error) {
    seen$prompts <- c(seen$prompts, prompts)
    lapply(prompts, function(prompt) {
      input <- jsonlite::fromJSON(prompt)
      value <- responder(input$source_text)
      if (inherits(value, "error") || inherits(value, "ellmer::Turn") || is.null(value)) return(value)
      turn <- text_turn(value)
      turn@json <- list(model = "model-snapshot")
      turn
    })
  }, .package = "ellmer", .env = env)
  seen
}

mock_translation_deepl <- function(transform = function(text) text, env = parent.frame()) {
  seen <- new.env(parent = emptyenv())
  seen$requests <- list()
  httr2::local_mocked_responses(function(req) {
    seen$requests[[length(seen$requests) + 1L]] <- req
    text <- req$body$data$text
    httr2::response_json(body = list(translations = lapply(text, function(item) {
      list(text = transform(item), detected_source_language = "FR",
           model_type_used = "quality_optimized", billed_characters = nchar(item))
    })))
  }, env = env)
  seen
}

mock_translation_qwen <- function(responder = NULL, env = parent.frame()) {
  withr::local_envvar(c(DASHSCOPE_API_KEY = "qwen-test-key"), .local_envir = env)
  testthat::local_mocked_bindings(req_throttle = function(req, ...) req,
                                 .package = "httr2", .env = env)
  seen <- new.env(parent = emptyenv())
  seen$requests <- list()
  httr2::local_mocked_responses(function(req) {
    seen$requests[[length(seen$requests) + 1L]] <- req
    body <- req$body$data
    if (!is.null(responder)) return(responder(body))
    httr2::response_json(body = list(id = "request-test", model = body$model,
      choices = list(list(message = list(content = body$messages[[1]]$content),
                          finish_reason = "stop")),
      usage = list(prompt_tokens = 5, completion_tokens = 5, total_tokens = 10)))
  }, env = env)
  seen
}

qwen_test_group_size <- function(body) {
  terms <- body$translation_options$terms
  1L + sum(vapply(terms, function(term) startsWith(term$source, "QLMP"), logical(1)))
}
