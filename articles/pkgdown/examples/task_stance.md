# Example: Stance detection

The
[`annotate()`](https://seraphinem.github.io/quallmer/reference/annotate.md)
function with a predefined
[`task_stance()`](https://seraphinem.github.io/quallmer/reference/task_stance.md)
task allows you to perform stance detection on texts regarding a
specific topic. This position taking analysis classifies texts as Pro,
Neutral, or Contra towards the given topic, along with a brief
explanation. In this example, we will analyze a set of inaugural
speeches to determine their stance on “Climate Change”.

### Loading packages and data

``` r
# We will use the quanteda package 
# for loading a sample corpus of innaugural speeches
# If you have not yet installed the quanteda package, you can do so by:
# install.packages("quanteda")
library(quanteda)
```

    ## Package version: 4.3.1
    ## Unicode version: 15.1
    ## ICU version: 74.2

    ## Parallel computing: disabled

    ## See https://quanteda.io for tutorials and examples.

``` r
library(quallmer)
```

    ## Loading required package: ellmer

``` r
# For educational purposes, 
# we will use a subset of the inaugural speeches corpus
# The three most recent speeches in the corpus
data_corpus_inaugural <- quanteda::data_corpus_inaugural[57:60]
```

### Using `annotate()` for stance detection of texts

``` r
# Define topic of interest
topic <- "Climate Change"
# Apply predefined stance task with task_stance() in the annotate() function
result <- annotate(data_corpus_inaugural, task = task_stance(topic), 
                   chat_fn = chat_openai, model = "gpt-4o",
                   api_args = list(temperature = 0, seed = 42))
```

    ## Running task 'Stance detection' using model: gpt-4o

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

| id         | stance | explanation |
|:-----------|:-------|:------------|
| 2013-Obama | NA     | NA          |
| 2017-Trump | NA     | NA          |
| 2021-Biden | NA     | NA          |
| 2025-Trump | NA     | NA          |

### Adjusting the stance detection task

You can customize the stance detection task by defining your own task
with [`task()`](https://seraphinem.github.io/quallmer/reference/task.md)
(for a more detailed explanation, [see our “Defining custom tasks”
tutorial](https://seraphinem.github.io/quallmer/articles/pkgdown/tutorials/customtask.html)).
For example, you might want to include an additional field for
confidence level.

``` r
custom_stance <- task(
  name = "Custom stance detection",
  system_prompt = paste0(
    "You are an expert annotator. Read each short text carefully and determine its stance towards ",
    topic,
    ". Classify the stance as Pro, Neutral, or Contra, provide a brief explanation for your classification, and indicate your confidence level from 0 to 1."
  ),
  type_def = ellmer::type_object(
    stance = ellmer::type_string("Stance towards the topic: Pro, Neutral, or Contra"),
    explanation = ellmer::type_string("Brief explanation of the classification"),
    confidence = ellmer::type_number("Confidence level from 0 to 1")
  ),
  input_type = "text"
)
# Apply the custom stance task
custom_result <- annotate(data_corpus_inaugural, task = custom_stance, 
                          chat_fn = chat_openai, model = "gpt-4o",
                          api_args = list(temperature = 0, seed = 42))
```

    ## Running task 'Custom stance detection' using model: gpt-4o

    ## Warning: 4 requests errored.

| id         | stance | explanation | confidence |
|:-----------|:-------|:------------|-----------:|
| 2013-Obama | NA     | NA          |         NA |
| 2017-Trump | NA     | NA          |         NA |
| 2021-Biden | NA     | NA          |         NA |
| 2025-Trump | NA     | NA          |         NA |

Or, you might want the LLM to extract specific arguments supporting the
stance.

``` r
argument_stance <- task(
  name = "Argument-based stance detection",
  system_prompt = paste0(
    "You are an expert annotator. Read each short text carefully and determine its stance towards ",
    topic,
    ". Classify the stance as Pro, Neutral, or Contra, provide a brief explanation for your classification, and list up to three key arguments supporting the stance."
  ),
  type_def = ellmer::type_object(
    stance = ellmer::type_string("Stance towards the topic: Pro, Neutral, or Contra"),
    explanation = ellmer::type_string("Brief explanation of the classification"),
    arguments = ellmer::type_string("Key arguments supporting the stance")
  ),
  input_type = "text"
)
# Apply the argument-based stance task
argument_result <- annotate(data_corpus_inaugural, task = argument_stance, 
                            chat_fn = chat_openai, model = "gpt-4o",
                            api_args = list(temperature = 0, seed = 42))
```

    ## Running task 'Argument-based stance detection' using model: gpt-4o

    ## Warning: 4 requests errored.

| id         | stance | explanation | arguments |
|:-----------|:-------|:------------|:----------|
| 2013-Obama | NA     | NA          | NA        |
| 2017-Trump | NA     | NA          | NA        |
| 2021-Biden | NA     | NA          | NA        |
| 2025-Trump | NA     | NA          | NA        |

In this example, we demonstrated how to use the `stance()` task for
stance detection on texts regarding “Climate Change”. We also showed how
to customize the task to include additional fields such as confidence
level and key arguments supporting the stance. Now it is your turn to
explore stance detection with your own texts and topics of interest!
