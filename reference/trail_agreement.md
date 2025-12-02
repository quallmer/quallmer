# Compute agreement across Trail settings

Convenience helper to compute intercoder reliability across multiple
Trail records or a Trail comparison by treating each setting as a coder.

## Usage

``` r
trail_agreement(
  x,
  id_col = "id",
  label_col = "label",
  min_coders = 2L,
  agreement_fun = agreement
)
```

## Arguments

- x:

  A `trail_compare` object or a list of `trail_record` objects.

- id_col:

  Character scalar. Name of the unit identifier column in the resulting
  wide data (defaults to "id").

- label_col:

  Character scalar. Name of the label column in each record's
  annotations (defaults to "label").

- min_coders:

  Integer. Minimum number of non-missing coders per unit required for
  inclusion. Passed through to `agreement_fun`.

- agreement_fun:

  Function used to compute agreement. Defaults to
  [`agreement()`](https://seraphinem.github.io/quallmer/reference/agreement.md),
  which is expected to accept `data`, `unit_id_col`, `coder_cols`, and
  `min_coders`.

## Value

The result of calling `agreement_fun()` on the wide data, typically a
data frame of agreement statistics.
