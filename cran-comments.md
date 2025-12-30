Resubmission:
## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.
* NOTE: The dependency ‘ellmer’ on my local machine shows a minor version mismatch warning (“built under R 4.5.2”). This does not occur on CRAN since dependencies are built from source there.

## Test environments

* Local macOS R 4.5.x: `devtools::check(--as-cran)` — OK

## Additional comments

* We addressed earlier requests to add references, by adding these to the package-level documentation as well as to the relevant function documentation (e.g., `validate()`).

