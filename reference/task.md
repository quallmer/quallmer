# Define an annotation task (deprecated)

**\[deprecated\]**

## Usage

``` r
task(name, system_prompt, type_def, input_type = c("text", "image"))
```

## Arguments

- name:

  Name of the codebook (character).

- input_type:

  Type of input data: `"text"` (default) or `"image"`.

## Value

A task object (a list with class `"task"`) containing the task
definition.

## Details

`task()` has been deprecated in favor of
[`qlm_codebook()`](https://quallmer.github.io/quallmer/reference/qlm_codebook.md).
The new function returns an object with dual class inheritance that
works with both the old and new APIs.

## See also

[`qlm_codebook()`](https://quallmer.github.io/quallmer/reference/qlm_codebook.md)
for the replacement function.

## Examples

``` r
if (FALSE) { # \dontrun{
# Deprecated usage
my_task <- task(
  name = "Sentiment",
  system_prompt = "Rate the sentiment from -1 (negative) to 1 (positive).",
  type_def = type_object(
    score = type_number("Sentiment score from -1 to 1"),
    explanation = type_string("Brief explanation")
  )
)

# New recommended usage
my_codebook <- qlm_codebook(
  name = "Sentiment",
  instructions = "Rate the sentiment from -1 (negative) to 1 (positive).",
  schema = type_object(
    score = type_number("Sentiment score from -1 to 1"),
    explanation = type_string("Brief explanation")
  )
)
} # }
```
