# quallmer (development version)

## New API

The package introduces a new `qlm_*()` API with richer return objects and clearer terminology for qualitative researchers:

* `qlm_codebook()` defines coding instructions, replacing `task()` (#27).
* `qlm_code()` executes coding tasks and returns a tibble with coded results and metadata as attributes, replacing `annotate()` (#27). The returned `qlm_coded` object prints as a tibble and can be used directly in data manipulation workflows. Now includes `name` parameter for tracking runs and hierarchical attribute structure with provenance support.
* `qlm_compare()` compares multiple `qlm_coded` objects to assess inter-rater reliability using measures from the irr package (Krippendorff's alpha, Cohen's/Fleiss' kappa, Kendall's W, or percent agreement).
* `qlm_validate()` validates a `qlm_coded` object against a gold standard (human-coded reference data) using classification metrics from the yardstick package. Computes accuracy, precision, recall, F1-score, and Cohen's kappa with support for multiple averaging methods (macro, micro, weighted, or per-class breakdown).
* `qlm_replicate()` re-executes coding with optional overrides (model, codebook, parameters) while tracking provenance chain. Enables systematic assessment of coding reliability and sensitivity to model choices.

The new API uses the `qlm_` prefix to avoid namespace conflicts (e.g., with `ggplot2::annotate()`) and follows the convention of verbs for workflow actions, nouns for accessor functions.

### Restructured qlm_coded objects

* `qlm_coded` objects now use a hierarchical attribute structure with a `run` list containing `name`, `call`, `codebook`, `chat_args`, `pcs_args`, `metadata`, and `parent` fields. This structure supports provenance tracking across replication chains and provides clearer organization of coding metadata.

## Built-in codebooks

* New `codebook_*()` functions provide ready-to-use codebooks for common tasks: `codebook_sentiment()`, `codebook_stance()`, `codebook_ideology()`, `codebook_salience()`, and `codebook_fact()`.
* All predefined `task_*()` functions (`task_sentiment()`, `task_stance()`, `task_ideology()`, `task_salience()`, `task_fact()`) are deprecated in favor of the new `codebook_*()` equivalents.

## Deprecated and superseded functions

* `task()` is deprecated in favor of `qlm_codebook()` (#27).
* `annotate()` is deprecated in favor of `qlm_code()` (#27).
* `validate()` is superseded by `qlm_compare()` (for inter-rater reliability) and `qlm_validate()` (for gold standard validation). The function remains available but is marked with a lifecycle badge.
* Trail functions (`trail_settings()`, `trail_record()`, `trail_compare()`, `trail_matrix()`, `trail_icr()`) are deprecated. Use `qlm_code()` with model and temperature parameters directly, or `qlm_replicate()` for systematic comparisons across models.

**Backward compatibility**: Old code continues to work with deprecation warnings. New `qlm_codebook` objects work with old `annotate()`, and old `task` objects work with new `qlm_code()`. This is achieved through dual-class inheritance where `qlm_codebook` inherits from both `"qlm_codebook"` and `"task"`.

## Package restructuring

* `validate_app()` has been extracted into the companion package [quallmer.app](https://github.com/SeraphineM/quallmer.app). This reduces dependencies in the core quallmer package (removing shiny, bslib, and htmltools from Imports). Install quallmer.app separately for interactive validation functionality.

## Other changes

- Improved error messages in `qlm_compare()` and `qlm_validate()` now show which objects are missing the requested variable and list available alternatives.
- Add contributor guides (`AGENTS.md`, `CLAUDE.md`) with structure, style, and testing guidance.
- Adopt tidyverse-style error messaging via `cli::cli_abort()` and `cli::cli_warn()` throughout the package, replacing all `stop()`, `stopifnot()`, and `warning()` calls with structured, informative error messages.
- Documentation and CI notes refreshed.

