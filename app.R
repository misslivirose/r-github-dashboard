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
library(dplyr)
library(RSQLite)
library(DBI)


db_file <- 'data/projects.sqlite'
db_connection <- dbConnect(SQLite(), db_file)
# Set up the tibble from a CSV file of the projects we want to include
projects <- dbReadTable(db_connection, 'projects')
metrics <- c('description', 'stars', 'forks', 'contributors', 'issues')

# Function to check if a project exists in the projects table
project_exists <- function(conn, repository) {
  query <- "SELECT COUNT(*) FROM projects WHERE repository = ?"
  result <- dbGetQuery(conn, query, params = list(repository))
  return(result[1, 1] > 0)
}

# Iterate over the list of repositories to populate our data frame
repositories <- as.list(projects$repository)

# Insert project data if it doesn't already exist
for (p in repositories) {
  if (!project_exists(db_connection, p)) {
    project_data <- data.frame(
      project_name = projects[projects$repository == p, "project_name"],
      repository = p,
      tag = projects[projects$repository == p, "tag"],
      year = projects[projects$repository == p, "year"],
      date_added = as.character(Sys.Date())
    )
    dbWriteTable(
      db_connection,
      'projects',
      project_data,
      append = TRUE,
      row.names = FALSE
    )
  }
}

# Initialize an empty list to store snapshot data
snapshot_data_list <- list()

# Function to check if a snapshot for today's date already exists
snapshot_exists <- function(conn, project_name, date) {
  query <- "SELECT COUNT(*) FROM metrics WHERE project_name = ? AND snapshot_date = ?"
  result <- dbGetQuery(conn, query, params = list(project_name, date))
  return(result[1, 1] > 0)
}


for (p in repositories) {
  project_name <- projects[projects$repository == p, "project_name"]
  
  if (snapshot_exists(db_connection, project_name, as.character(Sys.Date()))) {
    next
  }
  
  # Create the full repository URL
  url <- paste('https://github.com/', p, sep = "")
  # Read in the HTML of the GitHub repository page
  html <- read_html(url)
  
  # Extract the description of the project from the HTML node
  updated_description <- html |>
    html_node('div.Layout-sidebar') |>
    html_node('p.f4') |>
    html_text(trim = TRUE)  # Extract text, trim to remove extra spaces
  
  update_project_description <- function(conn, project_name, new_description) {
    query <- "UPDATE projects SET description = ? WHERE project_name = ?"
    dbExecute(conn, query, params = list(new_description, project_name))
  }
  
  # Update the description in the `projects` table
  if (!is.na(updated_description)) {
    update_project_description(db_connection, project_name, updated_description)
  }
  
  # Extract the stars, forks, and issues as integer values from the GitHub repository page
  stars <- as.integer(gsub(',', '', as.character(
    html |> html_node('#repo-stars-counter-star') |> html_attr('title')
  )))
  forks <- as.integer(gsub(',', '', as.character(
    html |> html_node('#repo-network-counter') |> html_attr('title')
  )))
  issues <- as.integer(gsub(',', '', as.character(
    html |> html_node('#issues-repo-tab-count') |> html_attr('title')
  )))
  
  # Get the collaborators from the GitHub repository page. If there is no html node for contributors, return 1
  collaborators <- tryCatch({
    html |> 
      html_node('a[href*="/contributors"]') |>  # Find the link to contributors
      html_text(trim = TRUE) |>                # Extract the text
      str_extract("[0-9]+") |>                 # Extract the number
      as.integer()                             # Convert to integer
  }, error = function(e) {
    0  # Return 1 if an error occurs
  })
  
  # Collect snapshot data for this repository
  snapshot_data <- data.frame(
    project_name = project_name,
    snapshot_date = as.character(Sys.Date()),
    stars = stars,
    forks = forks,
    contributors = collaborators,
    issues = issues
  )
  
  # Append to the list
  snapshot_data_list[[length(snapshot_data_list) + 1]] <- snapshot_data
}

# Combine and write to the database only if there's new data
if (length(snapshot_data_list) > 0) {
  all_snapshot_data <- do.call(rbind, snapshot_data_list)
  
  # Write the data to the database
  dbWriteTable(
    db_connection,
    'metrics',
    all_snapshot_data,
    append = TRUE,
    row.names = FALSE
  )
} else {
  message("No new data to insert into the metrics table.")
}


