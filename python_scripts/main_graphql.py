import os
import boto3
import pandas as pd
import gh_graphql_issues

"""
Env varibales for AWS S3 Bucket - data uploading there
"""

os.environ['AWS_ACCESS_KEY_ID'] = os.getenv('OPENPHARMA_AWS_ACCESS_KEY_ID')
os.environ['AWS_SECRET_ACCESS_KEY'] = os.getenv('OPENPHARMA_AWS_SECRET_ACCESS_KEY')

PATH_REPOS_CLEAN = "scratch/repos_clean.csv"

df_repos_clean = pd.read_csv(PATH_REPOS_CLEAN)
df_people_clean = gh_graphql_issues.main_gh_issues(
    df_repos_clean=df_repos_clean
    )
df_people_clean.to_parquet("scratch/gh_leaderboard_raw.parquet")


"""
AWS client
"""
client = boto3.client('s3',
    aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY')
)

client.upload_file(Filename='scratch/gh_leaderboard_raw.parquet',
    Bucket='openpharma',
    Key='gh_leaderboard_raw.parquet'
)
