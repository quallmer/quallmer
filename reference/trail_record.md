# Trail record: reproducible quallmer annotation (deprecated)

**\[deprecated\]**

## Usage

``` r
trail_record(
  data,
  text_col,
  task,
  setting,
  id_col = NULL,
  cache_dir = NULL,
  overwrite = FALSE,
  annotate_fun = annotate
)
```

## Arguments

- data:

  A data frame containing the text to be annotated.

- text_col:

  Character scalar. Name of the text column.

- task:

  A quallmer task object.

- setting:

  A `trail_setting` object describing the LLM configuration.

- id_col:

  Optional character scalar identifying units.

- cache_dir:

  Optional directory in which to cache Trails. If `NULL`, caching
  disabled. For examples and tests, use
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html) to comply with
  CRAN policies.

- overwrite:

  Whether to overwrite existing cache.

- annotate_fun:

  Function used to perform the annotation (default
  [`annotate()`](https://quallmer.github.io/quallmer/reference/annotate.md)).

## Value

An object of class `"trail_record"`.

## Details

`trail_record()` is deprecated. Use
[`qlm_code()`](https://quallmer.github.io/quallmer/reference/qlm_code.md)
instead, which automatically captures metadata for reproducibility. For
systematic comparisons across different models or settings, see
[`qlm_replicate()`](https://quallmer.github.io/quallmer/reference/qlm_replicate.md).
