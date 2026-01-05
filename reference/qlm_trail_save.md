# Save trail to RDS file

Saves a provenance trail to an RDS file for archival purposes. If the
trail was created with `include_data = TRUE`, the actual coded data will
also be saved, creating a complete archive of your analysis.

## Usage

``` r
qlm_trail_save(trail, file)
```

## Arguments

- trail:

  A `qlm_trail` object from
  [`qlm_trail()`](https://seraphinem.github.io/quallmer/reference/qlm_trail.md).

- file:

  Path to save the RDS file.

## Value

Invisibly returns the file path.

## See also

[`qlm_trail()`](https://seraphinem.github.io/quallmer/reference/qlm_trail.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Save metadata only (lightweight)
trail <- qlm_trail(coded1, coded2, coded3)
qlm_trail_save(trail, "analysis_trail.rds")

# Save complete archive with coded data
trail_complete <- qlm_trail(coded1, coded2, coded3, include_data = TRUE)
qlm_trail_save(trail_complete, "analysis_trail_complete.rds")
} # }
```
