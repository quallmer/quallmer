#### Create fact-checking codebook for examples
library(quallmer)
library(ellmer)

# Create fact-checking codebook
max_topics <- 5

instructions <- paste(
  "Your goal is to provide an overall assessment of how truthful and accurate",
  "the text is, and to highlight any topics that reduce your confidence.",
  "",
  "Task:",
  "- Read the text carefully.",
  "- Consider the factual claims and implications made in the text.",
  "- Assign an overall truthfulness score from 0 to 10, where:",
  "  0 = almost completely false or highly misleading,",
  "  5 = mixed or partially accurate with significant issues,",
  " 10 = highly accurate, with no obvious false or misleading claims.",
  "- If specific topics or issues in the text reduce your confidence in its",
  "  truthfulness, list them as \"low confidence topics\".",
  "- If no particular topics stand out as problematic, leave the list empty.",
  "",
  "Do not invent new facts or details that are not widely known.",
  "Base your evaluation on general background knowledge and on the wording",
  "of the text itself.",
  sep = "\n"
)

topics_text <- paste0(
  "\n\nIdentify and return up to ", max_topics,
  " topics, issues or themes that lower your confidence in the truthfulness",
  " of the text. If none are clearly problematic, return an empty list."
)

data_codebook_fact <- qlm_codebook(
  name = "Fact-checking",
  instructions = paste0(instructions, topics_text),
  schema = ellmer::type_object(
    truth_score = ellmer::type_integer(
      "Overall truthfulness and accuracy score from 0 (almost completely false or highly misleading) to 10 (highly accurate and truthful)."
    ),
    misleading_topic = ellmer::type_array(
      ellmer::type_string(
        paste0(
          "Topics, issues, or themes that reduce confidence in the truthfulness of the text (up to ",
          max_topics, " items)."
        )
      )
    ),
    explanation = ellmer::type_string(
      "Brief explanation for the assigned truthfulness score and how the listed topics, if any, contribute to reduced confidence."
    )
  ),
  role = "You are an expert fact-checker analysing the content of texts.",
  input_type = "text"
)

# Save as package data
usethis::use_data(data_codebook_fact, overwrite = TRUE)
