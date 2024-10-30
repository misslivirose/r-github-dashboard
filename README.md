# GitHub Data Dashboard

The GitHub Data Dashboard makes it easy to quickly create a dashboard application to view open source projects hosted on GitHub. View repositories of interest at a glance and get new insights from the projects with visual plots and graphs.

![A preview of the dashboard, showing selected metrics from an assortment of GitHub projects](img/preview)

## Data

The dashboard is populated with a .csv file called `projects-of-interest`. At a minimum, this file should include two columns, `project` and `repository`. You can include optional columns (such as `tag` or `year`), which will show up in the `reactable` table. The card view, however, doesn't display additional attributes included. The `repository` column should be in the format of the `<owner>/<repository>` found after `github.com/`.

Sample .csv:

```         
project,repository
dashboard,misslivirose/r-github-dashboard
llamafile,Mozilla-Ocho/llamafile
llama-recipes,meta-llama/llama-recipes
```

## Dependencies

This project uses R and Shiny to run and assumes the following dependencies:

-   R, version 4.4.0+

-   R Studio - tested with RStudio 2024.04.2+764

-   Required R Packages: `install.packages(c('shiny', 'rvest', 'reactable', 'shinythemes', 'stringr', 'ggplot2', 'bslib', 'scales'))`

## Running the app

To run the application:

1.  Clone the GitHub project to your local machine after installing dependencies
2.  Create your `projects-of-interest.csv` file and put it into the repository at the root level
3.  Open `basic_dashboard_test.R` in R Studio
4.  Use `CTRL` + `SHIFT` + `ENTER` to generate the dashboard and display it in the R Studio viewer
