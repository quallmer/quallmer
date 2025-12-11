# Apply an annotation task to input data

Applies an annotation task to input data, automatically detecting the
input type based on the task definition. Delegates processing to the
task's internal `run()` method.

## Usage

``` r
annotate(.data, task, ...)
```

## Arguments

- .data:

  Input data: a character vector of texts (for text tasks) or file paths
  to images (for image tasks). Named vectors will use names as
  identifiers in the output; unnamed vectors will use sequential
  integers.

- task:

  A task object created with
  [`task()`](https://seraphinem.github.io/quallmer/reference/task.md)

- ...:

  Additional arguments passed to the task's `run()` method:

  `chat_fn`

  :   Chat function to use (default:
      [`ellmer::chat_openai()`](https://ellmer.tidyverse.org/reference/chat_openai.html)).
      Other options include
      [`ellmer::chat_ollama()`](https://ellmer.tidyverse.org/reference/chat_ollama.html),
      [`ellmer::chat_google_gemini()`](https://ellmer.tidyverse.org/reference/chat_google_gemini.html),
      etc.

  `model`

  :   Model identifier string (default: `"gpt-4o"`).

  `verbose`

  :   Logical; whether to print progress messages (default: `TRUE`).

  Any additional arguments are passed to `chat_fn()`, such as
  `temperature`, `seed`, or other provider-specific options.

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
annotate(texts, task_sentiment())

# With named inputs (names become IDs in output)
texts <- c(doc1 = "Great service!", doc2 = "Very disappointing.")
annotate(texts, task_sentiment())

# Using a different model
annotate(texts, task_sentiment(), model = "gpt-4o-mini")

# Using Ollama locally
annotate(texts, task_sentiment(), chat_fn = ellmer::chat_ollama,
         model = "llama3.2")
} # }
```
