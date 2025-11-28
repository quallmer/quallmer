# Apply an annotation task to input data

Automatically detects the correct task type (e.g., text, image).
Delegates the actual processing to the task's internal run() method.

## Usage

``` r
annotate(.data, task, ...)
```

## Arguments

- .data:

  Input data (text, image, etc.)

- task:

  A task created with \[task()\]

- ...:

  Additional arguments passed to task\$run()

## Value

Structured data frame with results
