#### Create sentiment codebook for examples
library(quallmer)
library(ellmer)

# Create sentiment analysis codebook matching data_corpus_LMRDsample structure
# but with expanded polarity to include "mixed"
data_codebook_sentiment <- qlm_codebook(
  name = "Movie Review Sentiment",
  instructions = paste(
    "Analyze the sentiment of this movie review, on both a 1-10 scale and as a polarity of negative or positive."
  ),
  schema = ellmer::type_object(
    polarity = ellmer::type_enum(
      c("neg", "pos"),
      description = "Overall sentiment polarity: negative (neg) or positive (pos)"
    ),
    rating = ellmer::type_integer(
      description = "Sentiment rating from 1 (most negative) to 10 (most positive)"
    )
  ),
  role = "You are an amateur film critic writing a movie review on for a movie website.",
  input_type = "text"
)

# Save as package data
usethis::use_data(data_codebook_sentiment, overwrite = TRUE)

