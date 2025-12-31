# quallmer (development version)

## New API

The package introduces a new `qlm_*()` API with richer return objects and clearer terminology for qualitative researchers:

* `qlm_codebook()` defines coding instructions, replacing `task()` (#27).
* `qlm_code()` executes coding tasks and returns a tibble with coded results and metadata as attributes, replacing `annotate()` (#27). The returned `qlm_coded` object prints as a tibble and can be used directly in data manipulation workflows.
* `qlm_compare()` compares multiple `qlm_coded` objects to assess inter-rater reliability using measures from the irr package (Krippendorff's alpha, Cohen's/Fleiss' kappa, Kendall's W, or percent agreement).

The new API uses the `qlm_` prefix to avoid namespace conflicts (e.g., with `ggplot2::annotate()`) and follows the convention of verbs for workflow actions, nouns for accessor functions.

## Deprecated functions

* `task()` is deprecated in favor of `qlm_codebook()` (#27).
* `annotate()` is deprecated in favor of `qlm_code()` (#27).
* All predefined `task_*()` functions now return `qlm_codebook` objects (which are also `task` objects for compatibility).

**Backward compatibility**: Old code continues to work with deprecation warnings. New `qlm_codebook` objects work with old `annotate()`, and old `task` objects work with new `qlm_code()`. This is achieved through dual-class inheritance where `qlm_codebook` inherits from both `"qlm_codebook"` and `"task"`.

## Other changes

- Add contributor guides (`AGENTS.md`, `CLAUDE.md`) with structure, style, and testing guidance.
- Adopt tidyverse-style error messaging via `cli::cli_abort()` and `cli::cli_warn()` throughout the package, replacing all `stop()`, `stopifnot()`, and `warning()` calls with structured, informative error messages.
- Documentation and CI notes refreshed.

# quallmer 0.1.1

- CRAN release.

