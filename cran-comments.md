# quallmer 0.5.1 submission notes

## Purpose

Patch release. It changes only a test: `test-corpus.R` matched the summary line
quanteda prints for corpus objects ("Corpus consisting of ..."), which the
forthcoming quanteda 4.5.1 changes to "corpus of ... documents (... characters)
and ... docvars". With quanteda 4.5.1, the 0.5.0 test fails. The test now
accepts both formats, so 0.5.1 passes with the current CRAN quanteda (4.5.0) and
with 4.5.1. There are no changes to the package code.

Releasing this first avoids a reverse dependency failure when quanteda 4.5.1 is
submitted.

## R CMD check results

TODO: fill in after running `R CMD check --as-cran`.

## Reverse dependency and other package conflicts

The one reverse dependency, 'quallmer.app' 0.1.0, is unaffected by this
change, which touches only a test.
