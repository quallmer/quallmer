#### Create salience codebook for examples
library(quallmer)
library(ellmer)

# Create salience codebook for topic ranking
max_topics <- 5

instructions <- paste(
  "Extract structured data on the salience of topics discussed in texts.",
  "",
  "Task:",
  "- Read the text carefully.",
  "- Identify the topics discussed.",
  "- Return a ranked list of topics, ordered by their salience in the text.",
  "- Salience refers to how prominently and frequently a topic is discussed,",
  "  including the amount of space and emphasis devoted to it.",
  "",
  "Do not infer information that is not in the text.",
  "Base all evaluations solely on the language and arguments in the document.",
  sep = "\n"
)

topics_text <- paste0(
  "\n\nIdentify and return up to ", max_topics,
  " of the most salient topics directly from the text, ranked in descending order of salience.",
  " If fewer topics are clearly present, return only those."
)

data_codebook_salience <- qlm_codebook(
  name = "Salience (ranked topics)",
  instructions = paste0(instructions, topics_text),
  schema = ellmer::type_object(
    topics = ellmer::type_array(
      ellmer::type_string(
        paste0("Topics mentioned in the text, listed in order of salience (first = most salient, up to ", max_topics, " topics).")
      )
    ),
    explanation = ellmer::type_string(
      "A brief explanation of why these topics were selected and ordered in this way, referring to specific wording, emphasis, or sections of the text."
    )
  ),
  role = "You are an expert analysing the content of texts.",
  input_type = "text"
)

# Save as package data
usethis::use_data(data_codebook_salience, overwrite = TRUE)
