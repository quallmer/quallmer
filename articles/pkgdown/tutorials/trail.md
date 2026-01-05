# The quallmer trail

In this tutorial, we will explore the quallmer trail system, which
automatically captures provenance metadata for full workflow
traceability. The trail system helps you:

- Track the complete history of your coding workflow
- Document model parameters and settings used
- Assess robustness of downstream analyses
- Maintain parent-child relationships across coding runs
- Export provenance information for reproducibility
- Generate human-readable reports of your analysis pipeline

## Understanding provenance tracking

All `qlm_coded`, `qlm_comparison`, and `qlm_validation` objects in
quallmer automatically capture provenance metadata, including:

- **Run name**: A unique identifier for each coding run
- **Timestamp**: When the coding was executed
- **Model**: The LLM model and parameters used
- **Codebook**: The coding instructions applied
- **Parent runs**: Links to previous runs in a replication chain
- **Metadata**: Package versions, number of units coded, etc.

This metadata enables full workflow traceability.

## Loading packages and data

``` r
# We will use the quanteda package
# for loading a sample corpus of inaugural speeches
library(quanteda)
```

    ## Package version: 4.3.1
    ## Unicode version: 15.1
    ## ICU version: 74.2

    ## Parallel computing: disabled

    ## See https://quanteda.io for tutorials and examples.

``` r
library(quallmer)
```

    ## Loading required package: ellmer

``` r
# For educational purposes,
# we will use a subset of the inaugural speeches corpus
data_corpus_inaugural <- quanteda::data_corpus_inaugural[50:60]
```

## Creating a workflow with provenance tracking

Let’s build a coding workflow that demonstrates the trail system. We’ll
use sentiment analysis as our example.

### Initial coding run

``` r
# For this tutorial, we'll use the built-in sentiment codebook
# For real research, you would create a custom codebook tailored to your
# specific research question (see the "Creating codebooks" tutorial)

# Code with GPT-4o (note the 'name' parameter for tracking)
coded1 <- qlm_code(data_corpus_inaugural,
                   codebook = data_codebook_ideology,
                   model = "openai/gpt-4o",
                   params = params(temperature = 0),
                   name = "initial_gpt4o")
```

    ## [working] (0 + 0) -> 10 -> 1 | ■■■■                               9%

    ## [working] (0 + 0) -> 0 -> 11 | ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100%

``` r
# Each qlm_coded object has a 'run' attribute with metadata
attr(coded1, "run")$name
```

    ## [1] "initial_gpt4o"

``` r
attr(coded1, "run")$metadata$timestamp
```

    ## [1] "2026-01-05 12:10:24 UTC"

### Creating a replication chain

