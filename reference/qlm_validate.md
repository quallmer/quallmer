# Validate coded results against a gold standard

Validates LLM-coded results from a `qlm_coded` object against a gold
standard (typically human annotations) using appropriate metrics based
on measurement level. For nominal data, computes accuracy, precision,
recall, F1-score, and Cohen's kappa. For ordinal data, computes accuracy
and weighted kappa (linear weighting), which accounts for the ordering
and distance between categories.

## Usage

``` r
qlm_validate(
  x,
  gold,
  by,
  level = c("nominal", "ordinal", "interval"),
  average = c("macro", "micro", "weighted", "none")
)
```

## Arguments

- x:

  A data frame, `qlm_coded`, or `qlm_humancoded` object containing
  predictions to validate. Must include a `.id` column and the variable
  specified in `by`. Plain data frames are automatically converted to
  `qlm_humancoded` objects.

- gold:

  A data frame, `qlm_coded`, or `qlm_humancoded` object containing gold
  standard annotations. Must include a `.id` column for joining with `x`
  and the variable specified in `by`. Plain data frames are
  automatically converted to `qlm_humancoded` objects.

- by:

  Name of the variable to validate (supports both quoted and unquoted).
  Must be present in both `x` and `gold`. Can be specified as
  `by = sentiment` or `by = "sentiment"`.

- level:

  Character scalar. Measurement level of the variable: `"nominal"`,
  `"ordinal"`, or `"interval"`. Default is `"nominal"`. Determines which
  validation metrics are computed.

- average:

  Character scalar. Averaging method for multiclass metrics (nominal
  level only):

  `"macro"`

  :   Unweighted mean across classes (default)

  `"micro"`

  :   Aggregate contributions globally (sum TP, FP, FN)

  `"weighted"`

  :   Weighted mean by class prevalence

  `"none"`

  :   Return per-class metrics in addition to global metrics

## Value

A `qlm_validation` object containing:

- `accuracy`:

  Overall accuracy (nominal only)

- `precision`:

  Precision (nominal only)

- `recall`:

  Recall (nominal only)

- `f1`:

  F1-score (nominal only)

- `kappa`:

  Cohen's kappa (nominal only)

- `rho`:

  Spearman's rho rank correlation (ordinal only)

- `tau`:

  Kendall's tau rank correlation (ordinal only)

- `r`:

  Pearson's r correlation (interval only)

- `icc`:

  Intraclass correlation coefficient (interval only)

- `mae`:

  Mean absolute error (ordinal/interval)

- `rmse`:

  Root mean squared error (interval only)

- `by_class`:

  Per-class metrics (nominal with `average = "none"` only)

- `confusion`:

  Confusion matrix (nominal only)

- `n`:

  Number of units compared

- `classes`:

  Class/level labels

- `average`:

  Averaging method used

- `level`:

  Measurement level

- `variable`:

  Variable name validated

- `call`:

  Function call

## Details

The function performs an inner join between `x` and `gold` using the
`.id` column, so only units present in both datasets are included in
validation. Missing values (NA) in either predictions or gold standard
are excluded with a warning.

**Measurement levels:**

- **Nominal**: Categories with no inherent ordering (e.g., topics,
  sentiment polarity). Metrics: accuracy, precision, recall, F1-score,
  Cohen's kappa (unweighted).

- **Ordinal**: Categories with meaningful ordering but unequal intervals
  (e.g., ratings 1-5, Likert scales). Metrics: Spearman's rho (`rho`,
  rank correlation), Kendall's tau (`tau`, rank correlation), and MAE
  (`mae`, mean absolute error). These measures account for the ordering
  of categories without assuming equal intervals.

- **Interval/Ratio**: Numeric data with equal intervals (e.g., counts,
  continuous measurements). Metrics: ICC (intraclass correlation),
  Pearson's r (linear correlation), MAE (mean absolute error), and RMSE
  (root mean squared error).

For multiclass problems with nominal data, the `average` parameter
controls how per-class metrics are aggregated:

- **Macro averaging** computes metrics for each class independently and
  takes the unweighted mean. This treats all classes equally regardless
  of size.

- **Micro averaging** aggregates all true positives, false positives,
  and false negatives globally before computing metrics. This weights
  classes by their prevalence.

- **Weighted averaging** computes metrics for each class and takes the
  mean weighted by class size.

- **No averaging** (`average = "none"`) returns global macro-averaged
  metrics plus per-class breakdown.

Note: The `average` parameter only affects precision, recall, and F1 for
nominal data. For ordinal data, these metrics are not computed.

## See also

[`qlm_compare()`](https://seraphinem.github.io/quallmer/reference/qlm_compare.md)
for inter-rater reliability between coded objects,
[`qlm_code()`](https://seraphinem.github.io/quallmer/reference/qlm_code.md)
for LLM coding,
[`qlm_humancoded()`](https://seraphinem.github.io/quallmer/reference/qlm_humancoded.md)
for human coding,
[`yardstick::accuracy()`](https://yardstick.tidymodels.org/reference/accuracy.html),
[`yardstick::precision()`](https://yardstick.tidymodels.org/reference/precision.html),
[`yardstick::recall()`](https://yardstick.tidymodels.org/reference/recall.html),
[`yardstick::f_meas()`](https://yardstick.tidymodels.org/reference/f_meas.html),
[`yardstick::kap()`](https://yardstick.tidymodels.org/reference/kap.html),
[`yardstick::conf_mat()`](https://yardstick.tidymodels.org/reference/conf_mat.html)

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic validation against gold standard

set.seed(24)
reviews <- data_corpus_LMRDsample[sample(length(data_corpus_LMRDsample), size = 20)]

# Code movie reviews
coded <- qlm_code(
  reviews,
  data_codebook_sentiment,
  model = "openai/gpt-4o"
)

# Create gold standard from corpus metadata
gold <- data.frame(
  .id = coded$.id,
  sentiment = quanteda::docvars(reviews, "polarity"),
  rating = quanteda::docvars(reviews, "rating")
)

# Validate polarity (nominal data) - supports unquoted variable names
validation <- qlm_validate(coded, gold, by = sentiment, level = "nominal")
print(validation)

# Can also use quoted names
validation <- qlm_validate(coded, gold, by = "sentiment", level = "nominal")

# Validate ratings (ordinal data)
validation_ordinal <- qlm_validate(coded, gold_ratings, by = rating, level = "ordinal")
print(validation_ordinal)

# Use micro-averaging (nominal level only)
qlm_validate(coded, gold, by = sentiment, level = "nominal", average = "micro")

# Get per-class breakdown (for nominal data only)
validation_detailed <- qlm_validate(coded, gold, by = sentiment,
                                    level = "nominal", average = "none")
print(validation_detailed)
validation_detailed$by_class
validation_detailed$confusion
} # }
```
