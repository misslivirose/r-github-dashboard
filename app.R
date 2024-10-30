# Basic GitHub Dashboard
# Author: MissLiviRose
# License: Mozilla Public License 2.0
# A basic dashboard for viewing GitHub projects

# Import the libraries that we want to use
# install.packages('library') if not installed on system
library(shiny)
library(rvest)
library(reactable)
library(shinythemes)
library(stringr)
library(ggplot2)
library(bslib)
library(scales)

# Set up the tibble from a CSV file of the projects we want to include
projects <- read.csv('projects-of-interest.csv')
metrics <- c('description', 'stars', 'forks', 'contributors', 'issues')
projects[ , metrics] <- NA
projects$contributors <- 1

# Iterate over the list of repositories to populate our data frame
repositories <- as.list(projects$repository)
for (p in repositories) {
  # Create the full repository URL
  url <- paste('https://github.com/', p, sep="")
  # Read in the HTML of the GitHub repository page
  html <- read_html(url)
  
  # Extract the description of the project from the HTML node
  projects[projects$repository == p, ]$description <- html |> 
    html_node('div.Layout-sidebar') |> 
    html_node('p.f4') |> 
    html_text(trim = TRUE)  # Extract text, trim to remove extra spaces
  
  # Extract the stars, forks, and issues as integer values from the GitHub repository page
  projects[projects$repository == p, ]$stars <- as.integer(gsub(',', '', as.character(html |> html_node('#repo-stars-counter-star') |> html_attr('title'))))
  projects[projects$repository == p, ]$forks <- as.integer(gsub(',', '', as.character(html |> html_node('#repo-network-counter') |> html_attr('title'))))
  projects[projects$repository == p, ]$issues <- as.integer(gsub(',', '', as.character(html |> html_node('#issues-repo-tab-count') |> html_attr('title'))))
  
  # Get the collaborators from the GitHub repository page. If there is no html node for contributors, return 1
  collaborators <- html |> html_node('div.Layout-sidebar') |> html_nodes("[href*=contributors]")
  tryCatch(
    projects[projects$repository == p, ]$contributors <- as.integer(
      gsub(',', '', as.character(collaborators[[1]] |> html_nodes('span.ml-1') |>  html_attr('title')))), 
    error = function(e){projects[projects$repository == p, ]$contributors <- as.integer(1)}
  )
}

# Create the dashboard UI
ui <- page_navbar(
  # In-line CSS styling for now, TODO move to a separate file
  tags$head(
    tags$style(HTML(
      '
       @import url("https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:ital,wght@0,100;0,200;0,300;0,400;0,500;0,600;0,700;1,100;1,200;1,300;1,400;1,500;1,600;1,700&display=swap");
        a {
          font-size: small;
          margin-top: -16px;
          color: #00d230;
        } 
        .card-header {
          background-color: #161616;
          color: #FFFFFF;
        }
        body {
          font-family: "IBM Plex Sans", sans-serif;
        }
      '
    ))
  ), 
  # Set up the header of the page and nest our pages for each data view we want to include
  title='Builders Data Dashboard',
  # Card view of the GitHub repositories, formatted
  nav_panel(title='GitHub Repositories', 
            mainPanel(
              width=12,
              fluidRow(
                uiOutput("cards")
            )
        )
    ), 
  # Data table view of the GitHub information as an interactive element
  nav_panel(title='Data Table', 
            mainPanel(
              width = 12,
              reactableOutput(
                outputId='data'
              )
            )), 
  # Plots / charts from the data as an interactive element
  nav_panel(title='Project Graphs', 
            mainPanel(
              width = 12, 
              plotly::plotlyOutput(
                outputId='project_plot'
              )
            ))
)
# Set up the application server
server <- function(input, output, session) {
  
  # Render the UI for card view for our repositories
  output$cards <- renderUI({
    lapply(1:nrow(projects), function(i) {
      column(
        width = 4, 
        div(style = "margin: 15px",
      card(
        card_header(projects$project[i]),  # Project name
        textOutput(paste0("description_", i)), # Project description
        uiOutput(paste0("url_", i)),     # Repository URL
        textOutput(paste0("stars_", i)),   # Stars
        textOutput(paste0("forks_", i)),   # Forks
        textOutput(paste0("contributors_", i))  # Contributors
      )
        )
      )
    })
  })
  lapply(1:nrow(projects), function(i) {
    output[[paste0("description_", i)]] <- renderText({projects$description[i]})
    output[[paste0("url_", i)]] <- renderUI({ 
      a(href = paste('https://github.com/', projects$repository[i], sep=""), projects$repository[i], target='_blank') })
    output[[paste0("stars_", i)]] <- renderText({ paste('Stars:', comma(projects$stars[i])) })
    output[[paste0("forks_", i)]] <- renderText({ paste('Forks:', comma(projects$forks[i])) })
    output[[paste0("contributors_", i)]] <- renderText({ paste('Contributors:', comma(projects$contributors[i])) })
  })
  
  # Render the reactable data table
  output$data <- renderReactable(
    reactable(projects, 
              defaultColDef = colDef(
                header = function(value) str_to_title(value),
                minWidth = 60, 
                align = 'left', 
                headerStyle = list(background = '#f7f7f8')
              ),
              columns = list(
                tag = colDef(minWidth = 70),
                project = colDef(minWidth = 120),
                repository = colDef(minWidth = 120),
                description = colDef(minWidth = 120),
                stars = colDef(cell = function(value) comma(value)),
                forks = colDef(cell = function(value) comma(value)),
                contributors = colDef(name = '# of Contributors'), 
                issues = colDef(name = 'Open Issues')
              ),
              bordered = TRUE,
              highlight = TRUE, 
              searchable = TRUE, 
              showPageSizeOptions = TRUE, 
              pageSizeOptions = c(5, 10, 15), 
              defaultPageSize = 10)
  )
  
  # Render the graph(s)
  plot <- plotly::ggplotly(
    ggplot(projects, aes(y = stars, x = forks)) + 
      geom_point(aes(color=project)) + 
      labs(
        title = 'Repository Metrics', 
        subtitle ='Stars vs. Forks'
      ) + xlab('# of Forks') + ylab('# of Stars') + 
      scale_x_continuous(labels = comma) + 
      scale_y_continuous(labels = comma)
    )
  output$project_plot <- plotly::renderPlotly(plot)
}

# Launch the application 
shinyApp(ui, server)