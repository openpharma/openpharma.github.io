library(dplyr)
library(tibble)
library(readr)
library(glue)
library(tidyr)
library(purrr)
library(GithubMetrics)


## Load data

  # yaml
  data_yaml <- read_rds("scratch/yaml_repos.rds")

  # gh
  data_gh_commits <- read_rds("scratch/gh_commits.rds")
  data_gh_issues <- read_rds("scratch/gh_issues.rds")
  data_gh_people <- read_rds("scratch/gh_people.rds")
  data_gh_repos <- read_rds("scratch/gh_repos.rds")
  
  data_gh_help <- read_rds("scratch/gh_issues_help.rds")
  
  # s3
  commits_s3 <- read_rds("scratch/commits_s3.rds")
  people_s3 <- read_rds("scratch/people_s3.rds")
  repos_s3 <- read_rds("scratch/repos_s3.rds")
  
  # metacran
  data_metacran_repos <- read_rds("scratch/metacran_repos.rds") %>%
    unique() %>%
    select(-dependencies)
  
  # risk metric
  riskmetric <- read_rds("scratch/riskmetric.rds")
  

  
## Repos ----------------------------
  ## Add CRAN to repos
  
  data_repos <- data_yaml %>%
    left_join(
      data_metacran_repos %>% 
        select(
          repo = Package,
          cran_title = Title,
          cran_description = Description,
          cran_license = License,
          cran_bugs = BugReports,
          cran_maintainer = Maintainer,
          cran_version = Version
        ),
      by = "repo"
    ) %>%
    left_join(
      data_gh_repos %>%
        select(
          full_name,
          gh_description = description,
          gh_mb = mb,
          gh_updated = updated_at,
          gh_default_branch = default_branch,
          gh_language
        ),
      by = "full_name"
    ) 
  
# Merge with old data ----------------
  
  # Function to combine
  repos <- data_repos %>%
    select(org:gh_language) %>%
    mutate(source = "1 current pull") %>%
    bind_rows(
      repos_s3 %>% select(org:gh_language)
    ) %>%
    arrange(full_name, source) %>%
    group_by(full_name) %>% slice(1) %>% select(-source) %>%
    left_join(
      riskmetric,
      by = "full_name"
    )
  
  people <- data_gh_people %>%
    mutate(
      source = "1 current pull"
    ) %>%
    select(-email) %>% # remove personal info we do not need
    bind_rows(
      people_s3 %>% select(author:bio)
    ) %>%
    arrange(author, source) %>%
    group_by(author) %>% slice(1) %>% select(-source)
  
  commits <- data_gh_commits %>%
    mutate(source = "1 current pull") %>%
    bind_rows(
      commits_s3
    ) %>%
    arrange(sha, source) %>%
    group_by(sha) %>% slice(1) %>% select(-source) %>%
    mutate(
      author_clean = case_when(
        is.na(author) ~ sub("@.*", "",tolower(commit_email)),
        TRUE ~ author
      )
    )
  
## Add Github repo overlap
  get_overlap <- function(
    repo_name = "rtables", data
  ){
    
    i_authors <- data %>%
      filter(full_name == repo_name) %>%
      filter(author != ".gitconfig missing email") %>%
      pull(author) %>% unique() 
    
    i_overlap <- data %>%
      filter(full_name != repo_name) %>%
      filter(author %in% i_authors) %>%
      group_by(full_name) %>%
      summarise(n = n_distinct(author)) %>%
      mutate(
        repo1 = repo_name,
        id = paste(pmin(repo1,full_name),pmax(repo1,full_name))
      ) %>%
      select(
        id,repo1,repo2 = full_name,n
      )
    
    i_overlap
  }
  
  
  connections <- unique(commits$full_name) %>%
    map(get_overlap, data = commits) %>%
    bind_rows() %>%
    group_by(id) %>% slice(1) %>% ungroup()
  
  
  collab_tables <- NULL
  for (i in unique(commits$full_name)) {
    list <- connections %>%
      filter(repo1 == i | repo2 == i) %>%
      mutate(
        repo = trimws(gsub(pattern = i,replacement = "",id))
      ) %>%
      select(
        repo = repo, overlap = n
      ) %>%
      arrange(-overlap) %>%
      mutate(
        similar = glue('<a href="https://github.com/{repo}">{basename(repo)}</a>')
      ) %>%
      slice(1:3) %>%
      pull(similar) %>% paste(collapse = ", ")
    
    if (length(table) == 1){
      output_table <- tibble(
        full_name = i,
        similar = list
      )
      
      collab_tables <- bind_rows(
        output_table,collab_tables
      )
    }
  }
  
  collab_tables <- collab_tables %>%
    filter(similar != "")
  
  repos <- repos %>%
    left_join(collab_tables, by = "full_name")
  
  # Clean data repos
  
  repos <- repos %>%
    mutate(
      imputed_description = case_when(
        !is.na(cran_description) ~ cran_description,
        TRUE ~ gh_description
      )
    )
  

  
