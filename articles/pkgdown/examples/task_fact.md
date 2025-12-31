# Example: Fact checking of claims

The
[`annotate()`](https://seraphinem.github.io/quallmer/reference/annotate.md)
function with a predefined
[`task_fact()`](https://seraphinem.github.io/quallmer/reference/task_fact.md)
can be used to fact-check claims made in texts. In this example, we will
demonstrate how to apply this task to a sample corpus of innaugural
speeches from US presidents. The fact-checking process involves
evaluating the truthfulness of claims made in the speeches and providing
explanations for each claim. The outcome is a **truthfulness score from
0 to 10, where 0 indicates completely false claims and 10 indicates
highest confidence in the truthfulness of the claims.**

### Loading packages and data

``` r
# We will use the quanteda package 
# for loading a sample corpus of innaugural speeches
# If you have not yet installed the quanteda package, you can do so by:
# install.packages("quanteda")
library(quanteda)
```

    ## Package version: 4.3.1
    ## Unicode version: 15.1
    ## ICU version: 74.2

    ## Parallel computing: disabled

    ## See https://quanteda.io for tutorials and examples.

``` r
library(quallmer)
```

    ## Loading required package: ellmer

``` r
# For educational purposes, 
# we will use a subset of the inaugural speeches corpus
# The three most recent speeches in the corpus
data_corpus_inaugural <- quanteda::data_corpus_inaugural[57:60]
```

### Using `annotate()` for fact checking of claims in texts

``` r
# Apply predefined fact checking task with task_fact() in the annotate() function
result <- annotate(data_corpus_inaugural, task = task_fact(),
                   model_name = "openai/gpt-4o",
                   params = list(temperature = 0))
```

    ## [working] (0 + 0) -> 3 -> 1 | ■■■■■■■■■                         25%

    ## [working] (0 + 0) -> 0 -> 4 | ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100%

| id         | truth_score | misleading_topic                                                                                                             | explanation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
|:-----------|------------:|:-----------------------------------------------------------------------------------------------------------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 2013-Obama |           9 |                                                                                                                              | The text is a ceremonial speech, likely an inaugural address, that emphasizes American values, historical references, and aspirations. It contains broad, aspirational statements rather than specific factual claims, which are generally accurate and consistent with historical and cultural narratives. There are no obvious misleading or false claims, but the nature of the speech is rhetorical and idealistic, which is typical for such contexts.                                                                                                                                                            |
| 2017-Trump |           5 | Transfer of power to the people, American carnage , America First policy , Protectionism benefits , Eradication of terrorism | The text is a political speech, which often includes aspirational and rhetorical statements rather than factual claims. The assertion of transferring power ‘back to the people’ is subjective and lacks specific evidence. The depiction of ‘American carnage’ is a dramatic portrayal that may not accurately reflect the overall state of the nation. The ‘America First’ policy and protectionism are complex issues with mixed outcomes, not universally beneficial as implied. The claim to eradicate terrorism is ambitious and not easily achievable. These elements contribute to a lower truthfulness score. |
| 2021-Biden |           9 |                                                                                                                              | The text is a speech that emphasizes themes of unity, democracy, and hope. It accurately reflects historical events and current challenges, such as the COVID-19 pandemic and political divisions. The speech is largely aspirational and rhetorical, focusing on ideals rather than specific factual claims, which contributes to its high truthfulness score. There are no significant misleading topics or inaccuracies present.                                                                                                                                                                                    |
| 2025-Trump |           3 | Historical inaccuracies, Policy claims , Election results , Panama Canal ownership , Energy resources                        | The text contains numerous factual inaccuracies and misleading claims. For instance, the assertion about the Panama Canal being ‘given to China’ is false; the canal is operated by Panama. The claim of winning ‘all seven swing states’ and the popular vote by ‘millions’ lacks evidence. The statement about the U.S. having the ‘largest amount of oil and gas’ is misleading, as it depends on definitions and metrics. Additionally, the narrative of a ‘golden age’ beginning is subjective and speculative. These issues significantly reduce the truthfulness score.                                         |

### Using `annotate()` for fact checking with a specific number of claims to check

``` r
# Apply predefined fact checking task with task_fact() in the annotate() function
result_claims <- annotate(data_corpus_inaugural, task = task_fact(max_topics = 3),
                   model_name = "openai/gpt-4o",
                   params = list(temperature = 0))
```

    ## [working] (0 + 0) -> 3 -> 1 | ■■■■■■■■■                         25%

    ## [working] (0 + 0) -> 0 -> 4 | ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100%

[TABLE]

In this example, we demonstrated how to use the
[`annotate()`](https://seraphinem.github.io/quallmer/reference/annotate.md)
function with the
[`task_fact()`](https://seraphinem.github.io/quallmer/reference/task_fact.md)
to fact-check claims in a corpus of innaugural speeches. The results
include a truth score, identified misleading topics, and explanations
for each claim evaluated. The amount of claims to check can be adjusted
using the `max_topics` parameter in the
[`task_fact()`](https://seraphinem.github.io/quallmer/reference/task_fact.md)
function. Now you can apply this approach to your own texts for
fact-checking purposes!
