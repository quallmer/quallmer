# quallmer 0.6.0 submission notes

## Purpose

Release with one fix and one new feature.

* Fixes a test: `test-corpus.R` matched the summary line quanteda prints for
  corpus objects ("Corpus consisting of ..."), which the forthcoming quanteda
  4.5.1 changes to "corpus of ... documents (... characters) and ... docvars".
  With quanteda 4.5.1, the 0.5.0 test fails. The test now accepts both
  formats, so 0.6.0 passes with the current CRAN quanteda (4.5.0) and with
  4.5.1. Releasing this first avoids a reverse dependency failure when
  quanteda 4.5.1 is submitted.

* Adds a new experimental function, `qlm_translate()`, which translates texts
  before coding. It adds 'xml2' to Imports and 'keyring' to Suggests. Its
  examples and live tests call paid APIs, so they are in `\dontrun{}` or
  skipped unless explicitly enabled.

## R CMD check results

0 errors | 0 warnings | 0 notes

* local macOS (aarch64-apple-darwin23), R 4.6.1, `R CMD check --as-cran`

## Reverse dependency and other package conflicts

The one reverse dependency, 'quallmer.app' 0.1.0, was checked against this
version with `R CMD check`: Status OK. The new function adds exports and does
not change existing ones.
