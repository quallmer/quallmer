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

| id         | score | explanation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
|:-----------|------:|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 2013-Obama |     0 | The text emphasizes inclusivity through repeated references to equality, diversity, and collective action. It highlights the importance of equal rights for all citizens, regardless of race, gender, or sexual orientation, and stresses the need for unity and shared responsibility. Phrases like ‘all men are created equal,’ ‘our journey is not complete until our gay brothers and sisters are treated like anyone else under the law,’ and ‘a better way to welcome the striving, hopeful immigrants’ underscore an inclusive ideology. |
| 2017-Trump |     7 | The text emphasizes national homogeneity and prioritizes American interests with phrases like “America first” and “buy American and hire American.” It highlights exclusionary policies such as protecting borders and prioritizing American workers. While it mentions unity and solidarity, the focus on national pride and protectionism suggests a more exclusive stance.                                                                                                                                                                   |
| 2021-Biden |     0 | The text emphasizes unity, inclusion, and the importance of diversity and pluralism. It calls for racial justice, overcoming political extremism, and uniting people across different backgrounds. Phrases like “uniting our people,” “delivering racial justice,” and “reject a culture in which facts themselves are manipulated” highlight an inclusive approach. The focus on “We the People” and “a President for all Americans” further underscores inclusivity.                                                                          |
| 2025-Trump |     8 | The text emphasizes national sovereignty, exclusion of ‘criminal aliens,’ and a focus on American exceptionalism, which aligns with exclusive language. Phrases like ‘put America first,’ ‘halt illegal entry,’ and ‘returning millions of criminal aliens’ highlight exclusionary policies. The mention of ‘only two genders’ and ending ‘socially engineered race and gender’ policies further supports an exclusive stance.                                                                                                                  |

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

| id         | score | explanation                                                                                                                                                                                                                                                                                                                                                                                                                         |
|:-----------|------:|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 2013-Obama |     5 | The text strongly emphasizes inclusivity, highlighting themes of equality, diversity, and collective action. It references historical struggles for civil rights and equality, and advocates for the protection and empowerment of marginalized groups. The language promotes unity and shared responsibility, aligning with inclusive values.                                                                                      |
| 2017-Trump |    -2 | The text emphasizes national homogeneity and prioritizes American interests with phrases like “America first” and “protect our borders.” It highlights exclusionary themes by focusing on American workers and industries, and suggests a withdrawal from global engagement. However, it also includes some inclusive elements, such as unity among Americans of different backgrounds, which moderates the exclusivity.            |
| 2021-Biden |     5 | The text emphasizes unity, inclusion, and the protection of democracy. It calls for racial justice, addresses systemic racism, and promotes the idea of working together as one nation. The language is inclusive, focusing on bringing people together regardless of differences, and highlights the importance of diversity and pluralism.                                                                                        |
| 2025-Trump |    -3 | The speech emphasizes national sovereignty, protection of American borders, and exclusion of ‘criminal aliens,’ which aligns with exclusive language. It also mentions ending policies that socially engineer race and gender, suggesting a move away from diversity initiatives. While there are mentions of unity and inclusion of various American demographics, the overall tone and policy proposals lean towards exclusivity. |

In this example, we demonstrated how to use the
[`task_ideology()`](https://seraphinem.github.io/quallmer/reference/task_ideology.md)
for scaling texts regarding their ideological position on a specified
dimension. We also showed how to customize the task using the
[`task()`](https://seraphinem.github.io/quallmer/reference/task.md)
function for more tailored annotation needs, e.g., changing the scale
from 0-10 to -5 to +5. Now you can apply these techniques to your own
text data for ideological analysis!
