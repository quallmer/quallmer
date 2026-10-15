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
