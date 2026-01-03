# Compare coded results for inter-rater reliability

Compares two or more `qlm_coded` objects to assess inter-rater
reliability or agreement. This function extracts a specified variable
from each coded result and computes reliability statistics using the irr
package.

## Usage

``` r
qlm_compare(
  ...,
  by,
  level = c("nominal", "ordinal", "interval", "ratio"),
  tolerance = 0
)
```

## Arguments

- ...:

  Two or more `qlm_coded` objects to compare. These represent different
  "raters" (e.g., different LLM runs, different models, or human vs. LLM
  coding). Objects should have the same units (matching `.id` values).

- by:

  Character scalar. Name of the variable to compare across raters. Must
  be present in all `qlm_coded` objects.

- level:

  Character scalar. Measurement level of the variable: `"nominal"`,
  `"ordinal"`, `"interval"`, or `"ratio"`. Default is `"nominal"`.
  Different sets of agreement statistics are computed for each level.

- tolerance:

  Numeric. Tolerance for agreement with numeric data. Default is 0
  (exact agreement required). Used for percent agreement calculation.

## Value

A `qlm_comparison` object containing agreement statistics appropriate
for the measurement level:

- **Nominal level:**:

  - `alpha_nominal`: Krippendorff's alpha

  - `kappa`: Cohen's kappa (2 raters) or Fleiss' kappa (3+ raters)

  - `kappa_type`: Character indicating "Cohen's" or "Fleiss'"

  - `percent_agreement`: Simple percent agreement

- **Ordinal level:**:

  - `alpha_ordinal`: Krippendorff's alpha (ordinal)

  - `kappa_weighted`: Weighted kappa (2 raters only)

  - `w`: Kendall's W coefficient of concordance

  - `rho`: Spearman's rho

  - `percent_agreement`: Simple percent agreement

- **Interval level:**:

  - `alpha_interval`: Krippendorff's alpha (interval)

  - `icc`: Intraclass correlation coefficient

  - `r`: Pearson's r

  - `percent_agreement`: Simple percent agreement

- **Ratio level:**:

  Measures are the same as for interval level, but Krippendorff's alpha
  is computed using the ratio-level formula.

  - `alpha_ratio`: Krippendorff's alpha (ratio)

  - `icc`: Intraclass correlation coefficient

  - `r`: Pearson's r

  - `percent_agreement`: Simple percent agreement

- `subjects`:

  Number of units compared

- `raters`:

  Number of raters

- `level`:

  Measurement level

- `call`:

  The function call

## Details

The function merges the coded objects by their `.id` column and only
includes units that are present in all objects. Missing values in any
rater will exclude that unit from analysis.

**Measurement levels and statistics:**

- **Nominal**: For unordered categories. Computes Krippendorff's alpha,
  Cohen's/Fleiss' kappa, and percent agreement.

- **Ordinal**: For ordered categories. Computes Krippendorff's alpha
  (ordinal), weighted kappa (2 raters only), Kendall's W, Spearman's
  rho, and percent agreement.

- **Interval**: For continuous data with meaningful intervals. Computes
  Krippendorff's alpha (interval), ICC, Pearson's r, and percent
  agreement.

- **Ratio**: For continuous data with a true zero point. Computes the
  same measures as interval level, but Krippendorff's alpha uses the
  ratio-level formula which accounts for proportional differences.

Kendall's W, ICC, and percent agreement are computed using all raters
simultaneously. For 3 or more raters, Spearman's rho and Pearson's r are
computed as the mean of all pairwise correlations between raters.

## See also

[`qlm_validate()`](https://seraphinem.github.io/quallmer/reference/qlm_validate.md)
for validation of coding against gold standards.

## Examples

``` r
if (FALSE) { # \dontrun{
# Compare two LLM coding runs on movie reviews
set.seed(42)
reviews <- data_corpus_LMRDsample[sample(length(data_corpus_LMRDsample), size = 20)]
coded1 <- qlm_code(reviews, data_codebook_sentiment, model = "openai/gpt-4o-mini")
coded2 <- qlm_code(reviews, data_codebook_sentiment, model = "openai/gpt-4o")

# Compare nominal data (polarity: neg/pos)
qlm_compare(coded1, coded2, by = "sentiment", level = "nominal")

# Compare ordinal data (rating: 1-10)
qlm_compare(coded1, coded2, by = "rating", level = "ordinal")

# Compare three raters using Fleiss' kappa on polarity
coded3 <- qlm_replicate(coded1, params = params(temperature = 0.5))
qlm_compare(coded1, coded2, coded3, by = "sentiment", level = "nominal")
} # }
```
