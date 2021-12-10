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
        colour = "red",
        value = riskmetric_score
      )),
      riskmetric_score_quintile == 2 ~ as.character(glue(
        template, 
        label = "riskmetric",
        colour = "orange",
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
        colour = "green",
        value = riskmetric_score
      )),
      riskmetric_score_quintile == 5 ~ as.character(glue(
        template, 
        label = "riskmetric",
        colour = "brightgreen",
        value = riskmetric_score
      ))
    ),
    # health --------------
    badge_health = case_when(
      is.na(Health) ~ as.character(glue(
        template, 
        label = "Health",
        colour = "red",
        value = 0
      )),
      Health > 90 ~ as.character(glue(
        template, 
        label = "Health",
        colour = "brightgreen",
        value = Health
      )),
      Health > 80 ~ as.character(glue(
        template, 
        label = "Health",
        colour = "green",
        value = Health
      )),
      Health > 60 ~ as.character(glue(
        template, 
        label = "Health",
        colour = "yellowgreen",
        value = Health
      )),
      Health > 50 ~ as.character(glue(
        template, 
        label = "Health",
        colour = "yellow",
        value = Health
      )),
      Health > 40 ~ as.character(glue(
        template, 
        label = "Health",
        colour = "orange",
        value = Health
      )),
      TRUE ~ as.character(glue(
        template, 
        label = "Health",
        colour = "red",
        value = Health
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

write.csv(badges, glue("scratch/badges-{Sys.Date()}.csv"), row.names = FALSE)
write.csv(badges, glue("scratch/badges.csv"), row.names = FALSE)

library(aws.s3)
Sys.setenv(
  "AWS_ACCESS_KEY_ID" = Sys.getenv("OPENPHARMA_AWS_ACCESS_KEY_ID"),
  "AWS_SECRET_ACCESS_KEY" = Sys.getenv("OPENPHARMA_AWS_SECRET_ACCESS_KEY"),
  "AWS_DEFAULT_REGION" = Sys.getenv("OPENPHARMA_AWS_DEFAULT_REGION")
)



  put_object(
    file = glue("scratch/badges.csv"), 
    object = glue("badges.csv"), 
    bucket = "openpharma",verbose = TRUE
  )


# for (i in to_upload) {
#   put_object(
#     file = glue("scratch/{i}.rds"), 
#     object = glue("{i}.rds"), 
#     bucket = "openpharma",verbose = FALSE
#   )
# }