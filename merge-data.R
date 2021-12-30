library(dplyr)
library(tibble)
library(readr)
library(glue)
library(tidyr)
library(purrr)


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
    ) %>%
    left_join(
      riskmetric,
      by = "full_name"
    )
  
# Merge with old data ----------------
  
  # Function to combine
  repos <- data_repos %>%
    mutate(source = "1 current pull") %>%
    bind_rows(
      repos_s3 %>% select(org:gh_language)
    ) %>%
    arrange(full_name, source) %>%
    group_by(full_name) %>% slice(1) %>% select(-source)
  
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
    group_by(sha) %>% slice(1) %>% select(-source)
  
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
  
  health <- repos %>%
    mutate(
      days_since_update = as.numeric(Sys.Date() - as.Date(gh_updated))
    ) %>%
    select(full_name, days_since_update) %>%
    left_join(
      # time current open
      data_gh_issues %>%
        group_by(full_name) %>%
        filter(state == "open") %>%
        summarise(
          open_issues = n(),
          median_age_open_issue = median(days_open),
          median_inactivity_open_issue = median(days_no_activity)
        ),
      by = "full_name"
    ) %>%
    left_join(
      # time to close
      data_gh_issues %>%
        group_by(full_name) %>%
        filter(state == "closed") %>%
        summarise(
          closed_issues = n(),
          median_timeto_close = median(days_open)
        )  ,
      by = "full_name"  
    ) %>%
    left_join(
      # increase in commits?
      commits %>%
        group_by(full_name) %>%
        mutate(
          date_numeric = as.numeric(date),
          midpoint = quantile(date_numeric, 0.5),
          firsthalf = ifelse(date_numeric >= midpoint,FALSE,TRUE)
        ) %>%
        summarise(
          commits = n(),
          secondhalf = sum(ifelse(!firsthalf,1,0)),
          firsthalf = sum(ifelse(firsthalf,1,0))
        ) %>%
        mutate(
          abs = secondhalf - firsthalf
        ) %>%
        select(
          full_name, abs_commits = abs,commits
        )   ,
      by = "full_name" 
    ) %>%
    left_join(
      # increase in people?
      commits %>%
        group_by(full_name) %>%
        summarise(
          authors_ever = n_distinct(author_clean)
        ),
      by = "full_name"
    ) %>%
    left_join(
      # increase in people?
      commits %>%
        group_by(full_name) %>%
        mutate(
          date_numeric = as.numeric(date),
          midpoint = quantile(date_numeric, 0.5),
          timing = ifelse(date_numeric >= midpoint,"firsthalf","secondhalf")
        ) %>%
        group_by(full_name,timing) %>%
        summarise(
          active_people = n_distinct(author_clean)
        ) %>% ungroup %>%
        pivot_wider(
          names_from = timing, values_from = active_people, values_fill = 0
        ) %>%
        mutate(
          ratio = secondhalf/firsthalf,
          abs_people = secondhalf-firsthalf,
          percentage_people = round(100*ratio),
          # if one commit set to 0
          percentage_people = ifelse(percentage_people == Inf,0,percentage_people)
        ) %>%
        select(full_name,abs_people),
      by = "full_name"
    ) %>%
    # Score
    ungroup() %>%
    mutate(
      score = ifelse(days_since_update < 30*6,1,0),
      score = case_when(
        is.na(sum(open_issues,closed_issues, na.rm = TRUE)) ~ score,
        TRUE ~ score + 1
      ),
      score = case_when(
        commits < 25 ~ score,
        TRUE ~ score + 1
      ),
      score = case_when(
        authors_ever < 5 ~ score,
        TRUE ~ score + 1
      ),
      score = case_when(
        is.na(median_age_open_issue) ~ score,
        median_age_open_issue > 30*6 ~ score,
        TRUE ~ score + 1
      ),
      score = case_when(
        is.na(median_inactivity_open_issue) ~ score,
        median_inactivity_open_issue > 30*3 ~ score,
        TRUE ~ score + 1
      ),
      score = case_when(
        is.na(open_issues) | is.na(closed_issues) ~ score,
        open_issues > closed_issues ~ score,
        TRUE ~ score + 1
      ),
      score = case_when(
        is.na(abs_commits)  ~ score,
        abs_commits < 0 ~ score,
        TRUE ~ score + 1
      ),
      score = case_when(
        is.na(abs_people)  ~ score,
        abs_people < 0 ~ score,
        TRUE ~ score + 1
      )
    ) %>%
    filter(!is.na(score)) %>%
    mutate(
      max = max(score, na.rm = TRUE),
      Health = round(100*score/max(score, na.rm = TRUE)),
      
      pretty_repo = glue(
        '<a href="https://github.com/{full_name}">{full_name}</a>'
      )
    ) %>%
    # tidy title
    select(
      full_name,
      pretty_repo,
      Health,
      Commits = commits,
      Contributors = authors_ever,
      `Days repo inactive` = days_since_update,
      `Median days open for current issues` = median_age_open_issue,
      `Median days without comments on open issues` = median_inactivity_open_issue,
      `Median days to close issue` = median_timeto_close,
      `Change in frequency of commits` = abs_commits,
      `Change in active contributors` = abs_people
    ) %>%
    arrange(
      desc(Health)
    ) 
  
  repos <- repos %>%
    select(org:imputed_description) %>% # fresh health
    left_join(health, by = "full_name")


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
  
