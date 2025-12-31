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
                   model_name = "openai/gpt-4o",
                   params = list(temperature = 0))
```

    ## [working] (0 + 0) -> 3 -> 1 | ■■■■■■■■■                         25%

    ## [working] (0 + 0) -> 0 -> 4 | ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100%

| id         | score | explanation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
|:-----------|------:|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 2013-Obama |     1 | The text emphasizes inclusivity, highlighting themes of equality, diversity, and collective action. It references the importance of equal rights for women, LGBTQ+ individuals, and immigrants, and stresses the need for unity and shared responsibility. Phrases like ‘all men are created equal,’ ‘our journey is not complete until our gay brothers and sisters are treated like anyone else under the law,’ and ‘a better way to welcome the striving, hopeful immigrants’ underscore an inclusive ideology.                           |
| 2017-Trump |     7 | The text emphasizes national homogeneity and prioritizes American interests with phrases like “America first” and “buy American and hire American.” It highlights protectionism and a focus on American workers and borders, suggesting an exclusive stance. However, it also includes some inclusive elements, such as unity and equality among Americans, regardless of race, with statements like “we all bleed the same red blood of patriots.” Overall, the emphasis on national interests and protectionism leans towards exclusivity. |
| 2021-Biden |     0 | The text emphasizes unity, inclusion, and addressing systemic issues like racial justice and political extremism. It calls for treating each other with dignity and respect, and highlights the importance of diversity and pluralism. Phrases like ‘uniting our people,’ ‘delivering racial justice,’ and ‘rejecting a culture in which facts themselves are manipulated’ support an inclusive ideology.                                                                                                                                    |
| 2025-Trump |     8 | The text emphasizes national sovereignty, exclusion of certain groups, and a focus on national homogeneity. Phrases like “put America first,” “reclaim our sovereignty,” and “halt illegal entry” suggest an exclusive stance. The mention of “only two genders” and ending “socially engineered race and gender” policies further supports exclusivity. While there are mentions of unity and diversity, the overall tone and policy proposals lean towards exclusivity.                                                                    |

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
                          model_name = "openai/gpt-4o",
                          params = list(temperature = 0))
```

    ## [working] (0 + 0) -> 3 -> 1 | ■■■■■■■■■                         25%

    ## [working] (0 + 0) -> 0 -> 4 | ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100%

| id         | score | explanation                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
|:-----------|------:|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 2013-Obama |     5 | The text strongly emphasizes inclusivity, highlighting themes of equality, diversity, and collective action. It advocates for equal rights across gender, sexual orientation, and socioeconomic status, and stresses the importance of welcoming immigrants and supporting marginalized groups. The language consistently promotes pluralism and the protection of minorities, aligning with an inclusive ideology.                                                   |
| 2017-Trump |    -2 | The text emphasizes national homogeneity and prioritizes American interests with phrases like “America first” and “protect our borders.” It highlights exclusionary themes by focusing on protecting American jobs and industries from foreign influence. However, it also includes some inclusive elements, such as unity among Americans regardless of race, which moderates the exclusivity slightly.                                                              |
| 2021-Biden |     5 | The text emphasizes unity, inclusion, and the protection of democracy, highlighting themes of racial justice, equality, and the rejection of division. It calls for overcoming political extremism and systemic racism, and promotes a vision of America that is inclusive and united. The language is inclusive, focusing on bringing people together and addressing common challenges collectively.                                                                 |
| 2025-Trump |    -3 | The text emphasizes national sovereignty, border control, and exclusion of ‘criminal aliens,’ which aligns with exclusive language. It also mentions ending policies that socially engineer race and gender, suggesting a move away from diversity and inclusion efforts. While there are mentions of unity and support for various communities, the overall focus on national homogeneity and restrictive policies places it towards the exclusive end of the scale. |

In this example, we demonstrated how to use the
[`task_ideology()`](https://seraphinem.github.io/quallmer/reference/task_ideology.md)
for scaling texts regarding their ideological position on a specified
dimension. We also showed how to customize the task using the
[`task()`](https://seraphinem.github.io/quallmer/reference/task.md)
function for more tailored annotation needs, e.g., changing the scale
from 0-10 to -5 to +5. Now you can apply these techniques to your own
text data for ideological analysis!
