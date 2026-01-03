# Trail settings specification (deprecated)

**\[deprecated\]**

## Usage

``` r
trail_settings(
  provider = "openai",
  model = "gpt-4o-mini",
  temperature = 0,
  extra = list()
)
```

## Arguments

- provider:

  Character. Backend provider identifier supported by ellmer, e.g.
  "openai", "ollama", "anthropic". See [ellmer
  documentation](https://ellmer.tidyverse.org/) for all supported
  providers.

- model:

  Character. Model identifier, e.g. "gpt-4o-mini", "llama3.2:1b",
  "claude-3-5-sonnet-20241022".

- temperature:

  Numeric scalar. Sampling temperature (default 0). Valid range depends
  on provider: OpenAI (0-2), Anthropic (0-1), etc.

- extra:

  Named list of extra arguments merged into `api_args`.

## Value

An object of class `"trail_setting"`.

## Details

`trail_settings()` is deprecated. Use
[`qlm_code()`](https://seraphinem.github.io/quallmer/reference/qlm_code.md)
with the `model` and `temperature` parameters directly instead. For
systematic comparisons across different models or settings, see
[`qlm_replicate()`](https://seraphinem.github.io/quallmer/reference/qlm_replicate.md).
