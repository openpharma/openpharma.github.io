library(dplyr)
library(tibble)
library(readr)
library(glue)
library(pkgsearch)

# Scrape ymls

  # Get the repos to scan
  d_scanme <- yaml::read_yaml("openpharma_included.yaml")
  
  helper_extract_repos <- function(data){
    org_tibble <- tibble(
      org = character(),
      repo = character(),
      lang = character(),
      type = character()
    )
    org <- names(data[1])
    org_data <- data[[org]]
    for (i in names(org_data)) {
      org_tibble <- org_tibble %>% 
        tibble::add_row(
          org = org,
          repo = i,
          lang = org_data[[repo]]$lang[[1]],
          type = paste(as.character(org_data[[repo]]$type), collapse = ", ")
        )
    }
    org_tibble
  }
  
  data_repos <- tibble(
    org = character(),
    repo = character(),
    lang = character(),
    type = character()
  )
  for (i in names(d_scanme)){
    data_repos <- helper_extract_repos(d_scanme[i]) %>%
      bind_rows(data_repos)
  }

# enrich data  
  
  data_repos <- data_repos %>%
    dplyr::mutate(
      full_name = glue::glue("{org}/{repo}")
    ) %>% group_by(full_name) %>% slice(1) %>% ungroup()
  
# Write to scratch
  write_rds(data_repos,file = "scratch/yaml_repos.rds")
  