# Create the dashboard UI
ui <- page_navbar(
  # In-line CSS styling for now, TODO move to a separate file
  tags$head(tags$style(
    HTML(
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
    )
  )),
  # Set up the header of the page and nest our pages for each data view we want to include
  title = 'Builders Data Dashboard',
  # Card view of the GitHub repositories, formatted
  nav_panel(title = 'GitHub Repositories', mainPanel(width = 12, fluidRow(uiOutput(
    "cards"
  )))),
  # Data table view of the GitHub information as an interactive element
  nav_panel(title = 'Data Table', mainPanel(
    width = 12, reactableOutput(outputId = 'data')
  )),
  # Plots / charts from the data as an interactive element
  nav_panel(
    title = 'Project Graphs',
    mainPanel(
      width = 12,
      plotly::plotlyOutput(outputId = 'project_plot_stars_forks'),
      # plotly::plotlyOutput(outputId = 'project_plot_collaborators_forks')
    )
  )
)

get_latest_metrics <- function(conn) {
  query <- "
    SELECT
        p.project_name,
        p.repository,
        p.description,
        m.snapshot_date,
        m.stars,
        m.forks,
        m.contributors,
        m.issues
    FROM projects p
    LEFT JOIN (
        SELECT
            project_name,
            MAX(snapshot_date) AS latest_snapshot_date
        FROM metrics
        GROUP BY project_name
    ) latest ON p.project_name = latest.project_name
    LEFT JOIN metrics m ON
        p.project_name = m.project_name AND
        m.snapshot_date = latest.latest_snapshot_date
  "
  dbGetQuery(conn, query)
}

get_all_metrics <- function(conn) {
  query <- "
    SELECT 
      m.project_name,
      m.snapshot_date,
      m.stars,
      m.forks,
      m.contributors,
      m.issues,
      p.repository,
      p.description
    FROM metrics m
    LEFT JOIN projects p ON m.project_name = p.project_name
    ORDER BY m.snapshot_date DESC
  "
  dbGetQuery(conn, query)
}


# Set up the application server
server <- function(input, output, session) {
  # Reactive data for the latest project metrics
  latest_metrics <- reactive({
    get_latest_metrics(db_connection)
  })
  
  # Reactive data for all project metrics
  all_metrics <- reactive({
    get_all_metrics(db_connection)
  })
  
  # Render the UI for card view for our repositories
  output$cards <- renderUI({
    data <- latest_metrics()
    lapply(1:nrow(data), function(i) {
      column(width = 4, div(style = "margin: 15px", card(
        card_header(data$project_name[i]),
        # Project name
        p(data$description[i]),
        # Project description
        a(
          href = paste('https://github.com/', data$repository[i], sep = ""),
          data$repository[i],
          target = '_blank'
        ),
        # Repository URL
        p(paste('Stars:', comma(data$stars[i]))),
        # Stars
        p(paste('Forks:', comma(data$forks[i]))),
        # Forks
        p(paste(
          'Contributors:', comma(data$contributors[i])
        ))  # Contributors
      )))
    })
  })
  
  # Render the reactable data table
  output$data <- renderReactable({
    data <- latest_metrics()
    reactable(
      data,
      defaultColDef = colDef(
        header = function(value)
          str_to_title(value),
        minWidth = 60,
        align = 'left',
        headerStyle = list(background = '#f7f7f8')
      ),
      columns = list(
        repository = colDef(minWidth = 120),
        description = colDef(minWidth = 120),
        stars = colDef(
          cell = function(value)
            comma(value)
        ),
        forks = colDef(
          cell = function(value)
            comma(value)
        ),
        contributors = colDef(name = '# of Contributors'),
        issues = colDef(name = 'Open Issues')
      ),
      bordered = TRUE,
      highlight = TRUE,
      searchable = TRUE,
      showPageSizeOptions = TRUE,
      pageSizeOptions = c(5, 10, 15),
      defaultPageSize = 10
    )
  })
  
  # Render the graph(s)
  output$project_plot_stars_forks <- plotly::renderPlotly({
    data <- latest_metrics()
    plotly::ggplotly(
      ggplot(data, aes(y = stars, x = forks)) +
        geom_point(aes(color = project_name)) +
        labs(title = 'Repository Metrics', subtitle = 'Stars vs. Forks') + xlab('# of Forks') + ylab('# of Stars') +
        scale_x_continuous(labels = comma) +
        scale_y_continuous(labels = comma)
    )
  })
  
  output$project_plot_collaborators_forks <- plotly::renderPlotly({
    data <- latest_metrics()
    plotly::ggplotly(
      ggplot(
        data |> dplyr::filter(contributors > 1),
        aes(x = project_name, y = contributors)
      ) +
        geom_bar(stat = 'identity', aes(fill = forks)) +
        labs(title = 'Contributors vs. Forks', x = 'Project Name', y = 'Contributors')
    )
  })
}


# Launch the application
shinyApp(ui, server)