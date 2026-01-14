# trail_compare: run a task across multiple settings and compute reliability (deprecated)

**\[deprecated\]**

## Usage

``` r
trail_compare(
  data,
  text_col,
  task,
  settings,
  id_col = NULL,
  label_col = "label",
  cache_dir = NULL,
  overwrite = FALSE,
  annotate_fun = annotate,
  min_coders = 2L
)
```

## Arguments

- data:

  A data frame containing the text to be annotated.

- text_col:

  Character scalar. Name of the text column containing text units to
  annotate.

- task:

  A quallmer task object describing what to extract or label.

- settings:

  A named list of `trail_setting` objects. The list names serve as
  identifiers for each setting (similar to coder IDs).

- id_col:

  Optional character scalar identifying the unit column. If `NULL`, a
  consistent temporary ID (`".trail_unit_id"`) is created and added to
  the input data so annotations from all settings can be aligned.

- label_col:

  Character scalar. Name of the label column in each record's
  `annotations` data that should be used as the code for comparison
  (e.g. `"label"`, `"score"`, `"category"`).

- cache_dir:

  Optional character scalar specifying a directory to cache LLM outputs.
  Passed to
  [`trail_record()`](https://quallmer.github.io/quallmer/reference/trail_record.md).
  If `NULL`, caching disabled. For examples and tests, use
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html) to comply with
  CRAN policies.

- overwrite:

  Logical. If `TRUE`, ignore all cached results and recompute
  annotations for every setting.

- annotate_fun:

  Annotation backend function used by
  [`trail_record()`](https://quallmer.github.io/quallmer/reference/trail_record.md)
  (default =
  [`annotate()`](https://quallmer.github.io/quallmer/reference/annotate.md)).

- min_coders:

  Minimum number of non-missing coders per unit required for inclusion
  in the inter-rater reliability calculation.

## Value

A `trail_compare` object with components:

- records:

  Named list of `trail_record` objects (one per setting)

- matrix:

  Wide coder-style annotation matrix (settings = columns)

- icr:

  Named list of inter-rater reliability statistics

- meta:

  Metadata on settings, identifiers, task, timestamp, etc.

## Details

`trail_compare()` is deprecated. Use
[`qlm_replicate()`](https://quallmer.github.io/quallmer/reference/qlm_replicate.md)
to re-run coding with different models or settings, then use
[`qlm_compare()`](https://quallmer.github.io/quallmer/reference/qlm_compare.md)
to assess inter-rater reliability.

All settings are applied to the same text units. Because the ID column
is shared across settings, their annotation outputs can be directly
compared via the `matrix` component, and summarized using inter-rater
reliability statistics in `icr`.

## See also

- [`trail_record()`](https://quallmer.github.io/quallmer/reference/trail_record.md)
  – run a task for a single setting

- [`trail_matrix()`](https://quallmer.github.io/quallmer/reference/trail_matrix.md)
  – align records into coder-style wide format

- [`trail_icr()`](https://quallmer.github.io/quallmer/reference/trail_icr.md)
  – compute inter-rater reliability across settings
