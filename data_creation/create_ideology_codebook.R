#### Create ideology codebook for examples
library(quallmer)
library(ellmer)

# Create ideological scaling codebook for left-right dimension
data_codebook_ideology <- qlm_codebook(
  name = "Ideological scaling",
  instructions = paste0(
    "Task:\n",
    "- Read each short text carefully.\n",
    "- Place the text on a 0 - 10 scale for the following ideological dimension: ",
    "left - right", ".\n",
    "- Interpret 0 as representing the FIRST pole mentioned in the dimension label,\n",
    "  and 10 as representing the SECOND pole mentioned.\n",
    "- Use the full 0 - 10 range where appropriate and avoid defaulting to middle values.\n",
    "- Base your decision only on the information in the text (do not infer external\n",
    "  knowledge about the author, party, or context).\n\n",
    "Output:\n",
    "- `score`: an integer from 0 to 10 indicating the position on the specified dimension.\n",
    "- `explanation`: a brief, text-based justification explaining why the score was chosen,\n",
    "  citing specific phrases or arguments from the text."
  ),
  schema = ellmer::type_object(
    score = ellmer::type_integer("Ideological position on the specified dimension (0 - 10, where 0 = first pole, 10 = second pole)"),
    explanation = ellmer::type_string("Brief justification for the assigned score, referring to specific elements in the text")
  ),
  role = "You are an expert political scientist performing ideological text scaling.",
  input_type = "text"
)

# Save as package data
usethis::use_data(data_codebook_ideology, overwrite = TRUE)
