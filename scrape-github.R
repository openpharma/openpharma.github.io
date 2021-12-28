library(dplyr)
library(tibble)
library(readr)
library(glue)
library(GithubMetrics)
library(purrr)

lookback_days <- 3

## Load data

  data <- read_rds("scratch/yaml_repos.rds")
  commits_s3 <- read_rds("scratch/commits_s3.rds")

## Helpers

  hlp_org_repos <- function(x){
    GithubMetrics::gh_repos_get(x) %>%
      GithubMetrics::gh_repos_clean(.)
  }

  safe_hlp_org_repos <- purrr::possibly(hlp_org_repos, otherwise = NULL)
  
## Scrape repos
  
  d_github <- data$org %>%
    unique() %>%
    purrr::map_dfr(safe_hlp_org_repos)

    
  d_github <- d_github %>%
    select(
      full_name,description,size,
      updated_at,default_branch,
      gh_language = language,
      mb = MB
      ) %>%
    filter(
      full_name %in% data$full_name
    )
  
## Scrape commits
  
  d_all_commits <- GithubMetrics::gh_commits_get(
    d_github %>% dplyr::filter(mb > 0) %>% dplyr::pull(full_name), 
    days_back = lookback_days
  ) 
  
  if (nrow(d_all_commits) == 0) {
    stop("No new commits! Stopping build")
  }
  
  d_all_commits <- d_all_commits %>%
    dplyr::filter(!author %in% c(".gitconfig missing email","actions-user")) %>%
    dplyr::mutate(
      date = as.Date(datetime)
    )

## Scrape issues
  
  d_all_issues <- GithubMetrics::gh_issues_get(
    unique(
      d_github %>% dplyr::filter(mb > 1) %>% dplyr::pull(full_name), 
      unique(commits_s3$full_name)
    ),
    days_back = 365
    ) %>%
    dplyr::filter(!author %in% c(".gitconfig missing email","actions-user")) %>%
    dplyr::mutate(
      created = as.Date(created),
      updated = as.Date(updated),
      closed = as.Date(closed),
      comments = as.numeric(comments)
    ) %>%
    dplyr::mutate(
      days_open = dplyr::case_when(
        !is.na(closed) ~ as.numeric(closed - created),
        TRUE ~ as.numeric(Sys.Date() - created)
      ),
      days_no_activity = dplyr::case_when(
        !is.na(closed) ~ as.numeric(closed - updated),
        TRUE ~ as.numeric(Sys.Date() - updated)
      )
    ) 
  
  ## labels
  d_issues_labels <- dplyr::bind_rows(
    gh_issues_labels_get(
      unique(
        d_github %>% dplyr::filter(mb > 1) %>% dplyr::pull(full_name), 
        unique(commits_s3$full_name)
      ),
      days_back = 365,
      state = "open"
    )
  )
  
  d_issues_labels_helpme <- d_issues_labels %>%
    dplyr::filter(tolower(label_name) %in% c("help wanted","good first issue","discussion")) %>%
    dplyr::group_by(url) %>% summarise(label = paste(label_name, collapse = ", ")) %>%
    dplyr::select(url,label) %>%
    dplyr::distinct() %>%
    dplyr::left_join(
      d_all_issues, by = "url"
    )
  
  d_issues_labels_helpme <- d_issues_labels_helpme %>%
    dplyr::left_join(
      d_github %>%
        dplyr::select(
          full_name, description, lang = gh_language
        ),
      by = c("full_name")
    )
  
  
  

##  People info 
  d_contributors <- d_all_commits %>%
    bind_rows(commits_s3 %>% select(-source)) %>%
    dplyr::group_by(author) %>%
    dplyr::summarise(
      commits = dplyr::n()
    ) %>% na.omit()
  
  d_user <- GithubMetrics::gh_user_get(d_contributors$author)
 
  d_contributors <- d_contributors %>%
    dplyr::left_join(
      d_user,
      by = c("author" = "username")
    ) 
  
  # tidy
  d_contributors <- d_contributors %>%
    dplyr::mutate(
      name = dplyr::if_else(is.na(name),author,name)
    )
  
## Save
  write_rds(d_all_commits, "scratch/gh_commits.rds", )
  write_rds(d_all_issues, "scratch/gh_issues.rds")
  write_rds(d_github, "scratch/gh_repos.rds")
  write_rds(d_contributors, "scratch/gh_people.rds")
  write_rds(d_issues_labels_helpme,"scratch/gh_issues_help.rds")
  
  