# Convert human-coded data to qlm_coded format

Converts a data frame of human-coded data into a `qlm_humancoded`
object, which inherits from `qlm_coded`. This enables provenance
tracking and integration with
[`qlm_compare()`](https://seraphinem.github.io/quallmer/reference/qlm_compare.md),
[`qlm_validate()`](https://seraphinem.github.io/quallmer/reference/qlm_validate.md),
and
[`qlm_trail()`](https://seraphinem.github.io/quallmer/reference/qlm_trail.md)
for human-coded data alongside LLM-coded results.

## Usage

``` r
qlm_humancoded(
  data,
  name = "human_coder",
  codebook = NULL,
  texts = NULL,
  metadata = list()
)
```

## Arguments

- data:

  A data frame containing human-coded data. Must include a `.id` column
  for unit identifiers and one or more coded variables.

- name:

  Character string identifying this coding run (e.g., "Coder_A",
  "expert_rater"). Default is "human_coder".

- codebook:

  Optional list containing coding instructions. Can include:

  `name`

  :   Name of the coding scheme

  `instructions`

  :   Text describing coding instructions

  `schema`

  :   NULL (not used for human coding)

  If `NULL` (default), a minimal placeholder codebook is created.

- texts:

  Optional vector of original texts or data that were coded. Should
  correspond to the `.id` values in `data`. If provided, enables more
  complete provenance tracking.

- metadata:

  Optional list of metadata about the coding process. Can include any
  relevant information such as:

  `coder_name`

  :   Name of the human coder

  `coder_id`

  :   Identifier for the coder

  `training`

  :   Description of coder training

  `date`

  :   Date of coding

  `notes`

  :   Any additional notes

  The function automatically adds `timestamp`, `n_units`, and
  `source = "human"`.

## Value

A `qlm_humancoded` object (inherits from `qlm_coded`), which is a tibble
with additional class and attributes for provenance tracking.

## Details

The resulting object has dual inheritance:
`c("qlm_humancoded", "qlm_coded", ...)` This allows it to work
seamlessly with all quallmer functions while maintaining a distinct
identity in provenance trails.

When printed, the object displays "Source: Human coder" instead of model
information, clearly distinguishing human from LLM coding in workflows.

## See also

[`qlm_code()`](https://seraphinem.github.io/quallmer/reference/qlm_code.md)
for LLM coding,
[`qlm_compare()`](https://seraphinem.github.io/quallmer/reference/qlm_compare.md)
for inter-rater reliability,
[`qlm_validate()`](https://seraphinem.github.io/quallmer/reference/qlm_validate.md)
for validation against gold standards,
[`qlm_trail()`](https://seraphinem.github.io/quallmer/reference/qlm_trail.md)
for provenance tracking.

## Examples

``` r
# Basic usage with minimal metadata
human_data <- data.frame(
  .id = 1:10,
  sentiment = sample(c("pos", "neg"), 10, replace = TRUE)
)

human_coded <- qlm_humancoded(human_data, name = "Coder_A")
human_coded
#> # quallmer coded object
#> # Run:      Coder_A
#> # Source:   Human coder
#> # Units:    10
#> 
#> # A tibble: 10 × 2
#>      .id sentiment
#>  * <int> <chr>    
#>  1     1 pos      
#>  2     2 pos      
#>  3     3 neg      
#>  4     4 pos      
#>  5     5 neg      
#>  6     6 neg      
#>  7     7 pos      
#>  8     8 pos      
#>  9     9 neg      
#> 10    10 neg      

# With complete metadata
human_coded <- qlm_humancoded(
  human_data,
  name = "expert_rater",
  codebook = list(
    name = "Sentiment Analysis",
    instructions = "Code overall sentiment as positive or negative"
  ),
  metadata = list(
    coder_name = "Dr. Smith",
    coder_id = "EXP001",
    training = "5 years experience",
    date = "2024-01-15"
  )
)

# Compare two human coders
human_coded_2 <- qlm_humancoded(
  data.frame(.id = 1:10, sentiment = sample(c("pos", "neg"), 10, replace = TRUE)),
  name = "Coder_B"
)

qlm_compare(human_coded, human_coded_2, by = sentiment, level = "nominal")
#> # Inter-rater reliability
#> # Subjects: 10 
#> # Raters:   2 
#> # Level:    nominal 
#> 
#> Krippendorff's alpha: -0.3434
#> Cohen's kappa:        -0.4000
#> Percent agreement:    0.3000
```
