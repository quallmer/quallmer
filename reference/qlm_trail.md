# Extract provenance trail from quallmer objects

Extracts and displays the provenance chain from one or more `qlm_coded`,
`qlm_comparison`, or `qlm_validation` objects. When multiple objects are
provided, attempts to reconstruct the full lineage by matching
parent-child relationships.

## Usage

``` r
qlm_trail(...)
```

## Arguments

- ...:

  One or more quallmer objects (`qlm_coded`, `qlm_comparison`, or
  `qlm_validation`). When multiple objects are provided, they will be
  used to reconstruct the complete provenance chain.

## Value

A `qlm_trail` object containing:

- runs:

  List of run information, ordered from oldest to newest

- complete:

  Logical indicating whether all parent references were resolved

## Details

The provenance trail shows the history of coding runs, including:

- Run name and parent relationship

- Model and parameters used

- Timestamp

- Call that created the run

When a single object is provided, only its immediate lineage (name,
parent, timestamp) is shown. To see the full chain, provide all ancestor
objects.

For branching workflows (e.g., when multiple coded objects are
compared), the trail captures all input runs as parents of the
comparison.

## See also

[`qlm_replicate()`](https://seraphinem.github.io/quallmer/reference/qlm_replicate.md),
[`qlm_code()`](https://seraphinem.github.io/quallmer/reference/qlm_code.md),
[`qlm_compare()`](https://seraphinem.github.io/quallmer/reference/qlm_compare.md),
[`qlm_validate()`](https://seraphinem.github.io/quallmer/reference/qlm_validate.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Single run shows immediate info
coded1 <- qlm_code(reviews, codebook, model = "openai/gpt-4o")
qlm_trail(coded1)

# Create replication chain
coded2 <- qlm_replicate(coded1, model = "openai/gpt-4o-mini")
coded3 <- qlm_replicate(coded2, temperature = 0.7)

# Reconstruct full chain
trail <- qlm_trail(coded3, coded2, coded1)
print(trail)

# Save for archival
qlm_trail_save(trail, "analysis_trail.rds")

# Export to JSON
qlm_trail_export(trail, "analysis_trail.json")
} # }
```
