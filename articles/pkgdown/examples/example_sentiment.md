# Example: Sentiment analysis

This example demonstrates sentiment analysis of movie reviews using
[`qlm_code()`](https://quallmer.github.io/quallmer/reference/qlm_code.md)
with the predefined `data_codebook_sentiment` codebook. We’ll analyze
reviews from the Large Movie Review Dataset (Maas et al. 2011) and
validate the results against movie ratings and polarity assigned by the
people who left these reviews, from the original dataset.

## Loading packages and data

[`library`](https://rdrr.io/r/base/library.html)`(``quanteda.tidy``)`

    ## Loading required package: quanteda

    ## Package version: 4.5.0
    ## Unicode version: 14.0
    ## ICU version: 71.1

    ## Parallel computing: 10 of 10 threads used.

    ## See https://quanteda.io for tutorials and examples.

    ## 
    ## Attaching package: 'quanteda.tidy'

    ## The following object is masked from 'package:stats':
    ## 
    ##     filter

[`library`](https://rdrr.io/r/base/library.html)`(`[`dplyr`](https://dplyr.tidyverse.org)`)`

    ## 
    ## Attaching package: 'dplyr'

    ## The following object is masked from 'package:quanteda.tidy':
    ## 
    ##     add_tally

    ## The following objects are masked from 'package:stats':
    ## 
    ##     filter, lag

    ## The following objects are masked from 'package:base':
    ## 
    ##     intersect, setdiff, setequal, union

[`library`](https://rdrr.io/r/base/library.html)`(`[`tidyr`](https://tidyr.tidyverse.org)`)`` `[`library`](https://rdrr.io/r/base/library.html)`(`[`quallmer`](https://quallmer.github.io/quallmer/)`)`

    ## Loading required package: ellmer

`# inspect the labelled data`` `[`convert`](https://quanteda.io/reference/convert.html)`(``data_corpus_LMRDsample``)`` `[`%>%`](https://magrittr.tidyverse.org/reference/pipe.html)` `` `[`count`](https://dplyr.tidyverse.org/reference/count.html)`(``polarity``, ``rating``)`` `[`%>%`](https://magrittr.tidyverse.org/reference/pipe.html)` `` `[`pivot_wider`](https://tidyr.tidyverse.org/reference/pivot_wider.html)`(``names_from ``=`` ``polarity``, values_from ``=`` ``n``, values_fill ``=`` ``0``)`` `[`%>%`](https://magrittr.tidyverse.org/reference/pipe.html)` `` ``janitor``::`[`adorn_totals`](https://sfirke.github.io/janitor/reference/adorn_totals.html)`(``"row"``)`

    ##  rating neg pos
    ##       1  43   0
    ##       2  18   0
    ##       3  20   0
    ##       4  19   0
    ##       7   0  22
    ##       8   0  20
    ##       9   0  22
    ##      10   0  36
    ##   Total 100 100

## Inspecting the codebook

The `data_codebook_sentiment` codebook provides structured sentiment
analysis. Let’s examine its components:

`# View the codebook name and role`` `[`cat`](https://rdrr.io/r/base/cat.html)`(``"Codebook name:"``, ``data_codebook_sentiment``$``name``, ``"\n\n"``)`

    ## Codebook name: Sentiment analysis

[`cat`](https://rdrr.io/r/base/cat.html)`(``"Role:"``, ``data_codebook_sentiment``$``role``, ``"\n\n"``)`

    ## Role: You are a political communication analyst evaluating public statements.

`# View the instructions`` `[`cat`](https://rdrr.io/r/base/cat.html)`(``"Instructions:\n"``, ``data_codebook_sentiment``$``instructions``, ``"\n\n"``)`

    ## Instructions:
    ##  Analyze the sentiment of this text, on both a 1-10 scale and as a polarity of negative or positive.

`# View the schema structure`` `[`cat`](https://rdrr.io/r/base/cat.html)`(``"Schema:\n"``)`

    ## Schema:

[`print`](https://rdrr.io/r/base/print.html)`(``data_codebook_sentiment``$``schema``)`

    ## <ellmer::TypeObject>
    ##  @ description          : NULL
    ##  @ required             : logi TRUE
    ##  @ properties           :List of 2
    ##  .. $ sentiment: <ellmer::TypeEnum>
    ##  ..  ..@ description: chr "Overall sentiment polarity: negative (neg) or positive (pos)"
    ##  ..  ..@ required   : logi TRUE
    ##  ..  ..@ values     : chr [1:2] "neg" "pos"
    ##  .. $ rating   : <ellmer::TypeBasic>
    ##  ..  ..@ description: chr "Sentiment rating from 1 (most negative) to 10 (most positive)"
    ##  ..  ..@ required   : logi TRUE
    ##  ..  ..@ type       : chr "integer"
    ##  @ additional_properties: logi FALSE

The codebook produces two outputs: - `polarity`: Categorical sentiment
(negative or positive) - `rating`: Numeric sentiment rating from 1 (most
negative) to 10 (most positive)

## Coding movie reviews using Gemini 2.5 Flash

`# Apply sentiment analysis using qlm_code()`` ``coded_g2.5_flash`` ``<-`` `[`qlm_code`](https://quallmer.github.io/quallmer/reference/qlm_code.md)`(`` `` ``data_corpus_LMRDsample``,`` `` codebook ``=`` ``data_codebook_sentiment``,`` `` model ``=`` ``"google_gemini/gemini-2.5-flash"``,`` `` max_active ``=`` ``20``,`` `` include_cost ``=`` ``TRUE``,`` `` params ``=`` `[`params`](https://ellmer.tidyverse.org/reference/params.html)`(``temperature ``=`` ``0``)`` ``)`

Total cost:

[`cat`](https://rdrr.io/r/base/cat.html)`(``"Total cost: $"``, `[`round`](https://rdrr.io/r/base/Round.html)`(`[`sum`](https://rdrr.io/r/base/sum.html)`(``coded_g2.5_flash``$``cost``)``, ``4``)``, sep ``=`` ``""``)`

    ## Total cost: $0.2478

## Validating against gold standard

The corpus includes human-coded sentiment labels in its docvars. We can
use
[`qlm_validate()`](https://quallmer.github.io/quallmer/reference/qlm_validate.md)
to assess the LLM’s performance:

`# Extract gold standard labels from corpus docvars`` ``# The docvars include both 'polarity' (neg/pos) and 'rating' (1-10)`` ``gold_standard`` ``<-`` ``data_corpus_LMRDsample`` ``|>`` `` `[`mutate`](https://dplyr.tidyverse.org/reference/mutate.html)`(``.id ``=`` `[`docnames`](https://quanteda.io/reference/docnames.html)`(``data_corpus_LMRDsample``)``)`` ``|>`` `` `[`docvars`](https://quanteda.io/reference/docvars.html)`(``)`` `` ``# Validate polarity predictions (nominal data)`` ``polarity_validation`` ``<-`` `[`qlm_validate`](https://quallmer.github.io/quallmer/reference/qlm_validate.md)`(`` `` ``coded_g2.5_flash``,`` `` gold ``=`` ``gold_standard``,`` `` by ``=`` ``"polarity"``,`` `` level ``=`` ``"nominal"`` ``)`

    ## ℹ Converting `gold` to <as_qlm_coded> object.
    ## ℹ Use `as_qlm_coded()` directly to provide coder names and metadata.

[`print`](https://rdrr.io/r/base/print.html)`(``polarity_validation``)`

    ## 
    ## ── quallmer validation ──
    ## 
    ## n: 200
    ## 
    ## 
    ## ── polarity (nominal) 
    ## By class:
    ## <macro>:
    ## accuracy: 0.9500
    ## precision: 0.9500
    ## recall: 0.9500
    ## F1: 0.9500
    ## Cohen's kappa: 0.9000

`# Validate rating predictions (ordinal data)`` ``rating_validation`` ``<-`` `[`qlm_validate`](https://quallmer.github.io/quallmer/reference/qlm_validate.md)`(`` `` ``coded_g2.5_flash``,`` `` gold ``=`` ``gold_standard``,`` `` by ``=`` ``"rating"``,`` `` level ``=`` ``"ordinal"`` ``)`

    ## ℹ Converting `gold` to <as_qlm_coded> object.
    ## ℹ Use `as_qlm_coded()` directly to provide coder names and metadata.

[`print`](https://rdrr.io/r/base/print.html)`(``rating_validation``)`

    ## 
    ## ── quallmer validation ──
    ## 
    ## n: 200
    ## 
    ## 
    ## ── rating (ordinal) 
    ## Spearman's rho: 0.9109
    ## Kendall's tau: 0.8132
    ## MAE: 0.7600

If we were to treat the `rating` variable as interval, then we get these
validation metrics:

[`qlm_validate`](https://quallmer.github.io/quallmer/reference/qlm_validate.md)`(`` `` ``coded_g2.5_flash``,`` `` gold ``=`` ``gold_standard``,`` `` by ``=`` ``"rating"``,`` `` level ``=`` ``"interval"`` ``)`

    ## ℹ Converting `gold` to <as_qlm_coded> object.
    ## ℹ Use `as_qlm_coded()` directly to provide coder names and metadata.
    ## 
    ## 
    ## ── quallmer validation ──
    ## 
    ## 
    ## 
    ## n: 200
    ## 
    ## 
    ## 
    ## 
    ## 
    ## ── rating (interval) 
    ## 
    ## Pearson's r: 0.9368
    ## 
    ## MAE: 0.7600
    ## 
    ## RMSE: 1.2845
    ## 
    ## ICC: 0.9350

## Comparing to a second LLM coding from GPT-5.1

### Compared to the previous LLM scoring

We can use
[`qlm_compare()`](https://quallmer.github.io/quallmer/reference/qlm_compare.md)
to try a more advanced model, to see how this changes things, comparing
its performance to the previous model, and also to the gold standard.

`# Apply sentiment analysis using qlm_code()`` ``coded_gpt5.1`` ``<-`` `[`qlm_code`](https://quallmer.github.io/quallmer/reference/qlm_code.md)`(`` `` ``data_corpus_LMRDsample``,`` `` codebook ``=`` ``data_codebook_sentiment``,`` `` model ``=`` ``"openai/gpt-5.1"``,`` `` max_active ``=`` ``10``,`` `` include_cost ``=`` ``TRUE``,`` `` params ``=`` `[`params`](https://ellmer.tidyverse.org/reference/params.html)`(``temperature ``=`` ``0``)`` ``)`

Now we can compare the agreement between the two LLM codings, for
polarity:

[`qlm_compare`](https://quallmer.github.io/quallmer/reference/qlm_compare.md)`(``coded_g2.5_flash``, ``coded_gpt5.1``, by ``=`` ``"polarity"``, level ``=`` ``"nominal"``)`

    ## 

    ## ── Inter-rater reliability ──

    ## 

    ## Subjects: 200

    ## Raters: 2

    ## 

    ## ── polarity (nominal)

    ## Percent agreement     0.9750 
    ## Krippendorff's alpha  0.9501 
    ## Kappa                 0.9500

    ## 

For the numerical (1-10) variable for rating, we can specify the level
as ordinal:

[`qlm_compare`](https://quallmer.github.io/quallmer/reference/qlm_compare.md)`(``coded_g2.5_flash``, ``coded_gpt5.1``, by ``=`` ``"rating"``, level ``=`` ``"ordinal"``)`

    ## 

    ## ── Inter-rater reliability ──

    ## 

    ## Subjects: 200

    ## Raters: 2

    ## 

    ## ── rating (ordinal)

    ## Percent agreement     0.5900 
    ## Krippendorff's alpha  0.9443 
    ## Weighted kappa        0.9742 
    ## Kendall's W           0.9805 
    ## Spearman's rho        0.9609

    ## 

If we change the tolerance for agreement, we see that agreement changes
but that no other measures do:

[`qlm_compare`](https://quallmer.github.io/quallmer/reference/qlm_compare.md)`(``coded_g2.5_flash``, ``coded_gpt5.1``, by ``=`` ``"rating"``, level ``=`` ``"ordinal"``,`` `` tolerance ``=`` ``1``)`

    ## 

    ## ── Inter-rater reliability ──

    ## 

    ## Subjects: 200

    ## Raters: 2

    ## 

    ## ── rating (ordinal)

    ## Percent agreement     0.9700 
    ## Krippendorff's alpha  0.9443 
    ## Weighted kappa        0.9742 
    ## Kendall's W           0.9805 
    ## Spearman's rho        0.9609

    ## 

If we treat the 1-10 ratings as interval, then we see:

[`qlm_compare`](https://quallmer.github.io/quallmer/reference/qlm_compare.md)`(``coded_g2.5_flash``, ``coded_gpt5.1``, by ``=`` ``"rating"``, level ``=`` ``"interval"``)`

    ## 

    ## ── Inter-rater reliability ──

    ## 

    ## Subjects: 200

    ## Raters: 2

    ## 

    ## ── rating (interval)

    ## Percent agreement     0.5900 
    ## Krippendorff's alpha  0.9743 
    ## ICC                   0.9744 
    ## Pearson's r           0.9793

    ## 

### GPT-5.1 versus the “gold standard”

Finally, we can compare the new LLM scoring to the gold standard, for
polarity:

[`qlm_validate`](https://quallmer.github.io/quallmer/reference/qlm_validate.md)`(`` `` ``coded_gpt5.1``,`` `` gold ``=`` ``gold_standard``,`` `` by ``=`` ``"polarity"``,`` `` level ``=`` ``"nominal"`` ``)`

    ## ℹ Converting `gold` to <as_qlm_coded> object.
    ## ℹ Use `as_qlm_coded()` directly to provide coder names and metadata.
    ## 
    ## 
    ## ── quallmer validation ──
    ## 
    ## 
    ## 
    ## n: 200
    ## 
    ## 
    ## 
    ## 
    ## 
    ## ── polarity (nominal) 
    ## 
    ## By class:
    ## 
    ## <macro>:
    ## 
    ## accuracy: 0.9550
    ## 
    ## precision: 0.9561
    ## 
    ## recall: 0.9550
    ## 
    ## F1: 0.9550
    ## 
    ## Cohen's kappa: 0.9100

Compare this to the previous values from Gemini 2.5 Flash:

    ## ℹ Converting `gold` to <as_qlm_coded> object.
    ## ℹ Use `as_qlm_coded()` directly to provide coder names and metadata.
    ## 
    ## 
    ## ── quallmer validation ──
    ## 
    ## 
    ## 
    ## n: 200
    ## 
    ## 
    ## 
    ## 
    ## 
    ## ── polarity (nominal) 
    ## 
    ## By class:
    ## 
    ## <macro>:
    ## 
    ## accuracy: 0.9500
    ## 
    ## precision: 0.9500
    ## 
    ## recall: 0.9500
    ## 
    ## F1: 0.9500
    ## 
    ## Cohen's kappa: 0.9000

That’s only a tiny improvement.

For the interval rating:

[`qlm_validate`](https://quallmer.github.io/quallmer/reference/qlm_validate.md)`(`` `` ``coded_gpt5.1``,`` `` gold ``=`` ``gold_standard``,`` `` by ``=`` ``"rating"``,`` `` level ``=`` ``"interval"`` ``)`

    ## ℹ Converting `gold` to <as_qlm_coded> object.
    ## ℹ Use `as_qlm_coded()` directly to provide coder names and metadata.
    ## 
    ## 
    ## ── quallmer validation ──
    ## 
    ## 
    ## 
    ## n: 200
    ## 
    ## 
    ## 
    ## 
    ## 
    ## ── rating (interval) 
    ## 
    ## Pearson's r: 0.9355
    ## 
    ## MAE: 0.7600
    ## 
    ## RMSE: 1.2329
    ## 
    ## ICC: 0.9346

Compared to Gemini 2.5 Flash:

    ## ℹ Converting `gold` to <as_qlm_coded> object.
    ## ℹ Use `as_qlm_coded()` directly to provide coder names and metadata.
    ## 
    ## 
    ## ── quallmer validation ──
    ## 
    ## 
    ## 
    ## n: 200
    ## 
    ## 
    ## 
    ## 
    ## 
    ## ── rating (interval) 
    ## 
    ## Pearson's r: 0.9368
    ## 
    ## MAE: 0.7600
    ## 
    ## RMSE: 1.2845
    ## 
    ## ICC: 0.9350

Call it a draw!