When you use
[`qlm_replicate()`](https://seraphinem.github.io/quallmer/reference/qlm_replicate.md),
the new run automatically links to its parent:

``` r
# Replicate with GPT-4o-mini
coded2 <- qlm_replicate(coded1,
                        model = "openai/gpt-4o-mini",
                        name = "replicate_mini")
```

    ## [working] (0 + 0) -> 10 -> 1 | ■■■■                               9%

    ## [working] (0 + 0) -> 1 -> 10 | ■■■■■■■■■■■■■■■■■■■■■■■■■■■■      91%

    ## [working] (0 + 0) -> 0 -> 11 | ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100%

``` r
# Check the parent relationship
attr(coded2, "run")$parent  # Shows "initial_gpt4o"
```

    ## [1] "initial_gpt4o"

``` r
# Replicate again with different temperature
coded3 <- qlm_replicate(coded2,
                        params = params(temperature = 0.7),
                        name = "mini_temp07")
```

    ## [working] (0 + 0) -> 10 -> 1 | ■■■■                               9%
    ## [working] (0 + 0) -> 0 -> 11 | ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100%

``` r
# This creates a chain: initial_gpt4o -> replicate_mini -> mini_temp07
attr(coded3, "run")$parent  # Shows "replicate_mini"
```

    ## [1] "replicate_mini"

## Extracting and displaying provenance trails

The
[`qlm_trail()`](https://seraphinem.github.io/quallmer/reference/qlm_trail.md)
function extracts and displays the complete provenance chain from your
quallmer objects.

### Viewing a single run

``` r
# Extract trail from a single object
trail1 <- qlm_trail(coded1)

# Print the trail
trail1
```

    ## # quallmer trail
    ## Run:     initial_gpt4o
    ## Created: 2026-01-05 12:10:24
    ## Model:   openai/gpt-4o

The trail displays:

- Run name and parent relationship
- Creation timestamp
- Model and parameters used

### Reconstructing a complete chain

To see the full provenance chain, provide all objects in the lineage:

``` r
# Provide all objects to reconstruct the complete chain
full_trail <- qlm_trail(coded3, coded2, coded1)

# Print shows the complete history
full_trail
```

    ## # quallmer trail (3 runs)
    ## 
    ## 1. initial_gpt4o (original)
    ##    2026-01-05 12:10 | openai/gpt-4o
    ##    Codebook: Ideological scaling
    ## 
    ## 2. replicate_mini (parent: initial_gpt4o)
    ##    2026-01-05 12:10 | openai/gpt-4o-mini
    ##    Codebook: Ideological scaling
    ## 
    ## 3. mini_temp07 (parent: replicate_mini)
    ##    2026-01-05 12:11 | openai/gpt-4o-mini
    ##    Codebook: Ideological scaling

The output shows:

- All runs in chronological order
- Parent-child relationships
- Model and parameter changes across runs
- Timestamps for each step
- Codebook used

## Assessing robustness of downstream analysis

The
[`qlm_trail_robustness()`](https://seraphinem.github.io/quallmer/reference/qlm_trail_robustness.md)
function helps you assess whether your **substantive findings** change
across different models or settings. Instead of just comparing raw coded
values (as qlm_compare() already does), it compares the results of your
downstream analysis (means, proportions, correlations, etc.).

### Defining your downstream analysis

First, define a function that performs your analysis on coded data:

``` r
# Define what analysis you want to compare
my_analysis <- function(coded) {
  list(
    mean_score = mean(coded$score, na.rm = TRUE),
    sd_score = sd(coded$score, na.rm = TRUE),
    n_units = sum(!is.na(coded$score))
  )
}
```

The analysis function should:

- Take a `qlm_coded` object as input
- Return a named list of numeric statistics
- Each statistic should be a single number (e.g., mean, proportion,
  correlation)

### Computing robustness

``` r
# Compute how much your analysis results differ across models
robustness <- qlm_trail_robustness(coded1, coded2, coded3,
                                   reference = "initial_gpt4o",
                                   analysis_fn = my_analysis)

# View the robustness scale
robustness
```

    ## # Downstream Analysis Robustness
    ## Reference run: initial_gpt4o
    ## 
    ##             run  statistic  value reference_value abs_diff pct_diff
    ##   initial_gpt4o mean_score  5.545           5.545  0.00000    0.000
    ##   initial_gpt4o   sd_score  2.162           2.162  0.00000    0.000
    ##   initial_gpt4o    n_units 11.000          11.000  0.00000    0.000
    ##  replicate_mini mean_score  5.455           5.545  0.09091   -1.639
    ##  replicate_mini   sd_score  2.067           2.162  0.09459   -4.376
    ##  replicate_mini    n_units 11.000          11.000  0.00000    0.000
    ##     mini_temp07 mean_score  5.364           5.545  0.18182   -3.279
    ##     mini_temp07   sd_score  2.203           2.162  0.04165    1.927
    ##     mini_temp07    n_units 11.000          11.000  0.00000    0.000
    ## 
    ## abs_diff: Absolute difference from reference
    ## pct_diff: Percent change from reference (positive = increase)
    ## 
    ## Smaller differences indicate more robust findings.

The output shows:

- **run**: Name of each run
- **statistic**: Which analysis statistic (e.g., mean_score)
- **value**: Value from this run
- **reference_value**: Value from the reference run
- **abs_diff**: Absolute difference from reference
- **pct_diff**: Percent change from reference

### Interpreting robustness

``` r
# Check which statistics have large differences (>5% change)
concerning <- robustness[abs(robustness$pct_diff) > 5 & !is.na(robustness$pct_diff), ]

# Check which are highly stable (<1% change)
stable <- robustness[abs(robustness$pct_diff) < 1 & !is.na(robustness$pct_diff), ]
```

**Interpretation guidelines:**

- **\<1% difference**: Highly robust, findings are very stable
- **1-5% difference**: Good robustness, minor variations
- **5-10% difference**: Moderate robustness, some sensitivity
- **\>10% difference**: Low robustness, conclusions may change

The acceptable threshold depends on your research context and the
magnitude of effects you’re studying.

## Integrating comparisons and validations

The trail system automatically tracks comparisons and validations as
part of your workflow.

### Complete workflow example

``` r
# 1. Code with two different models
coded_gpt4o <- qlm_code(data_corpus_inaugural,
                        codebook = data_codebook_ideology,
                        model = "openai/gpt-4o",
                        params = params(temperature = 0),
                        name = "gpt4o_run")
```

    ## [working] (0 + 0) -> 10 -> 1 | ■■■■                               9%

    ## [working] (0 + 0) -> 0 -> 11 | ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100%

``` r
coded_mini <- qlm_replicate(coded_gpt4o,
                            model = "openai/gpt-4o-mini",
                            name = "mini_run")
```

    ## [working] (0 + 0) -> 10 -> 1 | ■■■■                               9%

    ## [working] (0 + 0) -> 4 -> 7 | ■■■■■■■■■■■■■■■■■■■■              64%

    ## [working] (0 + 0) -> 0 -> 11 | ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100%

``` r
# 2. Compare inter-rater reliability
# Score is ordinal (0-10 scale), so use level = "ordinal"
comparison <- qlm_compare(coded_gpt4o, coded_mini,
                          by = score,
                          level = "ordinal")

# View the comparison results
print(comparison)
```

    ## # Inter-rater reliability
    ## # Subjects: 11 
    ## # Raters:   2 
    ## # Level:    ordinal 
    ## 
    ## Krippendorff's alpha: 0.9366
    ## Weighted kappa:       0.9521
    ## Kendall's W:          0.9364
    ## Spearman's rho:       0.9526
    ## Percent agreement:    0.6364

``` r
# 3. Validate against gold standard (if you have one)
# gold <- data.frame(.id = coded_gpt4o$.id, score = c(2, 3, 1, ...))
# validation <- qlm_validate(coded_gpt4o, gold = gold, by = score, level = "ordinal")
# print(validation)
```

### Viewing complete workflow trail

``` r
# Get full provenance trail including comparisons
full_trail <- qlm_trail(coded_gpt4o, coded_mini, comparison)
print(full_trail)
```

    ## # quallmer trail (3 runs)
    ## 
    ## 1. gpt4o_run (original)
    ##    2026-01-05 12:11 | openai/gpt-4o
    ##    Codebook: Ideological scaling
    ## 
    ## 2. mini_run (parent: gpt4o_run)
    ##    2026-01-05 12:11 | openai/gpt-4o-mini
    ##    Codebook: Ideological scaling
    ## 
    ## 3. comparison_2b5e12c6 (parents: gpt4o_run, mini_run)
    ##    2026-01-05 12:11 | unknown
    ##    Comparison: ordinal level | 11 subjects | 2 raters

The trail shows:

- Parent-child relationships between runs
- Comparison/validation summaries (level, subjects, raters, etc.)
- Complete lineage: gpt4o_run → mini_run → comparison

## Exporting and documenting your workflow

You can export your trail for documentation and reproducibility:

``` r
# Extract the full trail (metadata only - lightweight)
trail <- qlm_trail(coded_gpt4o, coded_mini, comparison)

# Save as RDS for archival
# qlm_trail_save(trail, "my_workflow_trail.rds")

# For complete archival with the actual coded data:
# trail_complete <- qlm_trail(coded_gpt4o, coded_mini, comparison, include_data = TRUE)
# qlm_trail_save(trail_complete, "my_workflow_complete.rds")

# Export as JSON for portability
# qlm_trail_export(trail, "my_workflow_trail.json")

# Generate a comprehensive report
# qlm_trail_report(trail, "my_workflow_report.qmd",
#                  include_comparisons = TRUE,
#                  include_validations = TRUE)
```

**When to include data:**

- Use `include_data = FALSE` (default) for lightweight documentation and
  lineage tracking
- Use `include_data = TRUE` to create a complete archive with all coded
  results for long-term storage or sharing

The generated report includes:

- **Timeline**: All coding runs with timestamps and model settings
- **Comparisons**: Inter-rater reliability measures (when
  `include_comparisons = TRUE`)
  - All relevant measures for the measurement level (alpha, kappa, ICC,
    etc.)
- **Validations**: Accuracy metrics against gold standards (when
  `include_validations = TRUE`)
  - Level-appropriate metrics (accuracy, precision, recall, kappa, rho,
    ICC, etc.)
- **System info**: Package versions and R version for reproducibility

## Summary

The quallmer trail system automatically tracks your coding workflow:

- **Provenance tracking**: All runs are timestamped with model and
  parameter information
- **Parent-child links**:
  [`qlm_replicate()`](https://seraphinem.github.io/quallmer/reference/qlm_replicate.md)
  maintains relationships between runs
- **Quality assessment**: Use
  [`qlm_compare()`](https://seraphinem.github.io/quallmer/reference/qlm_compare.md)
  to check agreement and
  [`qlm_trail_robustness()`](https://seraphinem.github.io/quallmer/reference/qlm_trail_robustness.md)
  to test if conclusions change
- **Documentation**: Export trails for methods sections and replication
  packages

**Best practices:**

1.  Name your runs with the `name` parameter
2.  Use
    [`qlm_compare()`](https://seraphinem.github.io/quallmer/reference/qlm_compare.md)
    to assess inter-rater reliability
3.  Use
    [`qlm_trail_robustness()`](https://seraphinem.github.io/quallmer/reference/qlm_trail_robustness.md)
    to check if your findings are stable across models
4.  Export trails for transparency and reproducibility
