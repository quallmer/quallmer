# Single-file Shiny app with manual coding, LLM checking, and ICR analysis
  suppressPackageStartupMessages({
    library(shiny)
    library(dplyr)
    library(tidyr)
    library(irr)
  })

# -------------------------------
# Helpers
# -------------------------------

na_to_empty <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x
}

read_data_file <- function(path, name) {
  if (grepl("\\.rds$", name, ignore.case = TRUE)) {
    readRDS(path)
  } else if (grepl("\\.csv$", name, ignore.case = TRUE)) {
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  } else {
    stop("Unsupported file type. Please select a .rds or .csv file.")
  }
}

preview_head <- function(df, n = 10) {
  utils::head(df, n)
}

make_long_icr <- function(df, unit_id_col, coder_cols) {
  stopifnot(unit_id_col %in% names(df), all(coder_cols %in% names(df)))
  df %>%
    mutate(unit_id = as.character(.data[[unit_id_col]])) %>%
    select(unit_id, all_of(coder_cols)) %>%
    pivot_longer(
      cols = all_of(coder_cols),
      names_to = "coder_id",
      values_to = "code"
    ) %>%
    mutate(
      coder_id = as.character(coder_id),
      code = as.character(code)
    ) %>%
    select(unit_id, coder_id, code) %>%
    complete(unit_id, coder_id, fill = list(code = NA_character_))
}

filter_units_by_coders <- function(long_df, min_coders = 2L) {
  long_df %>%
    group_by(unit_id) %>%
    filter(sum(!is.na(code)) >= min_coders) %>%
    ungroup()
}

compute_icr_summary <- function(long_df) {
  wide <- long_df %>%
    pivot_wider(names_from = coder_id, values_from = code) %>%
    arrange(unit_id)

  if (!"unit_id" %in% names(wide)) {
    return(data.frame(
      metric = character(), value = character(), stringsAsFactors = FALSE
    ))
  }

  ratings <- wide %>% select(-unit_id)
  n_units <- nrow(ratings)
  n_coders <- ncol(ratings)

  alpha_val <- tryCatch({
    if (n_units > 0 && n_coders >= 2) {
      rmat <- t(as.matrix(ratings))
      out <- irr::kripp.alpha(rmat, method = "nominal")
      unname(out$value)
    } else NA_real_
  }, error = function(e) NA_real_)

  fleiss_val <- tryCatch({
    if (n_units > 0 && n_coders >= 2) {
      comp <- ratings[stats::complete.cases(ratings), , drop = FALSE]
      if (nrow(comp) >= 1) {
        out <- irr::kappam.fleiss(comp)
        unname(out$value)
      } else {
        NA_real_
      }
    } else NA_real_
  }, error = function(e) NA_real_)

  data.frame(
    metric = c("units_included", "coders", "kripp_alpha_nominal", "fleiss_kappa"),
    value = c(n_units, n_coders, round(alpha_val, 4), round(fleiss_val, 4)),
    stringsAsFactors = FALSE
  )
}

