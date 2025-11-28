# Predefined task for ideological scaling on a specified dimension

Ideological scaling on a specified dimension, with justification.

## Usage

``` r
task_ideology(
  dimension = "the specified ideological dimension (0 = first pole, 10 = second pole)",
  definition = NULL
)
```

## Arguments

- dimension:

  A character string specifying the ideological dimension, ideally
  naming both poles, e.g., "liberal - illiberal", "left - right", or
  "inclusive - exclusive". The first pole corresponds to 0 and the
  second to 10.

- definition:

  Optional detailed explanation of what the dimension means. If
  provided, it will be included in the system prompt to guide
  annotation.

## Value

A task object
