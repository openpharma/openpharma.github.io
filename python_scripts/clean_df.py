import pandas as pd
import os
import boto3



os.environ['AWS_ACCESS_KEY_ID'] = os.getenv('OPENPHARMA_AWS_ACCESS_KEY_ID')
os.environ['AWS_SECRET_ACCESS_KEY'] = os.getenv('OPENPHARMA_AWS_SECRET_ACCESS_KEY')

df = pd.read_csv("scratch/repos.csv")

df['description'] = df['cran_description']
df['title'] = df['cran_title']
df.loc[df['title'].isnull(), 'title'] = df['gh_description']
df.loc[df['description'].isnull(), 'description'] = df['gh_description']
df = df.dropna(subset=['title']).reset_index(drop=True)
df['Contributors'] = df['Contributors'].fillna(0)
df['Contributors'] = df['Contributors'].apply(lambda x: int(x))
df['riskmetric_score_quintile'] = df['riskmetric_score_quintile'].fillna(0)
df['os_health'] = df['os_health'].fillna(0)
df['lang'] = df['lang'].fillna('R')
df['cran_license'] = df['cran_license'].fillna('Other Licenses')
df['risk_column'] = (20*df['riskmetric_score_quintile']+df['os_health'])
df['risk_column'] = (100*df['risk_column']/df['risk_column'].max())
df['last_commit_d'] = (pd.to_datetime("today") - pd.to_datetime(df['Last Commit'])).dt.days.astype('Int64')


df.to_csv("scratch/repos_clean.csv")

client = boto3.client('s3',
    aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY')
)

client.upload_file(Filename='scratch/repos_clean.csv',
    Bucket='openpharma',
    Key='repos_clean.csv'
)