# Convert Trail records to coder-style wide data (deprecated)

**\[deprecated\]**

## Usage

``` r
trail_matrix(x, id_col = "id", label_col = "label")
```

## Arguments

- x:

  Either a `trail_compare` object or a named list of `trail_record`
  objects.

- id_col:

  Character scalar. Name of the column that identifies units (documents,
  paragraphs, etc.). Must be present in each record's `annotations`
  data.

- label_col:

  Character scalar. Name of the column in each record's `annotations`
  data containing the code or label of interest.

## Value

A data frame with one row per unit and one column per setting/record.
The unit ID column is retained under the name `id_col`.

## Details

`trail_matrix()` is deprecated. Use
[`qlm_compare()`](https://quallmer.github.io/quallmer/reference/qlm_compare.md)
to compare multiple coded objects directly.
