# Define an annotation task

Creates a task definition for use with
[`annotate()`](https://seraphinem.github.io/quallmer/reference/annotate.md).
A task specifies what information to extract from input data, including
the system prompt that guides the LLM and the structured output
definition.

## Usage

``` r
task(name, system_prompt, type_def, input_type = c("text", "image"))
```

## Arguments

- name:

  Name of the task (character).

- system_prompt:

  System prompt to guide the model.

- type_def:

  Structured output definition, e.g., created by
  [`ellmer::type_object()`](https://ellmer.tidyverse.org/reference/type_boolean.html),
  [`ellmer::type_array()`](https://ellmer.tidyverse.org/reference/type_boolean.html),
  or
  [`ellmer::type_enum()`](https://ellmer.tidyverse.org/reference/type_boolean.html).

- input_type:

  Type of input data: `"text"` or `"image"`.

## Value

A task object (a list with class `"task"`) containing the task

definition. Use with
[`annotate()`](https://seraphinem.github.io/quallmer/reference/annotate.md)
to apply the task to data.

## See also

[`annotate()`](https://seraphinem.github.io/quallmer/reference/annotate.md)
for applying tasks to data,
[`task_sentiment()`](https://seraphinem.github.io/quallmer/reference/task_sentiment.md),
[`task_stance()`](https://seraphinem.github.io/quallmer/reference/task_stance.md),
[`task_ideology()`](https://seraphinem.github.io/quallmer/reference/task_ideology.md),
[`task_salience()`](https://seraphinem.github.io/quallmer/reference/task_salience.md),
[`task_fact()`](https://seraphinem.github.io/quallmer/reference/task_fact.md)
for predefined tasks.

## Examples

``` r
if (FALSE) { # \dontrun{
# Define a custom task
my_task <- task(
  name = "Sentiment",
  system_prompt = "Rate the sentiment from -1 (negative) to 1 (positive).",
  type_def = ellmer::type_object(
    score = ellmer::type_number("Sentiment score from -1 to 1"),
    explanation = ellmer::type_string("Brief explanation")
  )
)

# Use with annotate()
texts <- c("I love this!", "This is terrible.")
annotate(texts, my_task, model_name = "openai/gpt-4o-mini")
} # }
```
