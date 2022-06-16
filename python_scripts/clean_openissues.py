import pandas as pd
import gh_icon_api

def clean_merge_df(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    df_icon = gh_icon_api.get_icon_package_gh_api()
    if(len(df_icon)>=1):
        df = df.merge(df_icon, how='left', on='full_name', suffixes=('', '_'))
        df['icon_package'] = df['icon_package'].fillna("https://cran.r-project.org/Rlogo.svg")
    return df