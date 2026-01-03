# Compute robustness scale showing downstream analysis changes

Assesses how much downstream analysis results vary across different
coding runs. This helps determine whether substantive conclusions are
robust to different models, parameters, or codebook variations.

## Usage

``` r
qlm_trail_robustness(..., reference, analysis_fn)
```

## Arguments

- ...:

  One or more `qlm_coded` objects. The objects should be the actual
  coded results (not just the trail). Must include the reference run.

- reference:

  Character string naming the reference run to compare against. This
  should match the `name` attribute of one of the provided objects.

- analysis_fn:

  A function that takes a `qlm_coded` object and returns a named list or
  data frame of analysis results. The function will be applied to each
  coded object to compute downstream statistics.

## Value

A data frame with robustness metrics:

- run:

  Name of the run

- statistic:

  Name of the analysis statistic

- value:

  Value from this run

- reference_value:

  Value from reference run

- abs_diff:

  Absolute difference from reference

- pct_diff:

  Percent difference from reference (NULL if reference is 0)

## Details

Robustness is assessed by:

1.  Applying your analysis function to each coded object

2.  Comparing the resulting statistics to the reference run

3.  Computing absolute and percentage differences

Smaller differences indicate more robust findings that don't depend
heavily on model choice. Large differences suggest your conclusions may
be sensitive to which model or settings you use.

The `analysis_fn` should return a named list or data frame where each
element is a single numeric value representing a statistic of interest
(e.g., mean, proportion, correlation coefficient, regression
coefficient).

## See also

[`qlm_trail()`](https://seraphinem.github.io/quallmer/reference/qlm_trail.md),
[`qlm_compare()`](https://seraphinem.github.io/quallmer/reference/qlm_compare.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Create multiple coded versions
coded1 <- qlm_code(texts, codebook, model = "openai/gpt-4o",
                   name = "gpt4o_run")
coded2 <- qlm_replicate(coded1, model = "openai/gpt-4o-mini",
                        name = "mini_run")
coded3 <- qlm_replicate(coded1, temperature = 0.7,
                        name = "temp07_run")

# Define downstream analysis function
my_analysis <- function(coded) {
  list(
    mean_score = mean(coded$score, na.rm = TRUE),
    prop_positive = mean(coded$sentiment == "positive", na.rm = TRUE),
    sd_score = sd(coded$score, na.rm = TRUE)
  )
}

# Compute robustness
robustness <- qlm_trail_robustness(coded1, coded2, coded3,
                                   reference = "gpt4o_run",
                                   analysis_fn = my_analysis)
print(robustness)
} # }
```
