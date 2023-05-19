library(dplyr)
library(readr)
library(riskmetric)
library(pkgsearch)

## Load data

data <- read_rds("scratch/yaml_repos.rds")

cran <- available.packages()
cran <- row.names(cran)

## Filter data
riskmetric <- data %>%
  filter(repo %in% cran) %>%
  pull(repo) %>%
  
  ## Get cran meta
  pkg_ref() %>%
  pkg_assess() %>%
  pkg_score()

data %>%
  left_join(
    riskmetric %>% select(package, riskmetric_score = pkg_score),
    by = c("repo" = "package")
  ) %>%
  select(full_name,riskmetric_score) %>%
  na.omit() %>%
  mutate(
    riskmetric_score_quintile = ntile(riskmetric_score,5)
  ) %>%
  
  ## Write
  write_rds("scratch/riskmetric.rds")
  