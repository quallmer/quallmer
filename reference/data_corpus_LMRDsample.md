# Sample from Large Movie Review Dataset (Maas et al. 2011)

A sample of 100 positive and 100 negative reviews from the Maas et al.
(2011) dataset for sentiment classification. The original dataset
contains 50,000 highly polar movie reviews.

## Usage

``` r
data_corpus_LMRDsample
```

## Format

The corpus docvars consist of:

- docnumber:

  serial (within set and polarity) document number

- rating:

  user-assigned movie rating on a 1-10 point integer scale

- polarity:

  either `neg` or `pos` to indicate whether the movie review was
  negative or positive. See Maas et al (2011) for the cut-off values
  that governed this assignment.

## Source

<http://ai.stanford.edu/~amaas/data/sentiment/>

## References

Andrew L. Maas, Raymond E. Daly, Peter T. Pham, Dan Huang, Andrew Y. Ng,
and Christopher Potts. (2011). "[Learning Word Vectors for Sentiment
Analysis](http://ai.stanford.edu/~amaas/papers/wvSent_acl2011.pdf)". The
49th Annual Meeting of the Association for Computational Linguistics
(ACL 2011).

## Examples

``` r
if (FALSE) { # \dontrun{
library(quanteda)

# define a sentiment codebook
codebook_posneg <- qlm_codebook(
  name = "Sentiment analysis of movie reviews",
  instructions = "You will rate the sentiment from movie reviews.",
  schema = type_object(
    polarity = type_enum(c("pos", "neg"),
    description = "Sentiment label (pos = positive, neg = negative")
  )
)

set.seed(10001)
test_corpus <- data_corpus_LMRDsample %>%
  corpus_sample(size = 10, by = polarity)

result <- qlm_code(test_corpus, codebook_posneg, model = "openai/gpt-4o-mini")

# Create gold standard from corpus metadata
gold <- data.frame(.id = result$.id, polarity = test_corpus$polarity)

# Validate against human annotations
qlm_validate(result, gold, by = "polarity")
} # }
```
