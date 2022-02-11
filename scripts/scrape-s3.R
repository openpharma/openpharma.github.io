library(readr)
library(dplyr)

options(timeout = 3600) 

# Get latest files
repos_s3 <- read_csv(
  url("http://openpharma.s3-website.us-east-2.amazonaws.com/repos.csv"),
  col_types = cols(
    org = col_character(),
    repo = col_character(),
    lang = col_character(),
    type = col_character(),
    full_name = col_character(),
    cran_title = col_character(),
    cran_description = col_character(),
    cran_license = col_character(),
    cran_bugs = col_character(),
    cran_maintainer = col_character(),
    gh_description = col_character(),
    gh_mb = col_double(),
    gh_updated = col_character(),
    gh_default_branch = col_character(),
    gh_language = col_character(),
    similar = col_logical(),
    imputed_description = col_character(),
    pretty_repo = col_character(),
    os_health = col_double(),
    Commits = col_double(),
    Contributors = col_double()
  ),
  col_select = c(
    org ,
    repo ,
    lang ,
    type ,
    full_name ,
    cran_title ,
    cran_description ,
    cran_license ,
    cran_bugs ,
    cran_maintainer ,
    gh_description ,
    gh_mb,
    gh_updated ,
    gh_default_branch ,
    gh_language ,
    similar ,
    imputed_description ,
    pretty_repo ,
    os_health ,
    Commits ,
    Contributors 
  )
) %>%
  mutate(source = "2 previous pull")

people_s3 <- read_csv(
  url("http://openpharma.s3-website.us-east-2.amazonaws.com/people.csv"),
  col_types = cols(
    author = col_character(),
    commits = col_double(),
    avatar = col_character(),
    name = col_character(),
    blog = col_character(),
    joined = col_date(format = ""),
    last_active = col_date(format = ""),
    location = col_character(),
    company = col_character(),
    bio = col_character(),
    repo_list = col_character(),
    contributed_to = col_double(),
    days_last_active = col_double(),
    pretty_contributor = col_character(),
    pretty_blog = col_character(),
    pretty_name = col_character()
  ),
  col_select = c(
    author ,
    commits,
    avatar,
    name ,
    blog,
    joined,
    last_active,
    location,
    company,
    bio,
    repo_list,
    contributed_to,
    days_last_active,
    pretty_contributor,
    pretty_blog,
    pretty_name
  )
  ) %>%
  mutate(source = "2 previous pull")

# commits in two parts due to size
download.file(
  url = "http://openpharma.s3-website.us-east-2.amazonaws.com/commits.csv",
  destfile = "temp_commits.csv"
)

commits_s3 <- read_csv(
  "temp_commits.csv",
  col_types = cols(
    full_name = col_character(),
    author = col_character(),
    author = col_character(),
    author_type = col_character(),
    commit_email = col_character(),
    datetime = col_character(),
    sha = col_character(),
    commit_message = col_character(),
    date = col_date(format = "")
  ) , 
  col_select = c(
    full_name:date
  )
  ) %>%
  mutate(source = "2 previous pull")

write_rds(commits_s3, "scratch/commits_s3.rds")
write_rds(people_s3,  "scratch/people_s3.rds")
write_rds(repos_s3, "scratch/repos_s3.rds")
