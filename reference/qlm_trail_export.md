# Export trail to JSON

Exports a provenance trail to JSON format for portability and archival.

## Usage

``` r
qlm_trail_export(trail, file)
```

## Arguments

- trail:

  A `qlm_trail` object from
  [`qlm_trail()`](https://seraphinem.github.io/quallmer/reference/qlm_trail.md).

- file:

  Path to save the JSON file.

## Value

Invisibly returns the file path.

## Details

The JSON export includes:

- Run names and parent relationships

- Timestamps

- Model names and parameters

- Codebook names

- Call information (as text)

Large objects like the full codebook schema and data are not included to
keep file sizes manageable.

## See also

[`qlm_trail()`](https://seraphinem.github.io/quallmer/reference/qlm_trail.md)

## Examples

``` r
if (FALSE) { # \dontrun{
trail <- qlm_trail(coded1, coded2, coded3)
qlm_trail_export(trail, "analysis_trail.json")
} # }
```