# -------------------------------
# Human check module (UI + server)
# -------------------------------
humancheck_ui <- function(id) {
  ns <- NS(id)
  fluidPage(
    tags$head(
      tags$style(HTML("
        /* Make navigation buttons smaller */
        #sidebar-box .btn {
          font-size: 12px !important;   /* smaller text */
          padding: 4px 8px !important;  /* tighter spacing */
          line-height: 1.2 !important;  /* more compact vertically */
        }

        /* Optional: smaller margin between buttons */
        #sidebar-box .btn + .btn {
          margin-left: 2px;
        }

        /* Optional: make all text/buttons uniform */
        #sidebar-box h4,
        #sidebar-box h5,
        #sidebar-box p,
        #sidebar-box label {
          font-size: 13px;
        }

        :root { --panel-height: 200px; --small-box-height: 140px; --max-panel-height: 600px; }

        .box-base {
          background-color: #f8f9fa;
          padding: 10px;
          border-radius: 5px;
          border: 1px solid #dee2e6;
          width: 100%;
          box-sizing: border-box;
          overflow-x: hidden !important;
          overflow-y: auto;
        }

        .box-small { height: var(--small-box-height); }
        .box-tall  { height: var(--panel-height); }

        /* Limit the maximum height of sidebar and main text area */
        #sidebar-box, #main-text-box {
          height: auto;
          max-height: var(--max-panel-height);
          overflow-y: auto;
        }

        #sidebar-box, #main-text-box { height: var(--panel-height); overflow-y: auto; }

        .box-base pre, .box-base {
          white-space: pre-wrap !important;
          word-wrap: break-word !important;
          overflow-wrap: anywhere !important;
          font-family: 'Consolas','Monaco','Courier New',monospace;
          font-size: 12px;
          line-height: 1.2;
          margin-left: 2px;
        }

        .main-panel {
          padding: 10px;
          max-width: 100%;
          overflow-x: hidden;
          margin-right: 5px; /* reduced right margin */
        }

        /* Pastel colors for validation buttons */
        #sidebar-box .btn-success { background-color: #b3e6b3 !important; border-color: #99d699 !important; color: #000; }
        #sidebar-box .btn-danger  { background-color: #f5b3b3 !important; border-color: #e69999 !important; color: #000; }
      ")),
      tags$script(HTML("
        function updateHeights() {
          var sb = document.getElementById('sidebar-box');
          var mp = document.getElementById('main-text-box');
          if (!sb || !mp) return;
          var h1 = sb.scrollHeight || sb.offsetHeight || 0;
          var h2 = mp.scrollHeight || mp.offsetHeight || 0;
          var h = Math.max(h1, h2, 400);
          document.documentElement.style.setProperty('--panel-height', h + 'px');
        }
        window.addEventListener('resize', function(){ setTimeout(updateHeights, 100); });
        document.addEventListener('DOMContentLoaded', function(){ setTimeout(updateHeights, 300); });
        Shiny.addCustomMessageHandler('pingUpdateHeights', function(_) { setTimeout(updateHeights, 100); });
        Shiny.addCustomMessageHandler('getSelectedText', function(message) {
          var selection = window.getSelection().toString();
          Shiny.setInputValue(message.inputId, selection, {priority: 'event'});
        });
      "))
    ),
    sidebarLayout(
      sidebarPanel(
        div(id = "sidebar-box",
            h4(textOutput(ns("navigation_info"))),
            div(class = "document-info",
                tags$strong("Document: "),
                textOutput(ns("document_name"), inline = TRUE)
            ),
            fluidRow(
              column(8, actionButton(ns("jump_last"), "Jump to last coded",
                                     class = "btn btn-primary", width = "100%"))  # same as Save Highlight
            ),
            hr(),
            h5("Metadata"),
            tableOutput(ns("meta_table")),
            hr(),
            conditionalPanel(
              condition = sprintf("output['%s']", ns("has_llm_output")),
              h4("LLM output"),
              div(class = "box-base box-small", verbatimTextOutput(ns("llm_output_display")))
            ),
            conditionalPanel(
              condition = sprintf("output['%s']", ns("has_evidence")),
              h5("LLM evidence"),
              div(class = "box-base box-small", verbatimTextOutput(ns("llm_evidence_display")))
            ),
            hr(),
            conditionalPanel(
              condition = sprintf("output['%s']", ns("show_validation_buttons")),
              fluidRow(
                column(6, actionButton(ns("valid_btn"), "Valid", class = "btn btn-success", width = "100%")),
                column(6, actionButton(ns("invalid_btn"), "Invalid", class = "btn btn-danger", width = "100%"))
              ),
              br(),
              textOutput(ns("status_display")),
              hr()
            ),
            fluidRow(
              column(4, actionButton(ns("prev_text"), "Previous", class = "btn btn-secondary", width = "100%")),
              column(4, actionButton(ns("next_text"), "Next", class = "btn btn-secondary", width = "100%"))
            ),
            br(),
            textAreaInput(ns("comments"), "Comments:", "", width = "100%", height = "80px"),
            actionButton(ns("save_highlight"), "Save Highlight", class = "btn btn-primary"),
            h5("Highlighted examples:"),
            verbatimTextOutput(ns("highlighted_text_display")),
            p("Examples highlighted in the text are saved to new file.",
              style = "font-size: 0.9em; color: #6c757d;")
        )
      ),
      mainPanel(
        div(class = "main-panel",
            h4("Text to assess"),
            div(id = "main-text-box", class = "box-base box-tall", verbatimTextOutput(ns("text_display")))
        )
      )
    ),
    div(class = "footer",
        HTML(paste0(
          "Agreement App made with <span style='color: red;'>", "\u2665", "</span> and ",
          "<a href='https://shiny.posit.co/' target='_blank'>Shiny</a>"
        ))
    )
  )
}


