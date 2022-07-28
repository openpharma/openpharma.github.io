import os
import boto3
import pandas as pd
import gh_icon_readme

"""
Env varibales for AWS S3 Bucket - data uploading there
"""

os.environ['AWS_ACCESS_KEY_ID'] = os.getenv('OPENPHARMA_AWS_ACCESS_KEY_ID')
os.environ['AWS_SECRET_ACCESS_KEY'] = os.getenv('OPENPHARMA_AWS_SECRET_ACCESS_KEY')

PATH_REPOS_CLEAN = "scratch/repos_clean.csv"
PATH_REPOS_CLEAN_ICON = "scratch/repos_clean_icon.csv"
PATH_README = "scratch/gh_leaderboard.parquet"

df_repos = pd.read_csv(PATH_REPOS_CLEAN)
df_readme = pd.read_parquet(PATH_README)

df_repos_clean = gh_icon_readme.get_icon_from_readme(
    df_readme=df_readme,
    df_repos=df_repos
)

df_repos_clean.to_csv(PATH_REPOS_CLEAN_ICON, index=False)

"""
AWS client
"""
client = boto3.client('s3',
    aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY')
)

"""
Resave repos clean
"""

client.upload_file(Filename=PATH_REPOS_CLEAN_ICON,
    Bucket='openpharma',
    Key='repos_clean.csv'
)