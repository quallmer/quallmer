# Compute intercoder reliability across Trail settings

Convenience helper to compute intercoder reliability across multiple
Trail records or a \`trail_compare\` object by treating each setting as
a coder and calling
[`validate()`](https://seraphinem.github.io/quallmer/reference/validate.md)
in `mode = "icr"`.

## Usage

``` r
trail_icr(
  x,
  id_col = "id",
  label_col = "label",
  min_coders = 2L,
  icr_fun = validate,
  ...
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
  inclusion.

- icr_fun:

  Function used to compute intercoder reliability. Defaults to
  [`validate()`](https://seraphinem.github.io/quallmer/reference/validate.md),
  which is expected to accept `data`, `id`, `coder_cols`, `min_coders`,
  and `mode = "icr"`. It should also understand `output = "list"` to
  return a named list of statistics.

- ...:

  Additional arguments passed on to `icr_fun`.

## Value

The result of calling `icr_fun()` on the wide data. With the default
[`validate()`](https://seraphinem.github.io/quallmer/reference/validate.md),
this is a named list of intercoder reliability statistics.

## See also

\* \`trail_compare()\` – run the same task across multiple settings \*
\`trail_matrix()\` – underlying wide data used here \* \`validate()\` –
core validation / ICR engine
