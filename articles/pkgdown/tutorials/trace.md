# The quallmer audit trail

The quallmer trail system creates complete audit trails following
Lincoln and Guba’s (1985) concept for establishing trustworthiness in
qualitative research. It automatically captures the full decision
history of your coding workflow, including model parameters, timestamps,
parent-child relationships, and all coded results. This supports the
confirmability and dependability criteria, allowing others to trace the
logic of your analytical decisions and verify the consistency of your
coding process.

## Why use the quallmer trail?

The quallmer trail helps you:

- Document your complete analysis workflow for transparency
- Track which models and settings were used at each step
- Share reproducible workflows with collaborators
- Establish trustworthiness through a complete audit trail

## Basic example

``` r
library(quallmer)

# Initial coding run
coded1 <- qlm_code(
  data_corpus_LMRDsample,
  data_codebook_sentiment,
  model = "openai/gpt-4o",
  name = "gpt4o_run"
)

# Replicate with different model (automatically tracks parent)
coded2 <- qlm_replicate(
  coded1,
  model = "openai/gpt-4o-mini",
  name = "mini_run"
)

# Extract and view the complete audit trail
trail <- qlm_trail(coded1, coded2)
print(trail)
```

The trail shows the complete lineage: which models were used, when they
ran, how they relate to each other, and the actual coded results.

## Using helper functions

You can use individual helper functions for more control over each
output:

``` r
# Extract the trail
trail <- qlm_trail(coded1, coded2)

# Save to RDS (complete archive with all data)
qlm_trail_save(trail, "workflow.rds")

# Export to JSON (portable metadata)
qlm_trail_export(trail, "workflow.json")

# Generate Quarto report
qlm_trail_report(trail, "workflow.qmd")
```

## One-call documentation with qlm_archive()

For convenience, use
[`qlm_archive()`](https://quallmer.github.io/quallmer/reference/qlm_archive.md)
to create all outputs in one call:

``` r
# Document entire workflow in one call
qlm_archive(coded1, coded2, path = "workflow")
```

This creates:

- **workflow.rds**: Complete trail object with all coded data
  (reloadable with [`readRDS()`](https://rdrr.io/r/base/readRDS.html))
- **workflow.json**: Portable metadata for archival
- **workflow.qmd**: Human-readable report you can render to HTML/PDF

You can also pipe a trail into
[`qlm_archive()`](https://quallmer.github.io/quallmer/reference/qlm_archive.md):

``` r
qlm_trail(coded1, coded2) |>
  qlm_archive(path = "workflow")
```

## Including comparison and validation results

If you’ve compared or validated your coding, include those objects to
capture the full workflow:

``` r
# Compare two coding runs
comparison <- qlm_compare(coded1, coded2, by = sentiment, level = "nominal")

# Include comparison in trail
trail <- qlm_trail(coded1, coded2, comparison)

# Generate report with comparison metrics
qlm_trail_report(trail, "full_workflow.qmd", include_comparisons = TRUE)
```

The report will include inter-rater reliability metrics alongside the
workflow timeline.

## Summary

The trail system provides workflow traceability following Lincoln and
Guba’s (1985) audit trail concept:

1.  **Automatic tracking**: Every
    [`qlm_code()`](https://quallmer.github.io/quallmer/reference/qlm_code.md)
    and
    [`qlm_replicate()`](https://quallmer.github.io/quallmer/reference/qlm_replicate.md)
    captures the full decision history
2.  **Simple extraction**:
    [`qlm_trail()`](https://quallmer.github.io/quallmer/reference/qlm_trail.md)
    reconstructs your complete audit trail with all coded data
3.  **Helper functions**:
    [`qlm_trail_save()`](https://quallmer.github.io/quallmer/reference/qlm_trail_save.md),
    [`qlm_trail_export()`](https://quallmer.github.io/quallmer/reference/qlm_trail_export.md),
    [`qlm_trail_report()`](https://quallmer.github.io/quallmer/reference/qlm_trail_report.md)
    for individual outputs
4.  **One-call documentation**:
    [`qlm_archive()`](https://quallmer.github.io/quallmer/reference/qlm_archive.md)
    for instant complete documentation

Always name your runs with the `name` parameter to make trails easier to
interpret.

## Reference

Lincoln, Y. S., & Guba, E. G. (1985). *Naturalistic Inquiry*. Sage.
