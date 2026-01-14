# Apply an annotation task to input data (deprecated)

**\[deprecated\]**

## Usage

``` r
annotate(.data, task, model_name, ...)
```

## Arguments

- task:

  A task object created with
  [`task()`](https://quallmer.github.io/quallmer/reference/task.md) or
  [`qlm_codebook()`](https://quallmer.github.io/quallmer/reference/qlm_codebook.md).

- ...:

  Additional arguments passed to
  [`ellmer::chat()`](https://ellmer.tidyverse.org/reference/chat-any.html),
  [`ellmer::parallel_chat_structured()`](https://ellmer.tidyverse.org/reference/parallel_chat.html),
  or
  [`ellmer::batch_chat_structured()`](https://ellmer.tidyverse.org/reference/batch_chat.html),
  based on argument name. Arguments recognized by
  [`ellmer::parallel_chat_structured()`](https://ellmer.tidyverse.org/reference/parallel_chat.html)
  take priority when there are overlaps. Batch-specific arguments
  (`path`, `wait`, `ignore_hash`) are only used when `batch = TRUE`.
  Arguments not recognized by any function will generate a warning.

## Value

A data frame with one row per input element, containing:

- `id`:

  Identifier for each input (from names or sequential integers).

- ...:

  Additional columns as defined by the task's schema.

## Details

`annotate()` has been deprecated in favor of
[`qlm_code()`](https://quallmer.github.io/quallmer/reference/qlm_code.md).
The new function returns a richer object that includes metadata and
settings for reproducibility.

## See also

[`qlm_code()`](https://quallmer.github.io/quallmer/reference/qlm_code.md)
for the replacement function.

## Examples

``` r
if (FALSE) { # \dontrun{
# Deprecated usage
texts <- c("I love this product!", "This is terrible.")
annotate(texts, task_sentiment(), model_name = "openai")

# New recommended usage
coded <- qlm_code(texts, task_sentiment(), model = "openai")
coded  # Print as tibble
} # }
```
