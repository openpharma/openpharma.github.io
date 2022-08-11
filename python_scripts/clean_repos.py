import pandas as pd
import gh_icon_api

def clean_license(x):
    if ('GPL' in x) and ('3' in x):
        return 'GPL-3'
    elif ('GPL' in x) and ('2' in x):
        return 'GPL-2'
    elif 'GPL' in x:
        return 'GPL-1'
    elif 'MIT' in x:
        return 'MIT'
    elif 'LGPL' in x:
        return 'LGPL 2 or 3'
    elif 'Apache License' in x:
        return 'Apache License'
    else:
        return 'Other Licenses'

def clean_merge_df(path: str) -> tuple([pd.DataFrame, pd.DataFrame]):
    df = pd.read_csv(path)
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
    df['license_clean'] = df['cran_license'].apply(clean_license)
    df['risk_column'] = ((100-20*df['riskmetric_score_quintile'])+df['os_health'])/2
    df['last_commit_d'] = (pd.to_datetime("today") - pd.to_datetime(df['Last Commit'])).dt.days.astype('Int64')
    df['icon_package_link'] = "https://openpharma.s3.us-east-2.amazonaws.com/streamlit_img/Rlogo.svg"
    df.loc[df['lang'] == "python", 'icon_package_link'] = "https://openpharma.s3.us-east-2.amazonaws.com/streamlit_img/python.png"

    df_icon = gh_icon_api.get_icon_package_gh_api()
    if(len(df_icon)>=1):
        df = df.merge(df_icon, how='left', on='full_name', suffixes=('', '_'))
        df['icon_package'] = df['icon_package'].fillna("https://openpharma.s3.us-east-2.amazonaws.com/streamlit_img/Rlogo.svg")
        df.loc[df['lang'] == "python", 'icon_package'] = "https://openpharma.s3.us-east-2.amazonaws.com/streamlit_img/Python.svg"
    else:
        df['icon_package'] = "https://openpharma.s3.us-east-2.amazonaws.com/streamlit_img/Rlogo.svg"
        df.loc[df['lang'] == "python", 'icon_package'] = "https://openpharma.s3.us-east-2.amazonaws.com/streamlit_img/Python.svg"
    return df, df_icon






