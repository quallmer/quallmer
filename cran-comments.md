# quallmer 0.5.0 submission notes

## Purpose

Feature release. The main changes:

* `qlm_code()` validates every structured response against the codebook
  schema and records a non-conforming one as a failed unit, and new
  `qlm_failures()` and `qlm_backfill()` list and re-code the units a run
  failed on.
* Audio and video input to `qlm_code()`, and new `qlm_transcribe()` for
  transcribing audio recordings.
* All reliability and classification statistics are now implemented
  natively, so the package no longer imports 'irr' or 'yardstick'.

The breaking changes are listed in NEWS.md.

## R CMD check results

Checked on:
* local macOS (aarch64), R 4.6.1, `R CMD check --as-cran`

0 errors | 0 warnings | 0 notes

## Reverse dependency and other package conflicts

The one reverse dependency, 'quallmer.app' 0.1.0, passes `R CMD check`
against this version.
