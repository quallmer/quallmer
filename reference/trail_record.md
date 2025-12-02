# Trail record: reproducible quallmer annotation

Run a quallmer task on a data frame with a specified LLM setting,
capturing metadata for reproducibility and optionally caching the full
result on disk.

## Usage

``` r
trail_record(
  data,
  text_col,
  task,
  setting,
  id_col = NULL,
  cache_dir = "trail_cache",
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
  disabled.

- overwrite:

  Whether to overwrite existing cache.

- annotate_fun:

  Function used to perform the annotation (default
  [`annotate()`](https://seraphinem.github.io/quallmer/reference/annotate.md)).

## Value

An object of class `"trail_record"`.
