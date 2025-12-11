# Example: Ideology detection

The
[`annotate()`](https://seraphinem.github.io/quallmer/reference/annotate.md)
function with a predefined
[`task_ideology()`](https://seraphinem.github.io/quallmer/reference/task_ideology.md)
allows you to perform ideological scaling (0-10) on texts regarding a
specified ideological dimension. In this example, we will demonstrate
how to use the
[`task_ideology()`](https://seraphinem.github.io/quallmer/reference/task_ideology.md)
for ideology detection on a sample corpus of innaugural speeches from
U.S. presidents. We will use the dimension “inclusive–exclusive” as an
example. To refine the task, we will also provide a definition of the
dimension (optional).

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

### Using `annotate()` for ideological scaling of texts

``` r
# Define ideological dimension
dimension <- "inclusive–exclusive"
# Provide definition for the dimension
definition <- "Inclusive language emphasizes equal rights, diversity, pluralism, 
and protection of minorities, whereas exclusive language emphasizes exclusion 
of groups, national homogeneity, and restricting rights."
# Apply predefined ideology task with task_ideology() in the annotate() function
result <- annotate(data_corpus_inaugural, task = task_ideology(dimension, definition), 
                   chat_fn = chat_openai, model = "gpt-4o",
                   api_args = list(temperature = 0))
```

    ## Running task 'Ideological scaling' using model: gpt-4o

    ## [working] (0 + 0) -> 3 -> 1 | ■■■■■■■■■                         25%

    ## [working] (0 + 0) -> 0 -> 4 | ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100%

| id         | score | explanation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
|:-----------|------:|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 2013-Obama |     1 | The text emphasizes inclusivity through references to equality, diversity, and collective action. It highlights the importance of equal rights for all citizens, regardless of background, and stresses the need for unity and shared responsibility. Phrases like ‘all men are created equal,’ ‘diversity and openness,’ and ‘our journey is not complete until our gay brothers and sisters are treated like anyone else under the law’ underscore an inclusive ideology.                                                                           |
| 2017-Trump |     7 | The text emphasizes national homogeneity and prioritizes American interests with phrases like “America first” and “buy American and hire American.” It highlights protectionism and a focus on American workers and borders, suggesting an exclusive stance. However, it also includes some inclusive elements, such as unity and equality among Americans, regardless of race, with statements like “we all bleed the same red blood of patriots.” Overall, the emphasis on national exclusivity and protectionism outweighs the inclusive rhetoric. |
| 2021-Biden |     0 | The text emphasizes unity, inclusion, and the importance of diversity and pluralism. It calls for overcoming division, addressing racial justice, and uniting against common challenges. Phrases like “uniting our people,” “delivering racial justice,” and “seeing each other not as adversaries but as neighbors” highlight an inclusive approach.                                                                                                                                                                                                 |
| 2025-Trump |     8 | The text emphasizes national sovereignty, exclusion of certain groups, and a focus on national homogeneity. Phrases like “put America first,” “reclaim our sovereignty,” and “halt illegal entry” suggest an exclusive stance. The mention of “only two genders” and ending “socially engineered race and gender” policies further supports exclusivity. While there are mentions of unity and diversity, the overall tone and policy proposals lean towards exclusivity.                                                                             |

### Adjusting the ideology scaling task

You can customize the ideological scaling task by defining your own task
with [`task()`](https://seraphinem.github.io/quallmer/reference/task.md)
(for a more detailed explanation, [see our “Defining custom tasks”
tutorial](https://seraphinem.github.io/quallmer/articles/pkgdown/tutorials/customtask.html)).
For example, you might like to change the scale from 0-10 to -5 to +5.

``` r
custom_ideology <- task(
    name = "Ideological scaling",
    system_prompt = paste0(
      "You are an expert political scientist performing ideological text scaling.",
      "Task:",
      "- Read each short text carefully.",
      "- Place the text on a -5 to +5 scale for the following ideological dimension: ",
      dimension, 
      definition
    ),
    type_def = ellmer::type_object(
      score       = ellmer::type_integer("Ideological position on the specified dimension (0–10, where -5 = first pole, +5 = second pole)"),
      explanation = ellmer::type_string("Brief justification for the assigned score, referring to specific elements in the text")
    ),
    input_type = "text"
  )
# Apply the custom task
custom_result <- annotate(data_corpus_inaugural, task = custom_ideology, 
                          chat_fn = chat_openai, model = "gpt-4o",
                          api_args = list(temperature = 0))
```

    ## Running task 'Ideological scaling' using model: gpt-4o

    ## [working] (0 + 0) -> 3 -> 1 | ■■■■■■■■■                         25%

    ## [working] (0 + 0) -> 0 -> 4 | ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100%

| id         | score | explanation                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
|:-----------|------:|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 2013-Obama |     5 | The text strongly emphasizes inclusive language, focusing on equality, diversity, and collective action. It highlights the importance of equal rights for all citizens, regardless of race, gender, or sexual orientation, and stresses the need for unity and shared responsibility. The speech advocates for the protection of minorities and the vulnerable, and promotes a vision of America that is open, diverse, and committed to ensuring equal opportunities for all. |
| 2017-Trump |    -2 | The text emphasizes national homogeneity and prioritizes American interests with phrases like “America first” and “protect our borders.” It focuses on American workers and industries, suggesting an exclusive approach. However, it also includes some inclusive elements, such as unity and equality among Americans, regardless of race. Overall, the emphasis on national protection and prioritization of American interests leans towards exclusivity.                  |
| 2021-Biden |     5 | The text emphasizes unity, inclusion, and the protection of democracy. It calls for racial justice, addresses systemic racism, and promotes the idea of working together as one nation. The language is inclusive, focusing on bringing people together regardless of differences, and highlights the importance of diversity and pluralism.                                                                                                                                   |
| 2025-Trump |    -3 | The text emphasizes national sovereignty, border control, and exclusionary policies such as halting illegal entry and returning ‘criminal aliens.’ It also mentions ending government policies on race and gender, suggesting a move towards a more exclusive, homogeneous national identity. While there are mentions of unity and inclusion of various American communities, the overall tone and specific policies lean towards exclusivity.                                |

In this example, we demonstrated how to use the
[`task_ideology()`](https://seraphinem.github.io/quallmer/reference/task_ideology.md)
for scaling texts regarding their ideological position on a specified
dimension. We also showed how to customize the task using the
[`task()`](https://seraphinem.github.io/quallmer/reference/task.md)
function for more tailored annotation needs, e.g., changing the scale
from 0-10 to -5 to +5. Now you can apply these techniques to your own
text data for ideological analysis!
