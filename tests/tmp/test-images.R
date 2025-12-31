library(quallmer)
library(ellmer)
library(dplyr)

image_task <- task(
  name = "Campaign Poster Analysis",
  system_prompt = "You are a political scientist
    analysing campaign poster images.",
  type_def = type_object(
    candidate_name = type_string("Name of candidate"),
    text_translation = type_string("English translation"),
    facial_expression = type_enum(
      c("smiling", "serious", "neutral")),
    has_party_logo = type_boolean("Party logo present?")
  ),
  input_type = "image"
)

# Get image files
image_files <- list.files("~/GitHub/instats_dec25/sessions/Session_6_Ken_40min/data_images/",
                          pattern = "\\.jpg$",
                          full.names = TRUE)

# Annotate images
result <- quallmer::annotate(
  image_files,
  task = image_task,
  chat_fn = chat_google_gemini,
  model = "non-existent",
  params = params(temperature = 0)
)

chat <- chat_google_gemini(
  system_prompt = "You are a political scientist analysing campaign poster images.",
  model = "non-existent"
)

result_df <- parallel_chat_structured(
  chat,
  type = type_object(
    candidate_name = type_string("Name of candidate"),
    text_translation = type_string("English translation"),
    facial_expression = type_enum(
      c("smiling", "serious", "neutral")),
    has_party_logo = type_boolean("Party logo present?")
  ),
  prompts = purrr::map(image_files, content_image_file),
  convert = TRUE,
  include_cost = TRUE,
  include_tokens = TRUE
)
