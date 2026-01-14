# Generate trail report

Generates a human-readable Quarto/RMarkdown document summarizing the
audit trail, optionally including assessment metrics across runs.

## Usage

``` r
qlm_trail_report(
  trail,
  file,
  include_comparisons = FALSE,
  include_validations = FALSE
)
```

## Arguments

- trail:

  A `qlm_trail` object from
  [`qlm_trail()`](https://quallmer.github.io/quallmer/reference/qlm_trail.md).

- file:

  Path to save the report file (`.qmd` or `.Rmd`).

- include_comparisons:

  Logical. If `TRUE`, include comparison metrics in the report (if any
  comparisons are in the trail). Default is `FALSE`.

- include_validations:

  Logical. If `TRUE`, include validation metrics in the report (if any
  validations are in the trail). Default is `FALSE`.

## Value

Invisibly returns the file path.

## Details

Creates a formatted document showing:

- Trail summary and completeness

- Timeline of runs

- Model parameters and settings for each run

- Parent-child relationships

- Assessment metrics (if requested):

  - Inter-rater reliability comparisons

  - Validation results against gold standards

The generated file can be rendered to HTML, PDF, or other formats using
Quarto or RMarkdown.

## See also

[`qlm_trail()`](https://quallmer.github.io/quallmer/reference/qlm_trail.md),
[`qlm_archive()`](https://quallmer.github.io/quallmer/reference/qlm_archive.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Code movie reviews and create replication
coded1 <- qlm_code(data_corpus_LMRDsample, data_codebook_sentiment,
                   model = "openai/gpt-4o", name = "gpt4o_run")
coded2 <- qlm_replicate(coded1, model = "openai/gpt-4o-mini", name = "mini_run")

# Generate basic trail report
trail <- qlm_trail(coded1, coded2)
qlm_trail_report(trail, "analysis_trail.qmd")

# Include comparison metrics
comparison <- qlm_compare(coded1, coded2, by = sentiment, level = "nominal")
trail <- qlm_trail(coded1, coded2, comparison)
qlm_trail_report(trail, "full_report.qmd", include_comparisons = TRUE)

# Render to HTML
quarto::quarto_render("full_report.qmd")
} # }
```
