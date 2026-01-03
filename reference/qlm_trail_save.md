# Save trail to RDS file

Saves a provenance trail to an RDS file for archival purposes.

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
trail <- qlm_trail(coded1, coded2, coded3)
qlm_trail_save(trail, "analysis_trail.rds")
} # }
```
