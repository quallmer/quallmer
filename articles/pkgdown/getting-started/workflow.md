# The quallmer workflow

This tutorial provides a quick overview of the quallmer workflow for
LLM-assisted qualitative coding. We’ll use US presidential inaugural
addresses to demonstrate the core functions.

## The workflow at a glance

1.  **Define** your codebook with
    [`qlm_codebook()`](https://quallmer.github.io/quallmer/reference/qlm_codebook.md)
2.  **Code** your data with
    [`qlm_code()`](https://quallmer.github.io/quallmer/reference/qlm_code.md),
    and complete a run that came back with failures using
    [`qlm_backfill()`](https://quallmer.github.io/quallmer/reference/qlm_backfill.md)
3.  **Replicate** with different settings using
    [`qlm_replicate()`](https://quallmer.github.io/quallmer/reference/qlm_replicate.md)
4.  **Compare** results with
    [`qlm_compare()`](https://quallmer.github.io/quallmer/reference/qlm_compare.md)
5.  **Document** everything with
    [`qlm_trail()`](https://quallmer.github.io/quallmer/reference/qlm_trail.md)

## Sample data

We’ll use the inaugural addresses from the quanteda package:

[`library`](https://rdrr.io/r/base/library.html)`(`[`quallmer`](https://quallmer.github.io/quallmer/)`)`` `[`library`](https://rdrr.io/r/base/library.html)`(`[`quanteda`](https://quanteda.io)`)`` `` ``# Get last 5 inaugural addresses`` ``texts`` ``<-`` `[`tail`](https://rdrr.io/r/utils/head.html)`(``data_corpus_inaugural``, ``5``)`` ``texts`

## Step 1: Define a codebook

A codebook specifies what the LLM should extract from your texts:

`my_codebook`` ``<-`` `[`qlm_codebook`](https://quallmer.github.io/quallmer/reference/qlm_codebook.md)`(`` `` name ``=`` ``"Tone analysis"``,`` `` instructions ``=`` ``"Classify the overall tone of this political speech."``,`` `` schema ``=`` `[`type_object`](https://ellmer.tidyverse.org/reference/type_boolean.html)`(`` `` tone ``=`` `[`type_enum`](https://ellmer.tidyverse.org/reference/type_boolean.html)`(`` `` values ``=`` `[`c`](https://rdrr.io/r/base/c.html)`(``"optimistic"``, ``"cautious"``, ``"urgent"``)``,`` `` description ``=`` ``"The dominant emotional tone"`` `` ``)``,`` `` confidence ``=`` `[`type_integer`](https://ellmer.tidyverse.org/reference/type_boolean.html)`(``"Confidence in classification from 1-5"``)`` `` ``)`` ``)`` `` ``my_codebook`

> **Tip:** Need to split texts into smaller units first? Use
> [`qlm_segment()`](https://quallmer.github.io/quallmer/reference/qlm_segment.md)
> to segment texts into thematic or conceptual units (e.g.,
> quasi-sentences, aspects, or topics) before coding. For an example,
> see here: [Text
> segmentation](https://quallmer.github.io/quallmer/articles/pkgdown/examples/example_segmentation.html).

## Step 2: Code your data

Apply the codebook to your texts using an LLM:

`coded`` ``<-`` `[`qlm_code`](https://quallmer.github.io/quallmer/reference/qlm_code.md)`(`` `` ``texts``,`` `` ``my_codebook``,`` `` model ``=`` ``"openai/gpt-4o-mini"``,`` `` name ``=`` ``"gpt4o_mini"`` ``)`` `` ``coded`

### When a run comes back incomplete

A run over a real corpus rarely comes back complete. Requests time out
or hit a rate limit, a provider refuses a text on one pass and codes it
on the next, an endpoint accepts the schema and then returns something
that does not fit it. The units that failed sit in the object as rows of
`NA`, [`print()`](https://rdrr.io/r/base/print.html) counts them, and
[`qlm_failures()`](https://quallmer.github.io/quallmer/reference/qlm_failures.md)
lists them with the reason.

The run below ships with the package, so the rest of this section runs
without a key. Eight movie reviews were coded with a deliberately short
request timeout and a `max_tokens` of 90, and came back with both kinds
of failure this section is about: a request that timed out, and
responses the model could not fit into the output limit.

`examples`` ``<-`` `[`readRDS`](https://rdrr.io/r/base/readRDS.html)`(`[`system.file`](https://rdrr.io/r/base/system.file.html)`(``"extdata"``, ``"example_objects.rds"``, package ``=`` ``"quallmer"``)``)`` ``incomplete`` ``<-`` ``examples``$``example_coded_incomplete`` ``incomplete`

    ## # quallmer coded object
    ## # Run:      example_incomplete
    ## # Codebook: Sentiment with evidence
    ## # Model:    anthropic/claude-haiku-4-5
    ## # Units:    8 (4 scored, 4 failed)
    ## # Notes:    Coded with a deliberately short request timeout and max_tokens = 90, so that the run came back incomplete
    ## 
    ## # A tibble: 8 × 5
    ##   .id          sentiment rating evidence                              .error    
    ## * <chr>        <fct>      <int> <chr>                                 <list>    
    ## 1 3275_2.txt   neg            1 "Lets just say that from now on, we … <NULL>    
    ## 2 3150_1.txt   NA            NA  NA                                   <qllmr_t_>
    ## 3 3918_1.txt   NA            NA  NA                                   <qllmr_t_>
    ## 4 7530_1.txt   neg            1 "\"to call this the next cult classi… <NULL>    
    ## 5 4247_8.txt   pos            7 "One very strange piece of cinema. Y… <NULL>    
    ## 6 7227_7.txt   NA            NA  NA                                   <httr2_fl>
    ## 7 8877_8.txt   pos            9 "The one thing I really can't seem t… <NULL>    
    ## 8 11413_10.txt NA            NA  NA                                   <qllmr_t_>

[`qlm_failures`](https://quallmer.github.io/quallmer/reference/qlm_failures.md)`(``incomplete``)`

    ## # A tibble: 4 × 3
    ##   .id          reason                                                 .error    
    ##   <chr>        <chr>                                                  <list>    
    ## 1 3150_1.txt   "The response used the whole max_tokens limit of 90 a… <qllmr_t_>
    ## 2 3918_1.txt   "The response used the whole max_tokens limit of 90 a… <qllmr_t_>
    ## 3 7227_7.txt   "Failed to perform HTTP request.\nCaused by error:\n!… <httr2_fl>
    ## 4 11413_10.txt "The response used the whole max_tokens limit of 90 a… <qllmr_t_>

quallmer deals with failures at three points, and it helps to keep them
apart.

**Retries happen during the run, one request at a time, in two layers.**
The inner layer is ellmer’s: every request quallmer sends is retried at
the transport level if a rate limit or a server error turns it away, a
few times with a pause between, on every provider and every path;
`options(ellmer_max_tries = )` sets the count. The outer layer is
quallmer’s, and exists on the JSON path only: when a request comes back
unusable after ellmer’s tries, whether empty, unparsable, refused, not
conforming to the codebook’s schema, or still failing on transport,
[`qlm_code()`](https://quallmer.github.io/quallmer/reference/qlm_code.md)
sends the unit again, up to `json_retries` more times, and each of those
requests gets ellmer’s tries afresh. On the structured path there is no
outer layer: a request is tried by ellmer and then stands, and the only
second chance is that `structured = "auto"` falls back to the JSON path
when the structured call fails as a whole. A unit still failed after all
of this is what
[`qlm_failures()`](https://quallmer.github.io/quallmer/reference/qlm_failures.md)
shows.

**Backfilling happens after the run, on the object it produced.**
[`qlm_backfill()`](https://quallmer.github.io/quallmer/reference/qlm_backfill.md)
looks up the units that failed, re-codes just those with the run’s own
model and settings, and merges what comes back; everything that
succeeded the first time is left exactly as it was. Because it works on
the finished object, you can run it later, look at the failures first,
or give it a different `model` for units the original consistently
refuses or cannot fit in its context window. Each pass is recorded in
the object’s metadata, and
[`print()`](https://rdrr.io/r/base/print.html) and the audit trail say
what was backfilled and by which model, so a result coded by two
instruments is disclosed as one.

`filled`` ``<-`` `[`qlm_backfill`](https://quallmer.github.io/quallmer/reference/qlm_backfill.md)`(``incomplete``)`` ``` #> ℹ Leaving 3 units alone: rejected on length, or cut off at `max_tokens`. A ``` ``` #> different `model`, or a higher `params(max_tokens = )`, would retry them. ``` ``#> ℹ Backfill pass 1 of 2: re-coding 1 unit with "anthropic/claude-haiku-4-5".`` ``#> ℹ Recovered 1 unit; 3 still failed.`` ``#> ℹ Nothing recoverable remains.`

The object that call returned is saved with the package too. The
timed-out unit is coded now, the cut-off ones are still listed, and the
header says what was done:

`filled`` ``<-`` ``examples``$``example_coded_backfilled`` ``filled`

    ## # quallmer coded object
    ## # Run:      example_incomplete
    ## # Codebook: Sentiment with evidence
    ## # Model:    anthropic/claude-haiku-4-5
    ## # Units:    8 (5 scored, 3 failed)
    ## # Backfill: 1 pass, recovered 1 of 1
    ## # Notes:    Coded with a deliberately short request timeout and max_tokens = 90, so that the run came back incomplete
    ## 
    ## # A tibble: 8 × 5
    ##   .id          sentiment rating evidence                              .error    
    ##   <chr>        <fct>      <int> <chr>                                 <list>    
    ## 1 3275_2.txt   neg            1 "Lets just say that from now on, we … <NULL>    
    ## 2 3150_1.txt   NA            NA  NA                                   <qllmr_t_>
    ## 3 3918_1.txt   NA            NA  NA                                   <qllmr_t_>
    ## 4 7530_1.txt   neg            1 "\"to call this the next cult classi… <NULL>    
    ## 5 4247_8.txt   pos            7 "One very strange piece of cinema. Y… <NULL>    
    ## 6 7227_7.txt   pos            8 "ah man this movie was funny as hell… <NULL>    
    ## 7 8877_8.txt   pos            9 "The one thing I really can't seem t… <NULL>    
    ## 8 11413_10.txt NA            NA  NA                                   <qllmr_t_>

[`qlm_failures`](https://quallmer.github.io/quallmer/reference/qlm_failures.md)`(``filled``)`

    ## # A tibble: 3 × 3
    ##   .id          reason                                                 .error    
    ##   <chr>        <chr>                                                  <list>    
    ## 1 3150_1.txt   The response used the whole max_tokens limit of 90 an… <qllmr_t_>
    ## 2 3918_1.txt   The response used the whole max_tokens limit of 90 an… <qllmr_t_>
    ## 3 11413_10.txt The response used the whole max_tokens limit of 90 an… <qllmr_t_>

The two are for different failures. Retries catch what a moment’s wait
fixes, in the middle of the run. Backfilling recovers what is left when
the run is over, which for a corpus of any size is usually something.
Two kinds of failure a backfill leaves alone, because re-sending the
same request cannot change the outcome: a text the provider rejected as
longer than the model’s context window, and a response cut off at
`max_tokens`. Those are retried only with a different `model`, or for a
truncated response a higher `params(max_tokens = )`. Content refusals
are retried, since the same text is refused on one pass and coded on the
next.

| Failure | Stage and mechanism | Setting or action |
|----|----|----|
| Rate limit, timeout, or transient server error | ellmer retries the transport request, on every path and for every request quallmer sends | `options(ellmer_max_tries = n)` |
| Unusable response on the JSON path after ellmer’s tries: empty, malformed, refused, schema-invalid, or still failing on transport | quallmer sends the unit again during the run, each request with ellmer’s tries afresh | `json_retries = n` |
| Anything still failed after the run | quallmer makes another pass over the failed units | `backfill = n` in [`qlm_code()`](https://quallmer.github.io/quallmer/reference/qlm_code.md), or `qlm_backfill(..., passes = n)` |
| Input exceeds the model’s context window | Backfill with a larger-context model | `qlm_backfill(..., model = )` |
| Output was cut off at `max_tokens` | Backfill with a higher output limit | `qlm_backfill(..., params = ellmer::params(max_tokens = ))` |

Two settings shape how much there is to backfill. The first is what a
failure does to the rest of the run. By default
[`qlm_code()`](https://quallmer.github.io/quallmer/reference/qlm_code.md)
runs with `on_error = "continue"` on both paths, so every unit is
attempted and only the units that actually failed are left for a
backfill, each with its reason in `.error`. Pass `on_error = "return"`
to stop sending new requests after the first failure and return what
there is, which is ellmer’s own default. On the structured path that is
the whole run: one timeout can then leave most of a corpus uncoded, and
the units never sent carry no `.error`. On the JSON path it is one wave,
since `json_retries` sends the units a wave did not reach in later
waves, each stopped in turn at its first failure, and whatever is still
unsent at the end does carry an `.error`; the run stops after the first
wave only with `json_retries = 0`. The second is
`qlm_code(backfill = 2)`, which runs the passes in the same call, if you
would rather not make them a separate step. Either way, a replication
made with
[`qlm_replicate()`](https://quallmer.github.io/quallmer/reference/qlm_replicate.md)
replays the passes recorded on its parent, so both are complete on the
same terms.

## Step 3: Replicate with a different model

Test reliability by coding again with a different model:

`coded2`` ``<-`` `[`qlm_replicate`](https://quallmer.github.io/quallmer/reference/qlm_replicate.md)`(`` `` ``coded``,`` `` model ``=`` ``"openai/gpt-4o"``,`` `` name ``=`` ``"gpt4o"`` ``)`` `` ``coded2`

## Step 4: Compare results

Assess inter-rater reliability between the two coding runs:

`comparison`` ``<-`` `[`qlm_compare`](https://quallmer.github.io/quallmer/reference/qlm_compare.md)`(``coded``, ``coded2``)`` ``comparison`

If you have gold standard human coding, you can also validate against it
with
[`qlm_validate()`](https://quallmer.github.io/quallmer/reference/qlm_validate.md).

## Step 5: Create an audit trail

Document your complete workflow, including models, parameters, and
results and a Quarto report with replication instructions:

`# View the trail`` ``trail`` ``<-`` `[`qlm_trail`](https://quallmer.github.io/quallmer/reference/qlm_trail.md)`(``coded``, ``coded2``, ``comparison``)`` ``trail`` `` ``# Save trail and generate report`` `[`qlm_trail`](https://quallmer.github.io/quallmer/reference/qlm_trail.md)`(``coded``, ``coded2``, ``comparison``, path ``=`` ``"my_analysis"``)`` ``# Creates: my_analysis.rds, my_analysis.qmd`

This workflow provides a structured approach to leveraging LLMs for
qualitative coding with transparency as well as full traceability and
the ability to replicate and validate your analyses.
