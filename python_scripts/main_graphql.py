import os
import boto3
import pandas as pd
import gh_graphql_api

"""
Env varibales for AWS S3 Bucket - data uploading there
"""

os.environ['AWS_ACCESS_KEY_ID'] = os.getenv('OPENPHARMA_AWS_ACCESS_KEY_ID')
os.environ['AWS_SECRET_ACCESS_KEY'] = os.getenv('OPENPHARMA_AWS_SECRET_ACCESS_KEY')

PATH_REPOS_CLEAN = "scratch/repos_clean.csv"

df_repos_clean = pd.read_csv(PATH_REPOS_CLEAN)
df_open_issues, df_closed_issues = gh_graphql_api.main_gh_issues(df=df_repos_clean)
df_open_issues.to_csv("scratch/lead_open_issues.csv", index=False)
df_closed_issues.to_csv("scratch/lead_closed_issues.csv", index=False)

"""
AWS client
"""

client = boto3.client('s3',
    aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY')
)

client.upload_file(Filename='scratch/lead_open_issues.csv',
    Bucket='openpharma',
    Key='lead_open_issues.csv'
)

client.upload_file(Filename='scratch/lead_closed_issues.csv',
    Bucket='openpharma',
    Key='lead_closed_issues.csv'
)
