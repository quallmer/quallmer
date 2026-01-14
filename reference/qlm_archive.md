# Archive quallmer workflow

Convenience function that saves, exports, and optionally generates a
report for a quallmer workflow in one call. Accepts either coded objects
directly or a pre-built `qlm_trail` object.

## Usage

``` r
qlm_archive(x, ..., path, report = TRUE)
```

## Arguments

- x:

  Either a `qlm_trail` object from
  [`qlm_trail()`](https://quallmer.github.io/quallmer/reference/qlm_trail.md),
  or the first quallmer object (`qlm_coded`, `qlm_comparison`, or
  `qlm_validation`).

- ...:

  Additional quallmer objects to include in the trail (only used when
  `x` is not a `qlm_trail` object).

- path:

  Base path for output files. Creates `{path}.rds`, `{path}.json`, and
  optionally `{path}.qmd`.

- report:

  Logical. If `TRUE`, generates a Quarto report file. Default is `TRUE`.

## Value

Invisibly returns the `qlm_trail` object.

## Details

This function creates a complete archive of your workflow:

- `{path}.rds`: Complete trail object for R (can be reloaded with
  [`readRDS()`](https://rdrr.io/r/base/readRDS.html))

- `{path}.json`: Portable metadata for archival or sharing

- `{path}.qmd`: Human-readable report (if `report = TRUE`)

The function can be used in two ways:

1.  **Standalone**: Pass coded objects directly:

        qlm_archive(coded1, coded2, path = "workflow")

2.  **Piped**: Pass a pre-built trail:

        qlm_trail(coded1, coded2) |>
          qlm_archive(path = "workflow")

## See also

[`qlm_trail()`](https://quallmer.github.io/quallmer/reference/qlm_trail.md),
[`qlm_trail_save()`](https://quallmer.github.io/quallmer/reference/qlm_trail_save.md),
[`qlm_trail_export()`](https://quallmer.github.io/quallmer/reference/qlm_trail_export.md),
[`qlm_trail_report()`](https://quallmer.github.io/quallmer/reference/qlm_trail_report.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Code movie reviews and create replication
coded1 <- qlm_code(data_corpus_LMRDsample, data_codebook_sentiment,
                   model = "openai/gpt-4o", name = "gpt4o_run")
coded2 <- qlm_replicate(coded1, model = "openai/gpt-4o-mini", name = "mini_run")

# Archive entire workflow in one call
qlm_archive(coded1, coded2, path = "workflow")

# Piped usage
qlm_trail(coded1, coded2) |>
  qlm_archive(path = "workflow")

# Without report
qlm_archive(coded1, coded2, path = "workflow", report = FALSE)
} # }
```
