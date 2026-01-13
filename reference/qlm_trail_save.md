# Save trail to RDS file

Saves an audit trail to an RDS file for archival purposes. The trail
includes all coded data, creating a complete archive of your analysis.

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

[`qlm_trail()`](https://seraphinem.github.io/quallmer/reference/qlm_trail.md),
[`qlm_archive()`](https://seraphinem.github.io/quallmer/reference/qlm_archive.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Code movie reviews and create replication
coded1 <- qlm_code(data_corpus_LMRDsample, data_codebook_sentiment,
                   model = "openai/gpt-4o", name = "gpt4o_run")
coded2 <- qlm_replicate(coded1, model = "openai/gpt-4o-mini", name = "mini_run")

# Extract trail and save
trail <- qlm_trail(coded1, coded2)
qlm_trail_save(trail, "analysis_trail.rds")
} # }
```
