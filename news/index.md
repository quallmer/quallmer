# Changelog

## quallmer (development version)

- Add contributor guides (`AGENTS.md`, `CLAUDE.md`) with structure,
  style, and testing guidance.
- Adopt tidyverse-style error messaging via
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
  and
  [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html)
  throughout the package, replacing all
  [`stop()`](https://rdrr.io/r/base/stop.html),
  [`stopifnot()`](https://rdrr.io/r/base/stopifnot.html), and
  [`warning()`](https://rdrr.io/r/base/warning.html) calls with
  structured, informative error messages.
- Documentation and CI notes refreshed; no API changes.

## quallmer 0.1.1

- CRAN release.
