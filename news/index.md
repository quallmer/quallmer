# Changelog

## quallmer 0.2.0

### The quallmer trail

- New
  [`qlm_trail()`](https://seraphinem.github.io/quallmer/reference/qlm_trail.md)
  function extracts and displays provenance chains from coded objects,
  showing the complete history of coding runs including model
  parameters, timestamps, and parent-child relationships.
- Export functions allow saving provenance trails:
  [`qlm_trail_save()`](https://seraphinem.github.io/quallmer/reference/qlm_trail_save.md)
  for RDS archival,
  [`qlm_trail_export()`](https://seraphinem.github.io/quallmer/reference/qlm_trail_export.md)
  for JSON format, and
  [`qlm_trail_report()`](https://seraphinem.github.io/quallmer/reference/qlm_trail_report.md)
  for human-readable Quarto/RMarkdown documents.
- All `qlm_comparison` and `qlm_validation` objects now include run
  attributes capturing parent provenance, enabling full workflow
  traceability across comparisons and validations.
- Provenance trail automatically captures branching workflows when
  multiple coded objects are compared or validated.

### New API

The package introduces a new `qlm_*()` API with richer return objects
and clearer terminology for qualitative researchers:

- [`qlm_codebook()`](https://seraphinem.github.io/quallmer/reference/qlm_codebook.md)
  defines coding instructions, replacing
  [`task()`](https://seraphinem.github.io/quallmer/reference/task.md)
  (#27).
- [`qlm_code()`](https://seraphinem.github.io/quallmer/reference/qlm_code.md)
  executes coding tasks and returns a tibble with coded results and
  metadata as attributes, replacing
  [`annotate()`](https://seraphinem.github.io/quallmer/reference/annotate.md)
  (#27). The returned `qlm_coded` object prints as a tibble and can be
  used directly in data manipulation workflows. Now includes `name`
  parameter for tracking runs and hierarchical attribute structure with
  provenance support.
- [`qlm_compare()`](https://seraphinem.github.io/quallmer/reference/qlm_compare.md)
  compares multiple `qlm_coded` objects to assess inter-rater
  reliability. Automatically computes all statistically appropriate
  measures from the irr package based on the specified measurement level
  (nominal, ordinal, or interval).
- [`qlm_validate()`](https://seraphinem.github.io/quallmer/reference/qlm_validate.md)
  validates a `qlm_coded` object against a gold standard (human-coded
  reference data). Automatically computes all statistically appropriate
  metrics based on the specified measurement level, using measures from
  the yardstick, irr, and stats packages. For nominal data, supports
  multiple averaging methods (macro, micro, weighted, or per-class
  breakdown).
- [`qlm_replicate()`](https://seraphinem.github.io/quallmer/reference/qlm_replicate.md)
  re-executes coding with optional overrides (model, codebook,
  parameters) while tracking provenance chain. Enables systematic
  assessment of coding reliability and sensitivity to model choices.

The new API uses the `qlm_` prefix to avoid namespace conflicts (e.g.,
with `ggplot2::annotate()`) and follows the convention of verbs for
workflow actions, nouns for accessor functions.

#### Restructured qlm_coded objects

- `qlm_coded` objects now use a hierarchical attribute structure with a
  `run` list containing `name`, `batch`, `call`, `codebook`,
  `chat_args`, `execution_args`, `metadata`, and `parent` fields. This
  structure supports provenance tracking across replication chains and
  provides clearer organization of coding metadata (#26).
  - The `batch` flag indicates whether batch processing was used.
  - `execution_args` replaces `pcs_args` and stores all non-chat
    execution arguments for both parallel and batch processing. Old
    objects with `pcs_args` remain compatible.

### Example codebooks

- New example codebook data objects provide ready-to-use codebooks for
  common tasks: `data_codebook_sentiment`, `data_codebook_stance`,
  `data_codebook_ideology`, `data_codebook_salience`, and
  `data_codebook_fact`.
- All predefined `task_*()` functions are deprecated in favor of using
  the data objects or creating custom codebooks with
  [`qlm_codebook()`](https://seraphinem.github.io/quallmer/reference/qlm_codebook.md).

### Deprecated and superseded functions

- [`task()`](https://seraphinem.github.io/quallmer/reference/task.md) is
  deprecated in favor of
  [`qlm_codebook()`](https://seraphinem.github.io/quallmer/reference/qlm_codebook.md)
  (#27).
- [`annotate()`](https://seraphinem.github.io/quallmer/reference/annotate.md)
  is deprecated in favor of
  [`qlm_code()`](https://seraphinem.github.io/quallmer/reference/qlm_code.md)
  (#27).
- [`validate()`](https://seraphinem.github.io/quallmer/reference/validate.md)
  is superseded by
  [`qlm_compare()`](https://seraphinem.github.io/quallmer/reference/qlm_compare.md)
  (for inter-rater reliability) and
  [`qlm_validate()`](https://seraphinem.github.io/quallmer/reference/qlm_validate.md)
  (for gold standard validation). The function remains available but is
  marked with a lifecycle badge.
- Trail functions
  ([`trail_settings()`](https://seraphinem.github.io/quallmer/reference/trail_settings.md),
  [`trail_record()`](https://seraphinem.github.io/quallmer/reference/trail_record.md),
  [`trail_compare()`](https://seraphinem.github.io/quallmer/reference/trail_compare.md),
  [`trail_matrix()`](https://seraphinem.github.io/quallmer/reference/trail_matrix.md),
  [`trail_icr()`](https://seraphinem.github.io/quallmer/reference/trail_icr.md))
  are deprecated. Use
  [`qlm_code()`](https://seraphinem.github.io/quallmer/reference/qlm_code.md)
  with model and temperature parameters directly, or
  [`qlm_replicate()`](https://seraphinem.github.io/quallmer/reference/qlm_replicate.md)
  for systematic comparisons across models.

**Backward compatibility**: Old code continues to work with deprecation
warnings. New `qlm_codebook` objects work with old
[`annotate()`](https://seraphinem.github.io/quallmer/reference/annotate.md),
and old `task` objects work with new
[`qlm_code()`](https://seraphinem.github.io/quallmer/reference/qlm_code.md).
This is achieved through dual-class inheritance where `qlm_codebook`
inherits from both `"qlm_codebook"` and `"task"`.

### Package restructuring

- `validate_app()` has been extracted into the companion package
  [quallmer.app](https://github.com/SeraphineM/quallmer.app). This
  reduces dependencies in the core quallmer package (removing shiny,
  bslib, and htmltools from Imports). Install quallmer.app separately
  for interactive validation functionality.

### Other changes

- **BREAKING**:
  [`qlm_validate()`](https://seraphinem.github.io/quallmer/reference/qlm_validate.md)
  now uses distinct, statistically appropriate metrics for each
  measurement level:

  - **Nominal** (`level = "nominal"`): accuracy, precision, recall,
    F1-score, Cohen’s kappa (unweighted)
  - **Ordinal** (`level = "ordinal"`): Spearman’s rho, Kendall’s tau,
    MAE (mean absolute error)
  - **Interval/Ratio** (`level = "interval"`): ICC (intraclass
    correlation), Pearson’s r, MAE, RMSE (root mean squared error)

  The `measure` argument has been removed entirely - all appropriate
  measures are now computed automatically based on the `level`
  parameter. Function signature changed: `level` now comes before
  `average`, and `average` only applies to nominal (multiclass) data.
  Return values renamed for consistency: `spearman` → `rho`, `kendall` →
  `tau`, `pearson` → `r`. Print output uses “levels” terminology for
  ordinal data and “classes” for nominal data. This change provides more
  statistically sound validation that respects the mathematical
  properties of each measurement scale.

- **BREAKING**:
  [`qlm_compare()`](https://seraphinem.github.io/quallmer/reference/qlm_compare.md)
  now computes all statistically appropriate measures for each
  measurement level:

  - **Nominal** (`level = "nominal"`): Krippendorff’s alpha (nominal),
    Cohen’s/Fleiss’ kappa, percent agreement
  - **Ordinal** (`level = "ordinal"`): Krippendorff’s alpha (ordinal),
    weighted kappa (2 raters only), Kendall’s W, Spearman’s rho, percent
    agreement
  - **Interval/Ratio** (`level = "interval"`): Krippendorff’s alpha
    (interval), ICC (intraclass correlation), Pearson’s r, percent
    agreement

  The `measure` argument has been removed entirely - all appropriate
  measures are now computed automatically and returned in the result
  object. The return structure changed from a single value to a list
  containing all computed measures for the specified level. Percent
  agreement is now computed for all levels; for ordinal/interval/ratio
  data, the `tolerance` parameter controls what counts as agreement
  (e.g., `tolerance = 1` means values within 1 unit are considered in
  agreement).

- [`qlm_validate()`](https://seraphinem.github.io/quallmer/reference/qlm_validate.md)
  and
  [`qlm_compare()`](https://seraphinem.github.io/quallmer/reference/qlm_compare.md)
  now support non-standard evaluation (NSE) for the `by` argument,
  allowing both `by = sentiment` (unquoted) and `by = "sentiment"`
  (quoted) syntax. This provides a more natural, tidyverse-style
  interface while maintaining backward compatibility.

- Improved error messages in
  [`qlm_compare()`](https://seraphinem.github.io/quallmer/reference/qlm_compare.md)
  and
  [`qlm_validate()`](https://seraphinem.github.io/quallmer/reference/qlm_validate.md)
  now show which objects are missing the requested variable and list
  available alternatives.

- Adopt tidyverse-style error messaging via
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
  and
  [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html)
  throughout the package, replacing all
  [`stop()`](https://rdrr.io/r/base/stop.html),
  [`stopifnot()`](https://rdrr.io/r/base/stopifnot.html), and
  [`warning()`](https://rdrr.io/r/base/warning.html) calls with
  structured, informative error messages.

- Documentation and CI notes refreshed.
