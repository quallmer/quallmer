# Launch the Validate App

Starts the Shiny app for manual coding, LLM checking, and validation /
agreement calculation.

## Usage

``` r
validate_app(base_dir = getwd())
```

## Arguments

- base_dir:

  Base directory for saving uploaded files and progress. Defaults to
  current working directory. Use
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html) for temporary
  storage (e.g., in examples or tests), but note that data will be lost
  when the R session ends.

## Value

A shiny.appobj

## Details

- In LLM mode, you can also select metadata columns.

- In Validation mode, select unit ID and coder columns (no text column),
  and optionally specify a gold-standard coder.
