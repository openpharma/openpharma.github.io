import os
import boto3
import pandas as pd
import gh_issues_graphql
import clean_leaderboard

"""
Env varibales for AWS S3 Bucket - data uploading there
"""

os.environ['AWS_ACCESS_KEY_ID'] = os.getenv('OPENPHARMA_AWS_ACCESS_KEY_ID')
os.environ['AWS_SECRET_ACCESS_KEY'] = os.getenv('OPENPHARMA_AWS_SECRET_ACCESS_KEY')

PATH_REPOS_CLEAN = "scratch/repos_clean.csv"
PATH_GH_LEADERBOARD = "scratch/gh_leaderboard.parquet"
PATH_GH_LEADERBOARD_PHARMAVERSE = "scratch/gh_leaderboard_pharmaverse.parquet"
PATH_PEOPLE = "scratch/people.csv"
PATH_PEOPLE_CLEAN = "scratch/people_clean.csv"
PATH_PEOPLE_CLEAN_PHARMAVERSE = "scratch/people_clean_pharmaverse.csv"
PATH_COMMIT = "scratch/commits.csv"
PATH_PHARMAVERSE_PACKAGES = "scratch/pharmaverse_packages.csv"

#scope all contributors of packages
df_repos_clean = pd.read_csv(PATH_REPOS_CLEAN)
df_gh_leaderboard = gh_issues_graphql.main_gh_issues(
    df_repos_clean=df_repos_clean,
    scope="all"
    )
df_gh_leaderboard.to_parquet(PATH_GH_LEADERBOARD)

#pharmaverse scope
df_gh_leaderboard = gh_issues_graphql.main_gh_issues(
    df_repos_clean=df_repos_clean,
    scope="pharmaverse"
    )
df_gh_leaderboard.to_parquet(PATH_GH_LEADERBOARD_PHARMAVERSE)

# We clean people csv here and not in main_clean becauze we need repos_clean (otherwise cycle in DAG)
#scope all contributors of packages
df_people_clean = clean_leaderboard.main_overall_metric(
    path_people=PATH_PEOPLE,
    path_gh_graphql=PATH_GH_LEADERBOARD
    )
df_people_clean.to_csv(PATH_PEOPLE_CLEAN, index=False)

#pharmaverse scope
df_people_clean = clean_leaderboard.main_overall_metric(
    path_people=PATH_PEOPLE,
    path_gh_graphql=PATH_GH_LEADERBOARD_PHARMAVERSE
    )

#change the way of calculating best coder
df_people_clean = clean_leaderboard.best_coder_pharmaverse(
    df1=df_people_clean,
    path_commit=PATH_COMMIT,
    path_pharma=PATH_PHARMAVERSE_PACKAGES
)
#Additional function to recalculate commits and contrib on pharmaverse packages

df_people_clean.to_csv(PATH_PEOPLE_CLEAN_PHARMAVERSE, index=False)

"""
AWS client
"""
client = boto3.client('s3',
    aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY')
)

"""
Raw data in parquet format (bcz it preserves type contrarely to csv (dict and list))
"""
client.upload_file(Filename=PATH_GH_LEADERBOARD,
    Bucket='openpharma',
    Key='gh_leaderboard.parquet'
)

client.upload_file(Filename=PATH_GH_LEADERBOARD_PHARMAVERSE,
    Bucket='openpharma',
    Key='gh_leaderboard_pharmaverse.parquet'
)


"""
People clean data in csv format
"""
client.upload_file(Filename=PATH_PEOPLE_CLEAN,
    Bucket='openpharma',
    Key='people_clean.csv'
)

client.upload_file(Filename=PATH_PEOPLE_CLEAN_PHARMAVERSE,
    Bucket='openpharma',
    Key='people_clean_pharmaverse.csv'
)
