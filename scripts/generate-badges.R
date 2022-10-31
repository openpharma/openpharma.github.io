library(glue)
library(dplyr)

## Load

repos <- readRDS("scratch/repos.rds")

## Write badges

template <- "https://img.shields.io/badge/{label}-{value}-{colour}"

badges <- repos %>%
  mutate(
    # CRAN --------------
    badge_cran = case_when(
      is.na(cran_version) ~ "",
      TRUE ~ as.character(glue(
        template, 
        label = "CRAN",
        colour = "9cf",
        value = cran_version
      ))
    ),
    # People --------------
    badge_contributors = case_when(
      is.na(Contributors) ~ "",
      TRUE ~ as.character(glue(
        template, 
        label = "Contributors",
        colour = "9cf",
        value = Contributors
      ))
    ),
    # risk metric --------------
    riskmetric_score = round(riskmetric_score,2),
    
    badge_riskmetric = case_when(
      riskmetric_score_quintile == 1 ~ as.character(glue(
        template, 
        label = "riskmetric",
        colour = "brightgreen",
        value = riskmetric_score
      )),
      riskmetric_score_quintile == 2 ~ as.character(glue(
        template, 
        label = "riskmetric",
        colour = "green",
        value = riskmetric_score
      )),
      riskmetric_score_quintile == 3 ~ as.character(glue(
        template, 
        label = "riskmetric",
        colour = "yellowgreen",
        value = riskmetric_score
      )),
      riskmetric_score_quintile == 4 ~ as.character(glue(
        template, 
        label = "riskmetric",
        colour = "orange",
        value = riskmetric_score
      )),
      riskmetric_score_quintile == 5 ~ as.character(glue(
        template, 
        label = "riskmetric",
        colour = "red",
        value = riskmetric_score
      ))
    ),
    # Activity --------------
    badge_health = case_when(
      is.na(os_health) ~ as.character(glue(
        template, 
        label = "OS Activity",
        colour = "red",
        value = 0
      )),
      os_health > 90 ~ as.character(glue(
        template, 
        label = "OS Activity",
        colour = "brightgreen",
        value = os_health
      )),
      os_health > 80 ~ as.character(glue(
        template, 
        label = "OS Activity",
        colour = "green",
        value = os_health
      )),
      os_health > 60 ~ as.character(glue(
        template, 
        label = "OS Activity",
        colour = "yellowgreen",
        value = os_health
      )),
      os_health > 50 ~ as.character(glue(
        template, 
        label = "OS Activity",
        colour = "yellow",
        value = os_health
      )),
      os_health > 40 ~ as.character(glue(
        template, 
        label = "OS Activity",
        colour = "orange",
        value = os_health
      )),
      TRUE ~ as.character(glue(
        template, 
        label = "OS Activity",
        colour = "red",
        value = os_health
      ))
    )
  ) %>%
  select(
    full_name,
    badge_cran,
    badge_contributors,
    badge_health,
    badge_riskmetric
  )



## Upload

#write.csv(badges, glue("scratch/badges-{Sys.Date()}.csv"), row.names = FALSE)
write.csv(badges, glue("scratch/badges.csv"), row.names = FALSE)


