# Example: Fact checking of claims

The
[`annotate()`](https://quallmer.github.io/quallmer/reference/annotate.md)
function with a predefined
[`task_fact()`](https://quallmer.github.io/quallmer/reference/task_fact.md)
can be used to fact-check claims made in texts. In this example, we will
demonstrate how to apply this task to a sample corpus of innaugural
speeches from US presidents. The fact-checking process involves
evaluating the truthfulness of claims made in the speeches and providing
explanations for each claim. The outcome is a **truthfulness score from
0 to 10, where 0 indicates completely false claims and 10 indicates
highest confidence in the truthfulness of the claims.**

### Loading packages and data

`# We will use the quanteda package `` ``# for loading a sample corpus of innaugural speeches`` ``# If you have not yet installed the quanteda package, you can do so by:`` ``# install.packages("quanteda")`` `[`library`](https://rdrr.io/r/base/library.html)`(`[`quanteda`](https://quanteda.io)`)`

    ## Package version: 4.3.1
    ## Unicode version: 14.0
    ## ICU version: 71.1

    ## Parallel computing: disabled

    ## See https://quanteda.io for tutorials and examples.

[`library`](https://rdrr.io/r/base/library.html)`(`[`quallmer`](https://seraphinem.github.io/quallmer/)`)`

    ## Loading required package: ellmer

`# For educational purposes, `` ``# we will use a subset of the inaugural speeches corpus`` ``# The three most recent speeches in the corpus`` ``data_corpus_inaugural`` ``<-`` ``quanteda``::`[`data_corpus_inaugural`](https://quanteda.io/reference/data_corpus_inaugural.html)`[``57``:``60``]`

### Using `annotate()` for fact checking of claims in texts

`# Apply predefined fact checking task with task_fact() in the annotate() function`` ``result`` ``<-`` `[`annotate`](https://quallmer.github.io/quallmer/reference/annotate.md)`(``data_corpus_inaugural``, task ``=`` `[`task_fact`](https://quallmer.github.io/quallmer/reference/task_fact.md)`(``)``,`` `` model_name ``=`` ``"openai/gpt-4o"``,`` `` params ``=`` `[`list`](https://rdrr.io/r/base/list.html)`(``temperature ``=`` ``0``)``)`

    ## [working] (0 + 0) -> 3 -> 1 | ■■■■■■■■■                         25%

    ## [working] (0 + 0) -> 1 -> 3 | ■■■■■■■■■■■■■■■■■■■■■■■           75%

    ## [working] (0 + 0) -> 0 -> 4 | ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100%

[TABLE]

### Using `annotate()` for fact checking with a specific number of claims to check

`# Apply predefined fact checking task with task_fact() in the annotate() function`` ``result_claims`` ``<-`` `[`annotate`](https://quallmer.github.io/quallmer/reference/annotate.md)`(``data_corpus_inaugural``, task ``=`` `[`task_fact`](https://quallmer.github.io/quallmer/reference/task_fact.md)`(``max_topics ``=`` ``3``)``,`` `` model_name ``=`` ``"openai/gpt-4o"``,`` `` params ``=`` `[`list`](https://rdrr.io/r/base/list.html)`(``temperature ``=`` ``0``)``)`

    ## [working] (0 + 0) -> 3 -> 1 | ■■■■■■■■■                         25%

    ## [working] (0 + 0) -> 2 -> 2 | ■■■■■■■■■■■■■■■■                  50%

    ## [working] (0 + 0) -> 0 -> 4 | ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100%

[TABLE]

In this example, we demonstrated how to use the
[`annotate()`](https://quallmer.github.io/quallmer/reference/annotate.md)
function with the
[`task_fact()`](https://quallmer.github.io/quallmer/reference/task_fact.md)
to fact-check claims in a corpus of innaugural speeches. The results
include a truth score, identified misleading topics, and explanations
for each claim evaluated. The amount of claims to check can be adjusted
using the `max_topics` parameter in the
[`task_fact()`](https://quallmer.github.io/quallmer/reference/task_fact.md)
function. Now you can apply this approach to your own texts for
fact-checking purposes!
