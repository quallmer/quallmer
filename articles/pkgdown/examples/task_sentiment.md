# Example: Sentiment analysis

The
[`annotate()`](https://seraphinem.github.io/quallmer/reference/annotate.md)
function with a predefined `sentiment()` task allows you to rate the
sentiment of texts using an LLM. The predefined `sentiment()` object
structures the response with a numeric sentiment score from -1 (very
negative) to 1 (very positive) and a brief explanation.

### Loading packages and data

``` r
library(quallmer)
```

    ## Loading required package: ellmer

``` r
#Example texts
texts <- c(
"This is wonderful!",
"I really dislike this approach.",
"The results are somewhat disappointing.",
"Absolutely fantastic work!"
)
```

### Using `annotate()` for predefined sentiment analysis of texts

``` r
# Apply predefined sentiment task with task_sentiment() in the annotate() function
result <- annotate(texts, task = task_sentiment(), 
                   chat_fn = chat_openai, model = "gpt-4o",
                   api_args = list(temperature = 0, seed = 42))
```

    ## Running task 'Sentiment analysis' using model: gpt-4o

    ## Warning: 4 requests errored.

    ## 
    ## Attaching package: 'dplyr'

    ## The following object is masked from 'package:kableExtra':
    ## 
    ##     group_rows

    ## The following objects are masked from 'package:stats':
    ## 
    ##     filter, lag

    ## The following objects are masked from 'package:base':
    ## 
    ##     intersect, setdiff, setequal, union

|  id | score | explanation |
|----:|------:|:------------|
|   1 |    NA | NA          |
|   2 |    NA | NA          |
|   3 |    NA | NA          |
|   4 |    NA | NA          |

### Adjusting the sentiment task

You can customize the sentiment analysis task by defining your own task
with [`task()`](https://seraphinem.github.io/quallmer/reference/task.md)
(for a more detailed explanation, [see our “Defining custom tasks”
tutorial](https://seraphinem.github.io/quallmer/articles/pkgdown/tutorials/customtask.html)).

For example, you might want to include an additional field for
confidence level.

``` r
custom_sentiment <- task(
  name = "Custom sentiment analysis",
  system_prompt = "You are an expert annotator. Rate the sentiment of each text from -1 (very negative) to 1 (very positive), briefly explain why, and provide a confidence level from 0 to 1.",
  type_def = ellmer::type_object(
    score = ellmer::type_number("Sentiment score between -1 (very negative) and 1 (very positive)"),
    explanation = ellmer::type_string("Brief explanation of the rating"),
    confidence = ellmer::type_number("Confidence level from 0 to 1")
  ),
  input_type = "text"
)
# Apply the custom sentiment task
custom_result <- annotate(texts, task = custom_sentiment, 
                          chat_fn = chat_openai, model = "gpt-4o",
                          api_args = list(temperature = 0, seed = 42))
```

    ## Running task 'Custom sentiment analysis' using model: gpt-4o

    ## Warning: 4 requests errored.

|  id | score | explanation | confidence |
|----:|------:|:------------|-----------:|
|   1 |    NA | NA          |         NA |
|   2 |    NA | NA          |         NA |
|   3 |    NA | NA          |         NA |
|   4 |    NA | NA          |         NA |

Or, you might want to change the scoring scale to a 5-point Likert
scale.

``` r
likert_sentiment <- task(
  name = "Likert scale sentiment analysis",
  system_prompt = "You are an expert annotator. Rate the sentiment of each text on a scale from 1 (very negative) to 5 (very positive) and briefly explain why.",
  type_def = ellmer::type_object(
    score = ellmer::type_number("Sentiment score between 1 (very negative) and 5 (very positive)"),
    explanation = ellmer::type_string("Brief explanation of the rating")
  ),
  input_type = "text"
)
# Apply the Likert scale sentiment task
likert_result <- annotate(texts, task = likert_sentiment, 
                          chat_fn = chat_openai, model = "gpt-4o",
                          api_args = list(temperature = 0, seed = 42))
```

    ## Running task 'Likert scale sentiment analysis' using model: gpt-4o

    ## Warning: 4 requests errored.

|  id | score | explanation |
|----:|------:|:------------|
|   1 |    NA | NA          |
|   2 |    NA | NA          |
|   3 |    NA | NA          |
|   4 |    NA | NA          |

In this way, you can easily adapt the sentiment analysis task to fit
your specific research needs!
