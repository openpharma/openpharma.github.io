library(dplyr)
library(tibble)
library(readr)
library(glue)
library(ctv)
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
  
# ctv
  get_packages <- function(x) {ctv:::.get_pkgs_from_ctv_or_repos(views = x)[[1]]}

  

    
    
    # REMOVED as API seems to not like big calls
    # ctv <- c(
    # get_packages("Bayesian"),get_packages("ClinicalTrials"),
    # get_packages("MissingData"),get_packages("CausalInference"),
    # get_packages("Survival")
    # ) %>%
    # cran_packages() %>%
  
  ctv <- NULL
  for (i in c(
    "Bayesian","ClinicalTrials","MissingData","CausalInference","Survival"
  )) {
    message(paste("getting ctv",i))
    ctv <- bind_rows(
      cran_packages(get_packages(i)),
      ctv)
  }
    
  ctv <- ctv %>%
    select(Package,URL,BugReports) %>%
    # try to fina a repo
    mutate(
      URL = gsub("^(.*?),.*", "\\1", URL),
      BugReports = gsub("^(.*?),.*", "\\1", BugReports),
      full_name = case_when(
        startsWith(URL,"https://github.com/") ~ gsub("https://github.com/","",URL),
        startsWith(BugReports,"https://github.com/") ~ gsub("https://github.com/","",BugReports)
      ),
      full_name = gsub("/issues","",full_name)
    ) %>% 
    select(Package, full_name) %>% na.omit() %>%
    # should have one /
    filter(grepl("/",full_name)) %>%
    mutate(
      org = dirname(full_name),
      repo = basename(full_name),
      lang = "r",
      type = "ctv"
    ) %>% select(org:type) %>%
    # IR REPO IN YAML - DROP!!! 
    # YAML takes prominence over ctv
    filter(
      !tolower(repo) %in% tolower(data_repos$repo) 
    )
  
  
  ctv %>%
    bind_rows(
      data_repos
    ) -> data_repos


# enrich data  
  
  data_repos <- data_repos %>%
    dplyr::mutate(
      full_name = glue::glue("{org}/{repo}")
    ) %>% group_by(full_name) %>% slice(1) %>% ungroup()
  
# Write to scratch
  write_rds(data_repos,file = "scratch/yaml_repos.rds")
  