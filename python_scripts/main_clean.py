import os
import boto3
import clean_repos
import clean_openissues

"""
Env varibales for AWS S3 Bucket - data uploading there
"""

os.environ['AWS_ACCESS_KEY_ID'] = os.getenv('OPENPHARMA_AWS_ACCESS_KEY_ID')
os.environ['AWS_SECRET_ACCESS_KEY'] = os.getenv('OPENPHARMA_AWS_SECRET_ACCESS_KEY')

PATH_REPOS = "scratch/repos.csv"
PATH_HELP = "scratch/help.csv"


df_repos_clean = clean_repos.clean_merge_df(path=PATH_REPOS)
df_repos_clean.to_csv("scratch/repos_clean.csv", index=False)

df_openissues_clean = clean_openissues.clean_merge_df(path=PATH_HELP)
df_openissues_clean.to_csv("scratch/help_clean.csv", index=False)



client = boto3.client('s3',
    aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY')
)

client.upload_file(Filename='scratch/repos_clean.csv',
    Bucket='openpharma',
    Key='repos_clean.csv'
)

client.upload_file(Filename='scratch/help_clean.csv',
    Bucket='openpharma',
    Key='help_clean.csv'
)