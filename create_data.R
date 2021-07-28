#install.packages("yaml") # yaml
library(magrittr)
# pins dplyr GithubMetrics remotes
# remotes::install_github('rstudio/flexdashboard')
# dashboard - plotly thematic 

# Vars
lookback_days <- 10

# Get the things to scan
  d_scanme <- yaml::read_yaml("openpharma_included.yaml")
  
# Setup boards -------------
  pins::board_register_github(
    repo = "openpharma/openpharma_log", branch = "main"
  )
  
  
# old data -----------
  prev_commits <- pins::pin_get("all-commits", board = "github")
  prev_contributors <- pins::pin_get("all-contributors", board = "github")
  prev_issues <- pins::pin_get("all-issues", board = "github", cache = FALSE)
  
# Helpers
  hlp_org_repos <- function(x){
    GithubMetrics::gh_repos_get(x) %>%
      GithubMetrics::gh_repos_clean(.)
  }
  
  safe_hlp_org_repos <- purrr::possibly(hlp_org_repos, otherwise = NULL)
  
  hlp_expand_vector <- function(x){
    expanded <- strsplit(x, ", ") 
    unlist(expanded) 
  }

# Get high level info
  
    # tags ----
    # r / python
    tag_r <- hlp_expand_vector(d_scanme$tags$lang$r)
    tag_python <- hlp_expand_vector(d_scanme$tags$lang$python)
    # type
    tag_filing <- hlp_expand_vector(d_scanme$tags$type$`filing-tools`)
    tag_tlg <- hlp_expand_vector(d_scanme$tags$type$tlg)
    tag_clinstats <- hlp_expand_vector(d_scanme$tags$type$`clinical-statistics`)
  
    # exclude these from openpharma
    d_donot_scan_repos <- d_scanme$openpharma_exclude 
    # non-openpharma repos
    d_scan_repos <- d_scanme$repos %>%
      tibble::enframe(.) %>%
      tidyr::unnest(
        cols = c(value)
      ) %>%
      dplyr::rename(
        org = name,
        repo = value
      ) %>%
      dplyr::mutate(
        full_name = glue::glue("{org}/{repo}")
      )
    # Get all public repos
    d_all_repos <- unique(c("openpharma",d_scan_repos$org)) %>%
       purrr::map_dfr(safe_hlp_org_repos) %>%
       # pretty it up
      dplyr::rename(
        repo = name
      ) %>%
      dplyr::mutate(
        org = dirname(full_name)
      ) %>%
      dplyr::select(
        org, repo, full_name,description, updated_at,language,MB
      )
    
    # Repos of interest
    d_repos <- d_all_repos %>%
      # open pharma or of interest
      dplyr::filter(
        org %in% "openpharma" |
          full_name %in% d_scan_repos$full_name
      ) %>%
      # not one to exclude from openpharma
      dplyr::filter(
        (org == "openpharma" &
           !repo %in% d_donot_scan_repos) |
          org != "openpharma"
      )
    
# Get commits -----------------------
    message("Get commmits")
    d_all_commits <- GithubMetrics::gh_commits_get(
      d_repos %>% dplyr::filter(MB > 0) %>% dplyr::pull(full_name), 
      days_back = lookback_days
      ) 
    
    if(nrow(d_all_commits) == 0) {
      stop("No new commits! Stopping build")
    }
    
    d_all_commits <- d_all_commits %>%
      dplyr::filter(!author %in% c(".gitconfig missing email","actions-user")) %>%
      dplyr::mutate(
        date = as.Date(datetime)
      )
    
# Get issues -----------------------
    message("Get issues")
    d_all_issues <- GithubMetrics::gh_issues_get(
      d_repos %>% dplyr::filter(MB > 0) %>% dplyr::pull(full_name), 
      days_back = lookback_days
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
    
    
# Get people -----------------------
    message("Get People")
    message("Get People - sum commits")
    contributors <- d_all_commits %>%
      dplyr::group_by(author) %>%
      dplyr::summarise(
        commits = dplyr::n()
      ) 
    message("Get People - get usr info")
    message(str(contributors$author))
    user_info <- GithubMetrics::gh_user_get(contributors$author)
    message("Get People - join usr info")
    contributors <- contributors %>%
      dplyr::left_join(
        user_info,
        by = c("author" = "username")
      )
    
    # tidy
    message("Get People - rename")
    message(str(contributors))
    contributors <- contributors %>%
      dplyr::mutate(
        name = dplyr::if_else(is.na(name),author,name)
      )
    

    
# Upload -------------
    message("Upload")
    
  # tags
    all_tags <- list(
      r = tag_r,
      python = tag_python,
      filing = tag_filing,
      tlg = tag_tlg,
      clinstats = tag_clinstats
    )
    
    pins::pin(
      all_tags, 
      description = "List of repos for each tag in open pharma", 
      board = "github"
    )  
    
  # repos
  all_repos <- d_repos %>%
    dplyr::arrange(
      org,repo
    )
    
  pins::pin(
    all_repos, 
    description = "List of repos in open pharma", 
    board = "github"
  )    
    
  # commits
  all_commits <- d_all_commits %>%
    dplyr::arrange(datetime) %>%
    dplyr::select(date,datetime,full_name,author) %>%
    dplyr::bind_rows(prev_commits) %>%
    dplyr::arrange(datetime) %>%
    unique
    
  pins::pin(
    all_commits, 
    description = "Raw data on all the commits", 
    board = "github"
    )
  
  # contributors
  all_contributors <- contributors %>%
    dplyr::select(
      author,avatar,name,blog,joined,last_active,location,company,email,bio
    ) %>%
    dplyr::bind_rows(prev_contributors) %>%
    dplyr::group_by(author) %>%
    dplyr::arrange(joined,last_active) %>%
    dplyr::slice(1) %>% 
    unique
  
  pins::pin(
    all_contributors, 
    description = "Ever contributed", 
    board = "github")
      
  # issues
  all_issues <- d_all_issues %>%
    dplyr::bind_rows(prev_issues) %>%
    dplyr::group_by(created,title,full_name) %>%
    dplyr::slice(1) %>%
    dplyr::arrange(created,title,full_name)
    
    
  pins::pin(
    all_issues, 
    description = "All issues", 
    board = "github")
  
