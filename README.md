# GitHub Data Dashboard

The GitHub Data Dashboard makes it easy to quickly create a dashboard application to view open source projects hosted on GitHub. View repositories of interest at a glance and get new insights from the projects with visual plots and graphs.

![A preview of the dashboard, showing selected metrics from an assortment of GitHub projects](img/preview)

## Data

The dashboard is populated with a SQLite database called `projects.sqlite`. The schema for the database is: 

```
CREATE TABLE projects (
  project_name text, 
  repository text,
  tag text,
  year integer,
  description text,
  date_added text 
);
CREATE TABLE metrics (
  project_name text,
  snapshot_date text, 
  stars integer,
  forks integer,
  contributors integer,
  issues integer
);
```

## Dependencies

This project uses R and Shiny to run and assumes the following dependencies:

-   R, version 4.4.0+

-   R Studio - tested with RStudio 2024.12.0 

-   Required R Packages: `install.packages(c('shiny', 'rvest', 'reactable', 'shinythemes', 'stringr', 'ggplot2', 'bslib', 'scales', 'dplyr', 'RSQlite', 'DBI'))`

## Running the app

To run the application:

1.  Clone the GitHub project to your local machine after installing dependencies
2.  Create your `projects.sqlite` file and put it into the repository at the root level
3.  Populate `projects.sqlite` table `projects` with the name, repository (<user>/<project>), and additional tag, year, and date_added. The description field is pulled from GitHub.
4.  Open `app.R` in R Studio
5.  Use `CTRL` + `SHIFT` + `ENTER` to generate the dashboard and display it in the R Studio viewer
