import os
import boto3
import pandas as pd
import gh_graphql_merge

"""
Env varibales for AWS S3 Bucket - data uploading there
"""

os.environ['AWS_ACCESS_KEY_ID'] = os.getenv('OPENPHARMA_AWS_ACCESS_KEY_ID')
os.environ['AWS_SECRET_ACCESS_KEY'] = os.getenv('OPENPHARMA_AWS_SECRET_ACCESS_KEY')

PATH_REPOS_CLEAN = "scratch/repos_clean.csv"
PATH_PEOPLE = "scratch/people.csv"

df_repos_clean = pd.read_csv(PATH_REPOS_CLEAN)
df_people = pd.read_csv(PATH_PEOPLE)
df_people_clean = gh_graphql_merge.main_gh_issues(
    df_repos_clean=df_repos_clean, 
    df_people=df_people
    )
df_people_clean.to_csv("scratch/people_clean.csv", index=False)


"""
AWS client
"""
client = boto3.client('s3',
    aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY')
)

client.upload_file(Filename='scratch/people_clean.csv',
    Bucket='openpharma',
    Key='people_clean.csv'
)