humancheck_server <- function(id, data, text_col, blind,
                              llm_output_col = reactive(NULL),
                              llm_evidence_col = reactive(NULL),
                              original_file_name = reactive("data.csv"),
                              meta_cols = reactive(character())) {
  moduleServer(id, function(input, output, session) {

    rv <- reactiveValues(df = NULL, n = 0L, text_vec = NULL)
    current_index <- reactiveVal(1L)

    save_path <- reactive({
      base <- tools::file_path_sans_ext(req(original_file_name()))
      paste0(base, "_assessed.rds")
    })

    observeEvent(list(data(), text_col(), blind(),
                      llm_output_col(), llm_evidence_col(), original_file_name()), {
                        df <- req(data())
                        txt <- req(text_col())
                        if (!txt %in% names(df)) stop(sprintf("Text column '%s' not found in data.", txt))

                        n_texts <- nrow(df)
                        if (!"comments" %in% names(df)) df$comments <- rep("", n_texts) else df$comments <- na_to_empty(df$comments)
                        if (!"examples" %in% names(df)) df$examples <- rep("", n_texts) else df$examples <- na_to_empty(df$examples)
                        if (!isTRUE(blind()) && !"status" %in% names(df)) df$status <- rep("Unmarked", n_texts)

                        # merge saved progress when available
                        sp <- save_path()
                        if (file.exists(sp)) {
                          saved <- tryCatch(readRDS(sp), error = function(e) NULL)
                          if (!is.null(saved) && nrow(saved) == nrow(df)) {
                            for (nm in intersect(c("comments", "examples", "status"), names(saved))) {
                              df[[nm]] <- na_to_empty(saved[[nm]])
                            }
                          }
                        }

                        rv$df <- df
                        rv$n <- n_texts
                        rv$text_vec <- as.character(df[[txt]])

                        session$sendCustomMessage("pingUpdateHeights", TRUE)
                      }, ignoreInit = FALSE, priority = 10)

    has_llm_output <- reactive({
      !is.null(llm_output_col()) && nzchar(llm_output_col()) && llm_output_col() %in% names(rv$df)
    })
    has_evidence <- reactive({
      !is.null(llm_evidence_col()) && llm_evidence_col() != "None" && nzchar(llm_evidence_col()) && llm_evidence_col() %in% names(rv$df)
    })
    show_buttons <- reactive({ isFALSE(isTRUE(blind())) })

    output$has_llm_output <- reactive({ has_llm_output() })
    outputOptions(output, "has_llm_output", suspendWhenHidden = FALSE)
    output$has_evidence <- reactive({ has_evidence() })
    outputOptions(output, "has_evidence", suspendWhenHidden = FALSE)
    output$show_validation_buttons <- reactive({ show_buttons() })
    outputOptions(output, "show_validation_buttons", suspendWhenHidden = FALSE)

    output$navigation_info <- renderText({
      paste("Document", current_index(), "of", max(1L, rv$n))
    })
    output$document_name <- renderText({ req(original_file_name()) })

    # metadata table for current row
    output$meta_table <- renderTable({
      cols <- meta_cols()
      if (length(cols) == 0 || is.null(rv$df)) return(NULL)
      i <- current_index()
      vals <- vapply(cols, function(c) na_to_empty(rv$df[[c]][i]), character(1))
      data.frame(Field = cols, Value = vals, stringsAsFactors = FALSE)
    }, striped = TRUE, bordered = TRUE, colnames = TRUE)

    # decouple text rendering from df to prevent jumping
    output$text_display <- renderText({
      idx <- current_index()
      na_to_empty(rv$text_vec[idx])
    })
    output$llm_output_display <- renderText({
      if (has_llm_output()) na_to_empty(rv$df[[llm_output_col()]][current_index()]) else ""
    })
    output$llm_evidence_display <- renderText({
      if (has_evidence()) na_to_empty(rv$df[[llm_evidence_col()]][current_index()]) else ""
    })
    output$status_display <- renderText({
      if (show_buttons()) paste("Status:", rv$df$status[current_index()]) else ""
    })

    save_now <- function() {
      try(saveRDS(rv$df, save_path()), silent = TRUE)
    }

    observeEvent(input$comments, {
      i <- current_index()
      if (!is.null(rv$df) && i >= 1 && i <= nrow(rv$df)) {
        rv$df$comments[i] <- na_to_empty(if (is.null(input$comments)) "" else input$comments)
        save_now()
      }
    }, ignoreInit = TRUE)

    observeEvent(input$valid_btn, {
      if (show_buttons()) { rv$df$status[current_index()] <- "Valid"; save_now() }
    })
    observeEvent(input$invalid_btn, {
      if (show_buttons()) { rv$df$status[current_index()] <- "Invalid"; save_now() }
    })

    observeEvent(input$save_highlight, {
      session$sendCustomMessage("getSelectedText", list(inputId = session$ns("highlighted_text")))
    })
    observeEvent(input$highlighted_text, {
      txt <- input$highlighted_text
      if (!is.null(txt) && nzchar(txt)) { rv$df$examples[current_index()] <- txt; save_now() }
    })

    move_and_refresh <- function(to) {
      to <- max(1L, min(to, rv$n))
      current_index(to)
      i <- to
      updateTextAreaInput(session, "comments", value = na_to_empty(rv$df$comments[i]))
      output$highlighted_text_display <- renderText({ na_to_empty(rv$df$examples[i]) })
      output$status_display <- renderText({ if (show_buttons()) paste("Status:", rv$df$status[i]) else "" })
      session$sendCustomMessage("pingUpdateHeights", TRUE)
    }

    observeEvent(input$next_text, { move_and_refresh(current_index() + 1L) })
    observeEvent(input$prev_text, { move_and_refresh(current_index() - 1L) })

    observeEvent(input$jump_last, {
      if (is.null(rv$df) || nrow(rv$df) == 0) return()
      coded <- rep(FALSE, nrow(rv$df))
      if ("status" %in% names(rv$df)) coded <- coded | (!is.na(rv$df$status) & !(rv$df$status %in% c("", "Unmarked")))
      if ("comments" %in% names(rv$df)) coded <- coded | nzchar(na_to_empty(rv$df$comments))
      if ("examples" %in% names(rv$df)) coded <- coded | nzchar(na_to_empty(rv$df$examples))
      idx <- if (any(coded)) max(which(coded)) else 1L
      move_and_refresh(idx)
    })

    observe({ if (rv$n >= 1) move_and_refresh(1L) })
  })
}