## People ----------------------------
  ## Add Github repos
  people <- people %>%
    left_join(
      commits %>%
        group_by(author) %>%
        arrange(desc(datetime)) %>%
        summarise(
          repo_list = paste0(unique(basename(full_name)), collapse = " | "),
          contributed_to = n_distinct(full_name)
        ),
      by = "author"
    ) %>%
    mutate(
      days_last_active = Sys.Date() - last_active,
      pretty_contributor = as.character(glue(
        '<img src="{avatar}" alt="" height="30" width = "30"> {name} (<a href="https://github.com/{author}">{author}</a>)'
      )),
      pretty_blog = case_when(
        blog == "" ~ "",
        TRUE ~ as.character(glue('<a href="{blog}">link</a>'))
      ),
      pretty_name = glue("{name} ({author})")
    )
  
  # Add CRAN
  # fuzzy join maintainer and email on name?


    
## Generate Health table ------------
  
  issues_oshealth <- data_gh_issues %>% ungroup %>%
    mutate(
      days_open = as.numeric(Sys.Date() - as.Date(created)),
      days_no_activity = as.numeric(Sys.Date() - as.Date(updated))
    ) %>%
    select(
      full_name, state, days_open, days_no_activity
    )
  
  commits_oshealth <- commits %>% ungroup %>%
    mutate(
      date = as.Date(datetime)
    ) %>%
    select(full_name, date, author)
  
  health <- tibble(
    full_name = unique(commits$full_name)
    ) %>%
    left_join(
      gh_metric_issues(issues_oshealth), by = "full_name"
    ) %>%
    left_join(
      gh_metric_commits_days_since_commit(commits_oshealth), by = "full_name"
    ) %>%
    left_join(
      gh_metric_commits_prepost_midpoint(commits_oshealth), by = "full_name"
    ) %>%
    left_join(
      gh_metric_commits_authors_ever(commits_oshealth), by = "full_name"
    ) %>%
    left_join(
      gh_metric_commits_authors_prepost_midpoint(commits_oshealth), by = "full_name"
    ) %>%
    gh_score() %>% 
    mutate(
      os_health = score
    )
    
  repos <- repos %>%
    select(org:imputed_description) %>% # fresh health
    left_join(health, by = "full_name")
  
  # total contributors
  repos <- repos %>%
    left_join(
      commits %>% 
        group_by(full_name) %>%
        summarise(
          Contributors = n_distinct(author_clean),
          Commits = n(),
          `Last Commit` = max(date)
        ),
      by = "full_name"
    )
  
  # Nicer repo name
  repos <- repos %>%
    mutate(
      pretty_repo = glue(
        '<a href="https://github.com/{full_name}">{full_name}</a>'
      )
    )


## Help
  help <- data_gh_help %>%
    mutate(
      pretty_url = glue('<a href="{url}">Issue link</a>')
    )

  
## Things to upload
  write_csv(repos, glue("scratch/repos.csv"))
  write_csv(people,  glue("scratch/people.csv"))
  write_csv(help, glue("scratch/help.csv"))
  write_csv(commits, glue("scratch/commits.csv"))
  
  write_rds(repos,  glue("scratch/repos.rds"))
  write_rds(people,  glue("scratch/people.rds"))
  write_rds(help, glue("scratch/help.rds"))
  write_rds(commits, glue("scratch/commits.rds"))
  
  write_csv(repos, glue("scratch/repos-{Sys.Date()}.csv"))
  write_csv(people,  glue("scratch/people-{Sys.Date()}.csv"))
  write_csv(help, glue("scratch/help-{Sys.Date()}.csv"))
  write_csv(commits, glue("scratch/commits-{Sys.Date()}.csv"))
  
  write_rds(repos,  glue("scratch/repos-{Sys.Date()}.rds"))
  write_rds(people,  glue("scratch/people-{Sys.Date()}.rds"))
  write_rds(help, glue("scratch/help-{Sys.Date()}.rds"))
  write_rds(commits, glue("scratch/commits-{Sys.Date()}.rds"))
  
