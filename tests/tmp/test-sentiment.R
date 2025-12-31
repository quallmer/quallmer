library(quallmer)
library(quanteda.tidy)

# Load the Trump tweets dataset
load("~/GitHub/instats_dec25/sessions/Session_4_Ken_40min/data/data_corpus_trumptweets.rda")

# Sample 100 tweets from each device
set.seed(12345)
tweetsample <- data_corpus_trumptweets |>
  filter(stringr::str_detect(device, "Android|iPhone|Web Client")) |>
  mutate(device = droplevels(device)) |>
  filter(!isRetweet) |>
  corpus_sample(size = 100, by = device)

table(tweetsample$device)

sentiment_task <- task(
  name = "Tweet Sentiment Analysis",
  system_prompt = "You are a social media analyst scoring sentiment from Tweets.
                   Evaluate the emotional tone of each tweet carefully,
                   considering context, sarcasm, and implied meaning.",
  type_def = type_object(
    sentiment = type_integer("A sentiment value from -2 to 2, where:
                              -2 = very negative,
                              -1 = somewhat negative,
                               0 = neutral,
                               1 = somewhat positive,
                               2 = very positive"),
    confidence = type_number("Confidence on a scale of 0 to 1.0")
  ),
  input_type = "text"
)

result <- annotate(
  as.character(tweetsample),
  task = sentiment_task,
  chat_fn = chat_openai,
  model = "gpt-4.1-mini",
  api_args = list(temperature = 0)
)

