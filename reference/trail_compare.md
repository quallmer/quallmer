# Trail compare: run the same task across multiple settings

Apply a quallmer task to the same data and text column for a set of
settings, returning one `trail_record` per setting.

## Usage

``` r
trail_compare(
  data,
  text_col,
  task,
  settings,
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

- settings:

  A named list of `trail_setting` objects. The names will be used as
  identifiers for each setting (e.g. coder IDs).

- id_col:

  Optional character scalar. Name of the unit identifier column. If
  `NULL`, a temporary `".trail_unit_id"` will be created and shared
  across all records.

- cache_dir:

  Optional directory for caching. Passed to
  [`trail_record()`](https://seraphinem.github.io/quallmer/reference/trail_record.md).

- overwrite:

  Logical. If `TRUE`, ignore cache for all settings and recompute.

- annotate_fun:

  Function used to perform the annotation, passed to
  [`trail_record()`](https://seraphinem.github.io/quallmer/reference/trail_record.md).

## Value

An object of class `"trail_compare"` containing a named list of
`trail_record` objects and some basic metadata.
