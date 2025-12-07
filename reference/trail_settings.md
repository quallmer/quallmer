# Trail settings specification

Define a reproducible specification of an LLM setting for use with
quallmer Trail. This object captures the provider, model name,
temperature, and any optional extra arguments.

## Usage

``` r
trail_settings(
  provider = "openai",
  model = "gpt-4.1-mini",
  temperature = 0,
  extra = list()
)
```

## Arguments

- provider:

  Character. Backend provider, e.g. "openai", "ollama", "azure".

- model:

  Character. Model identifier, e.g. "gpt-4.1-mini", "gpt-4o-mini",
  "llama3.1:8b".

- temperature:

  Numeric scalar. Sampling temperature (default 0).

- extra:

  Named list of additional model arguments passed to \`annotate()\` via
  \`api_args\` if needed (e.g. penalties or safety flags).

## Value

An object of class `"trail_setting"`.
