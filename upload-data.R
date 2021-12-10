library(glue)
library(dplyr)


## Upload

library(aws.s3)
Sys.setenv(
  "AWS_ACCESS_KEY_ID" = Sys.getenv("OPENPHARMA_AWS_ACCESS_KEY_ID"),
  "AWS_SECRET_ACCESS_KEY" = Sys.getenv("OPENPHARMA_AWS_SECRET_ACCESS_KEY"),
  "AWS_DEFAULT_REGION" = Sys.getenv("OPENPHARMA_AWS_DEFAULT_REGION")
)

# Get contents
contents <- get_bucket(bucket = "openpharma", parse_response = TRUE) %>%
  data.table::rbindlist() %>%
  filter(Key != "index.html") %>%
  mutate(
    File = Key,
    MB = round(Size / 1048576,2),
    MB = case_when(
      MB > 0.01 ~ as.character(MB),
      TRUE ~ "<0.01"
    ),
    Location = glue("http://openpharma.s3-website.us-east-2.amazonaws.com/{Key}"),
    Updated = as.Date(LastModified)
  ) %>%
  select(
    File:Updated
  )




# Write new files
to_upload <- c(
  "repos","people","health","help","commits"
)

if (format(Sys.Date(), format = "%d") == "1") {
  for (i in to_upload) {
    put_object(
      file = glue("scratch/{i}-{Sys.Date()}.csv"), 
      object = glue("{i}-{Sys.Date()}.csv"), 
      bucket = "openpharma",verbose = FALSE
    )
  }
  
  # for (i in to_upload) {
  #   put_object(
  #     file = glue("scratch/{i}-{Sys.Date()}.rds"), 
  #     object = glue("{i}-{Sys.Date()}.rds"), 
  #     bucket = "openpharma",verbose = FALSE
  #   )
  # }
}

for (i in to_upload) {
  put_object(
    file = glue("scratch/{i}.csv"), 
    object = glue("{i}.csv"), 
    bucket = "openpharma",verbose = FALSE
  )
}

# for (i in to_upload) {
#   put_object(
#     file = glue("scratch/{i}.rds"), 
#     object = glue("{i}.rds"), 
#     bucket = "openpharma",verbose = FALSE
#   )
# }

put_object(
  file = glue("scratch/badges.csv"), 
  object = glue("badges.csv"), 
  bucket = "openpharma",verbose = TRUE
)
