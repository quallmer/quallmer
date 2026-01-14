# Extract audit trail from quallmer objects

Creates a complete audit trail documenting your qualitative coding
workflow. Following Lincoln and Guba's (1985) concept of the audit trail
for establishing trustworthiness in qualitative research, this function
captures the full decision history of your AI-assisted coding process.

## Usage

``` r
qlm_trail(...)
```

## Arguments

- ...:

  One or more quallmer objects (`qlm_coded`, `qlm_comparison`, or
  `qlm_validation`). When multiple objects are provided, they will be
  used to reconstruct the complete workflow chain.

## Value

A `qlm_trail` object containing:

- runs:

  List of run information with coded data, ordered from oldest to newest

- complete:

  Logical indicating whether all parent references were resolved

## Details

The audit trail captures the complete history of your coding workflow:

- Run names and parent-child relationships

- Models and parameters used at each step

- Timestamps documenting when each step occurred

- The actual coded results from each run

- Comparison and validation metrics (when applicable)

This supports the confirmability and dependability criteria described by
Lincoln and Guba, allowing others to trace the logic of your analytical
decisions and verify the consistency of your coding process.

When a single object is provided, only its immediate information is
shown. To see the full chain, provide all ancestor objects.

For branching workflows (e.g., when multiple coded objects are
compared), the trail captures all input runs as parents of the
comparison.

## References

Lincoln, Y. S., & Guba, E. G. (1985). *Naturalistic Inquiry*. Sage.

## See also

[`qlm_replicate()`](https://quallmer.github.io/quallmer/reference/qlm_replicate.md),
[`qlm_code()`](https://quallmer.github.io/quallmer/reference/qlm_code.md),
[`qlm_compare()`](https://quallmer.github.io/quallmer/reference/qlm_compare.md),
[`qlm_validate()`](https://quallmer.github.io/quallmer/reference/qlm_validate.md),
[`qlm_trail_save()`](https://quallmer.github.io/quallmer/reference/qlm_trail_save.md),
[`qlm_trail_export()`](https://quallmer.github.io/quallmer/reference/qlm_trail_export.md),
[`qlm_trail_report()`](https://quallmer.github.io/quallmer/reference/qlm_trail_report.md),
[`qlm_archive()`](https://quallmer.github.io/quallmer/reference/qlm_archive.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Code movie reviews with sentiment codebook

library(quanteda)

test_corpus <- data_corpus_LMRDsample %>%
  corpus_sample(size = 10, by = polarity)

coded1 <- qlm_code(
  test_corpus,
  data_codebook_sentiment,
  model = "openai/gpt-4o",
  name = "gpt4o_run"
)

# Replicate with different model
coded2 <- qlm_replicate(coded1, model = "openai/gpt-4o-mini", name = "mini_run")

# Extract and view the audit trail
trail <- qlm_trail(coded1, coded2)
print(trail)

# Use helper functions for saving/exporting
qlm_trail_save(trail, "trail.rds")
qlm_trail_export(trail, "trail.json")
qlm_trail_report(trail, "trail.qmd")

# Or use qlm_archive() for one-call documentation
qlm_archive(coded1, coded2, path = "workflow")
} # }
```
