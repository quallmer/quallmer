# Export trail to JSON

Exports an audit trail to JSON format for portability and archival.

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

Large objects like the full codebook schema and coded data are stored in
the RDS format (via
[`qlm_trail_save()`](https://seraphinem.github.io/quallmer/reference/qlm_trail_save.md))
rather than JSON.

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

# Extract trail and export to JSON
trail <- qlm_trail(coded1, coded2)
qlm_trail_export(trail, "analysis_trail.json")
} # }
```
