#' Predefined tasks
#'
#' Sentiment analysis task
#' Analyzes short texts and returns a sentiment score (-1 to 1) and a short explanation.
#' @return A task object
#' @export
sentiment <- function() {
  define_task(
    name = "Sentiment analysis",
    system_prompt = "You are an expert annotator. Rate the sentiment of each text from -1 (very negative) to 1 (very positive) and briefly explain why.",
    type_object = ellmer::type_object(
      score = ellmer::type_number("Sentiment score between -1 (very negative) and 1 (very positive)"),
      explanation = ellmer::type_string("Brief explanation of the rating")
    ),
    input_type = "text"
  )
}

# Internal registry of built-in tasks
.predefined_tasks <- list(
  sentiment = sentiment
)

#' Theme coding task
#' Codes short texts for the presence of predefined themes and provides brief explanations.
#' @return A task object
#' @export
themes <- function() {
  define_task(
    name = "Theme coding",
    system_prompt = "You are an expert annotator. For each text, indicate whether the following themes are present: 'Health', 'Environment', 'Technology', 'Education'. Provide a brief explanation for each theme's presence or absence.",
    type_object = ellmer::type_object(
      Health = ellmer::type_boolean("Indicates if the theme 'Health' is present"),
      Environment = ellmer::type_boolean("Indicates if the theme 'Environment' is present"),
      Technology = ellmer::type_boolean("Indicates if the theme 'Technology' is present"),
      Education = ellmer::type_boolean("Indicates if the theme 'Education' is present"),
      explanations = ellmer::type_string("Brief explanations for the presence or absence of each theme")
    ),
    input_type = "text"
  )
}