# -------------------------------
# Main App
# -------------------------------

agreement_app <- function() {
  ui <- fluidPage(
    titlePanel("Agreement App"),
    sidebarLayout(
      sidebarPanel(
        width = 3,
        h4("1. Select a data file"),
        fileInput("file", "Choose a data file (.rds or .csv):",
                  accept = c(".rds", ".csv")),
        hr(),
        h4("2. Choose mode"),
        radioButtons("mode", "Mode:",
                     choices = c(
                       "Manual coding (blind)" = "blind",
                       "Checking LLM outputs" = "llm",
                       "Calculate agreement scores" = "agreement"
                     ),
                     selected = "blind"),
        hr(),
        uiOutput("column_selectors"),
        br(),
        helpText("All changes will be automatically saved to a new file in your working directory with the ending _assessed.rds.")
      ),
      mainPanel(
        uiOutput("main_content")
      )
    )
  )

  server <- function(input, output, session) {
    dataset <- reactiveVal(NULL)
    last_file <- reactiveVal(NULL)

    # -----------------------
    # Load last-used file if exists
    # -----------------------
    observe({
      if (is.null(dataset()) && file.exists(".last_file.txt")) {
        lf <- readLines(".last_file.txt", warn = FALSE)
        if (length(lf) == 1 && file.exists(lf)) {
          df <- tryCatch(read_data_file(lf, basename(lf)),
                         error = function(e) { showNotification(e$message, type = "error"); NULL })
          if (!is.null(df)) {
            dataset(df)
            last_file(lf)
            showNotification(paste("Loaded previous file:", basename(lf)), type = "message")
          }
        }
      }
    })

    # -----------------------
    # File input observer
    # -----------------------
    observeEvent(input$file, {
      req(input$file)
      df <- tryCatch(read_data_file(input$file$datapath, input$file$name),
                     error = function(e) { showNotification(e$message, type = "error"); NULL })
      if (!is.null(df)) {
        dataset(df)
        last_file(input$file$datapath)
        writeLines(input$file$datapath, ".last_file.txt")
      }
    }, ignoreInit = TRUE)

    # -----------------------
    # Column selectors UI
    # -----------------------
    output$column_selectors <- renderUI({
      req(dataset())
      cols <- names(dataset())
      mode <- input$mode
      tagList(
        h4("3. Select columns"),
        if (mode != "agreement")
          selectInput("text_col", "Text column:", choices = cols),
        if (mode == "blind")
          selectInput("meta_cols", "Metadata columns (optional):", choices = cols, multiple = TRUE),
        if (mode == "llm") tagList(
          selectInput("llm_output_col", "LLM output column:", choices = cols),
          selectInput("llm_evidence_col", "LLM evidence column (optional):",
                      choices = c("None", cols), selected = "None")
        ),
        if (mode == "agreement") tagList(
          selectInput("unit_id_col", "Unit ID column:", choices = cols),
          selectInput("coder_cols", "Coder columns (multiple):", choices = cols, multiple = TRUE)
        )
      )
    })

    # -----------------------
    # Main content UI
    # -----------------------
    output$main_content <- renderUI({
      if (is.null(dataset())) {
        tagList(
          h3("Welcome to the Agreement App"),
          p("Step 1: Choose a file"),
          p("Step 2: Select mode"),
          p("Step 3: Select appropriate columns."),
          hr(),
          h4("File Preview:"),
          tableOutput("data_preview")
        )
      } else if (input$mode %in% c("blind", "llm")) {
        humancheck_ui("hc")
      } else if (input$mode == "agreement") {
        tagList(
          h4("Agreement scores:"),
          tableOutput("icr_summary"),
          downloadButton("export_icr", "Export agreement scores")
        )
      }
    })

    # -----------------------
    # Data preview
    # -----------------------
    output$data_preview <- renderTable({
      req(dataset()); preview_head(dataset())
    })

    # -----------------------
    # Human check server
    # -----------------------
    observe({
      req(dataset(), input$mode %in% c("blind", "llm"), input$text_col)
      humancheck_server(
        id = "hc",
        data = reactive({
          df <- dataset()
          sp <- paste0(tools::file_path_sans_ext(last_file()), "_assessed.rds")
          if (file.exists(sp)) {
            saved <- tryCatch(readRDS(sp), error = function(e) NULL)
            if (!is.null(saved) && nrow(saved) == nrow(df)) {
              for (nm in intersect(c("comments","examples","status"), names(saved))) {
                df[[nm]] <- na_to_empty(saved[[nm]])
              }
            }
          }
          df
        }),
        text_col = reactive(req(input$text_col)),
        blind = reactive(input$mode == "blind"),
        llm_output_col = reactive(if (input$mode == "llm") req(input$llm_output_col) else NULL),
        llm_evidence_col = reactive({
          if (input$mode == "llm") {
            col <- req(input$llm_evidence_col)
            if (identical(col, "None")) NULL else col
          } else NULL
        }),
        original_file_name = reactive(if (!is.null(last_file())) basename(last_file()) else "data.csv"),
        meta_cols = reactive(if (input$mode == "blind") input$meta_cols else character())
      )
    })

    # -----------------------
    # Agreement mode server
    # -----------------------
    observe({
      req(dataset(), input$mode == "agreement")
      req(input$unit_id_col, input$coder_cols, length(input$coder_cols) >= 2)
      df <- dataset()
      long_data <- make_long_icr(df, unit_id_col = input$unit_id_col, coder_cols = input$coder_cols)
      long_filtered <- filter_units_by_coders(long_data, min_coders = 2L)

      if (nrow(long_filtered) == 0) {
        output$icr_summary <- renderTable({
          data.frame(metric = "message",
                     value = "No units have at least 2 coders. Cannot compute agreement.",
                     stringsAsFactors = FALSE)
        }, striped = TRUE, bordered = TRUE)
        output$export_icr <- downloadHandler(
          filename = function() "icr_results.csv",
          content = function(file) utils::write.csv(
            data.frame(metric = "message", value = "No units to compute", stringsAsFactors = FALSE),
            file, row.names = FALSE
          )
        )
      } else {
        icr <- compute_icr_summary(long_filtered)
        output$icr_summary <- renderTable(icr, striped = TRUE, bordered = TRUE)
        output$export_icr <- downloadHandler(
          filename = function() "icr_results.csv",
          content = function(file) utils::write.csv(icr, file, row.names = FALSE)
        )
      }
    })
  }

  shinyApp(ui, server)
}

# Run the app if executed directly
if (identical(environment(), globalenv()) && !length(commandArgs(trailingOnly = TRUE))) {
  agreement_app()
}
