library(dplyr)
library(readr)
library(pkgsearch)

## Load data

data <- read_rds("scratch/yamL_repos.rds")

## Filter data
data %>%
  filter(lang == "r") %>%
  pull(repo) %>%
  
  ## Get cran meta
  cran_packages() %>%
  
  ## Write
  write_rds("scratch/metacran_repos.rds")

  