# quallmer (development version)

## New API

The package introduces a new `qlm_*()` API with richer return objects and clearer terminology for qualitative researchers:

* `qlm_codebook()` defines coding instructions, replacing `task()` (#27).
* `qlm_code()` executes coding tasks and returns rich metadata including the codebook, execution settings, results, and timestamp, replacing `annotate()` (#27).
* `qlm_results()` extracts results from `qlm_coded` objects returned by `qlm_code()` (#27).

The new API uses the `qlm_` prefix to avoid namespace conflicts (e.g., with `ggplot2::annotate()`) and follows the convention of verbs for workflow actions, nouns for accessor functions.

## Deprecated functions

* `task()` is deprecated in favor of `qlm_codebook()` (#27).
* `annotate()` is deprecated in favor of `qlm_code()` + `qlm_results()` (#27).
* All predefined `task_*()` functions now return `qlm_codebook` objects (which are also `task` objects for compatibility).

**Backward compatibility**: Old code continues to work with deprecation warnings. New `qlm_codebook` objects work with old `annotate()`, and old `task` objects work with new `qlm_code()`. This is achieved through dual-class inheritance where `qlm_codebook` inherits from both `"qlm_codebook"` and `"task"`.

## Other changes

- Add contributor guides (`AGENTS.md`, `CLAUDE.md`) with structure, style, and testing guidance.
- Adopt tidyverse-style error messaging via `cli::cli_abort()` and `cli::cli_warn()` throughout the package, replacing all `stop()`, `stopifnot()`, and `warning()` calls with structured, informative error messages.
- Documentation and CI notes refreshed.

# quallmer 0.1.1

- CRAN release.

