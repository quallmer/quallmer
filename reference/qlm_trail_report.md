# Generate trail report

Generates a human-readable Quarto/RMarkdown document summarizing the
provenance trail, optionally including assessment metrics across runs.

## Usage

``` r
qlm_trail_report(
  trail,
  file,
  include_comparisons = FALSE,
  include_validations = FALSE,
  robustness = NULL
)
```

## Arguments

- trail:

  A `qlm_trail` object from
  [`qlm_trail()`](https://seraphinem.github.io/quallmer/reference/qlm_trail.md).

- file:

  Path to save the report file (`.qmd` or `.Rmd`).

- include_comparisons:

  Logical. If `TRUE`, include comparison metrics in the report (if any
  comparisons are in the trail). Default is `FALSE`.

- include_validations:

  Logical. If `TRUE`, include validation metrics in the report (if any
  validations are in the trail). Default is `FALSE`.

- robustness:

  Optional. A `qlm_robustness` object from
  [`qlm_trail_robustness()`](https://seraphinem.github.io/quallmer/reference/qlm_trail_robustness.md)
  containing downstream analysis robustness metrics to include in the
  report.

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

  - Downstream analysis robustness

The generated file can be rendered to HTML, PDF, or other formats using
Quarto or RMarkdown.

## See also

[`qlm_trail()`](https://seraphinem.github.io/quallmer/reference/qlm_trail.md),
[`qlm_trail_robustness()`](https://seraphinem.github.io/quallmer/reference/qlm_trail_robustness.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic trail report
trail <- qlm_trail(coded1, coded2, coded3)
qlm_trail_report(trail, "analysis_trail.qmd")

# Include comparison and validation metrics
trail <- qlm_trail(coded1, coded2, comparison, validation)
qlm_trail_report(trail, "full_report.qmd",
                 include_comparisons = TRUE,
                 include_validations = TRUE)

# Include robustness assessment
robustness <- qlm_trail_robustness(coded1, coded2, coded3,
                                   reference = "run1",
                                   analysis_fn = my_analysis)
qlm_trail_report(trail, "full_report.qmd", robustness = robustness)

# Render to HTML
quarto::quarto_render("full_report.qmd")
} # }
```
