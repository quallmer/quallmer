# Validate coding: intercoder reliability or gold-standard comparison

This function validates nominal coding data with multiple coders in two
ways:

- `mode = "icr"`: compute intercoder reliability statistics
  (Krippendorff's alpha (nominal), Fleiss' kappa, mean pairwise Cohen's
  kappa, mean pairwise percent agreement, share of unanimous units, and
  basic counts).

- `mode = "gold"`: treat one coder column as a gold standard (typically
  a human coder) and, for each other coder, compute accuracy,
  macro-averaged precision, recall, and F1.

## Usage

``` r
validate(
  data,
  id,
  coder_cols,
  min_coders = 2L,
  mode = c("icr", "gold"),
  gold = NULL,
  output = c("list", "data.frame")
)
```

## Arguments

- data:

  A data frame containing the unit identifier and coder columns.

- id:

  Character scalar. Name of the column identifying units (e.g. document
  ID, paragraph ID).

- coder_cols:

  Character vector. Names of columns containing the coders' codes (each
  column = one coder).

- min_coders:

  Integer: minimum number of non-missing coders per unit for that unit
  to be included. Default is 2.

- mode:

  Character scalar: either `"icr"` for intercoder reliability
  statistics, or `"gold"` to compare coders against a gold-standard
  coder.

- gold:

  Character scalar: name of the gold-standard coder column (must be one
  of `coder_cols`) when `mode = "gold"`.

- output:

  Character scalar: either `"list"` (default) to return a named list of
  metrics when `mode = "icr"`, or `"data.frame"` to return a long data
  frame with columns `metric` and `value`. For `mode = "gold"`, the
  result is always a data frame.

## Value

If `mode = "icr"`:

- If `output = "list"` (default): a named list of scalar metrics (e.g.
  `res$fleiss_kappa`).

- If `output = "data.frame"`: a data frame with columns `metric` and
  `value`.

If `mode = "gold"`: a data frame with one row per non-gold coder and
columns:

- coder_id:

  Name of the coder column compared to the gold standard

- n:

  Number of units with non-missing gold and coder codes

- accuracy:

  Overall accuracy

- precision_macro:

  Macro-averaged precision across categories

- recall_macro:

  Macro-averaged recall across categories

- f1_macro:

  Macro-averaged F1 score across categories

## Examples

``` r
if (FALSE) { # \dontrun{
# Intercoder reliability (list output)
res_icr <- validate(
  data = my_df,
  id   = "doc_id",
  coder_cols  = c("coder1", "coder2", "coder3"),
  mode = "icr"
)
res_icr$fleiss_kappa

# Intercoder reliability (data.frame output)
res_icr_df <- validate(
  data = my_df,
  id   = "doc_id",
  coder_cols  = c("coder1", "coder2", "coder3"),
  mode   = "icr",
  output = "data.frame"
)

# Gold-standard validation, assuming coder1 is human gold standard
res_gold <- validate(
  data = my_df,
  id   = "doc_id",
  coder_cols  = c("coder1", "coder2", "llm1", "llm2"),
  mode = "gold",
  gold = "coder1"
)
} # }
```
