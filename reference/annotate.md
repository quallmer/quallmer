# Apply an annotation task to input data

Applies an annotation task to input data using a large language model.
Arguments in `...` are dynamically routed to either
[`ellmer::chat()`](https://ellmer.tidyverse.org/reference/chat-any.html)
or to
[`ellmer::parallel_chat_structured()`](https://ellmer.tidyverse.org/reference/parallel_chat.html)
based on their names.

## Usage

``` r
annotate(.data, task, model_name, ...)
```

## Arguments

- .data:

  Input data: a character vector of texts (for text tasks) or file paths
  to images (for image tasks). Named vectors will use names as
  identifiers in the output; unnamed vectors will use sequential
  integers.

- task:

  A task object created with
  [`task()`](https://seraphinem.github.io/quallmer/reference/task.md) or
  one of the predefined task functions
  ([`task_sentiment()`](https://seraphinem.github.io/quallmer/reference/task_sentiment.md),
  [`task_stance()`](https://seraphinem.github.io/quallmer/reference/task_stance.md),
  [`task_ideology()`](https://seraphinem.github.io/quallmer/reference/task_ideology.md),
  [`task_salience()`](https://seraphinem.github.io/quallmer/reference/task_salience.md),
  [`task_fact()`](https://seraphinem.github.io/quallmer/reference/task_fact.md)).

- model_name:

  Provider (and optionally model) name in the form `"provider/model"` or
  `"provider"` (which will use the default model for that provider).
  Passed to the `name` argument of
  [`ellmer::chat()`](https://ellmer.tidyverse.org/reference/chat-any.html).
  Examples: `"openai/gpt-4o-mini"`,
  `"anthropic/claude-3-5-sonnet-20241022"`, `"ollama/llama3.2"`,
  `"openai"` (uses default OpenAI model).

- ...:

  Additional arguments passed to either
  [`ellmer::chat()`](https://ellmer.tidyverse.org/reference/chat-any.html)
  or to
  [`ellmer::parallel_chat_structured()`](https://ellmer.tidyverse.org/reference/parallel_chat.html),
  based on argument name. Arguments not recognized by either function
  will generate a warning.

## Value

A data frame with one row per input element, containing:

- `id`:

  Identifier for each input (from names or sequential integers).

- ...:

  Additional columns as defined by the task's `type_def`. For example,
  [`task_sentiment()`](https://seraphinem.github.io/quallmer/reference/task_sentiment.md)
  returns `score` and `explanation`;
  [`task_stance()`](https://seraphinem.github.io/quallmer/reference/task_stance.md)
  returns `stance` and `explanation`.

## Details

Progress indicators and error handling are provided by the underlying
[`ellmer::parallel_chat_structured()`](https://ellmer.tidyverse.org/reference/parallel_chat.html)
function. Set `verbose = TRUE` to see progress messages during batch
annotation. Retry logic for API failures should be configured through
ellmer's options.

## See also

[`task()`](https://seraphinem.github.io/quallmer/reference/task.md) for
creating custom tasks,
[`task_sentiment()`](https://seraphinem.github.io/quallmer/reference/task_sentiment.md),
[`task_stance()`](https://seraphinem.github.io/quallmer/reference/task_stance.md),
[`task_ideology()`](https://seraphinem.github.io/quallmer/reference/task_ideology.md),
[`task_salience()`](https://seraphinem.github.io/quallmer/reference/task_salience.md),
[`task_fact()`](https://seraphinem.github.io/quallmer/reference/task_fact.md)
for predefined tasks,
[`validate()`](https://seraphinem.github.io/quallmer/reference/validate.md)
for computing agreement metrics on annotations.

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic sentiment analysis
texts <- c("I love this product!", "This is terrible.")
annotate(texts, task_sentiment(), model_name = "openai")

# With named inputs (names become IDs in output)
texts <- c(doc1 = "Great service!", doc2 = "Very disappointing.")
annotate(texts, task_sentiment(), model_name = "openai")

# Specify provider and model
annotate(texts, task_sentiment(), model_name = "openai/gpt-4o-mini")

# With execution control
annotate(texts, task_sentiment(),
         model_name = "openai/gpt-4o-mini",
         max_active = 5)

# Include token usage
annotate(texts, task_sentiment(), model_name = "openai", include_tokens = TRUE)

# Using Ollama locally
annotate(texts, task_sentiment(), model_name = "ollama/llama3.2")

# Using Anthropic
annotate(texts, task_sentiment(),
         model_name = "anthropic/claude-3-5-sonnet-20241022")
} # }
```
