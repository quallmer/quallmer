#### Create stance codebook for examples
library(quallmer)
library(ellmer)

# Create stance detection codebook for climate change
data_codebook_stance <- qlm_codebook(
  name = "Stance detection",
  instructions = paste0(
    "Read each short text carefully and determine its stance towards ",
    "climate change",
    ". Classify the stance as Pro, Neutral, or Contra, and provide a brief explanation for your classification."
  ),
  schema = ellmer::type_object(
    stance = ellmer::type_string("Stance towards the topic: Pro, Neutral, or Contra"),
    explanation = ellmer::type_string("Brief explanation of the classification")
  ),
  role = "You are an expert annotator.",
  input_type = "text"
)

# Save as package data
usethis::use_data(data_codebook_stance, overwrite = TRUE)
