import pandas as pd
import gh_icon_api

def clean_merge_df(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)
    df_icon = gh_icon_api.get_icon_package_gh_api()
    if(len(df_icon)>=1):
        df = df.merge(df_icon, how='left', on='full_name', suffixes=('', '_'))
        df['icon_package'] = df['icon_package'].fillna("https://openpharma.s3.us-east-2.amazonaws.com/streamlit_img/Rlogo.svg")
    else:
        df['icon_package'] = "https://openpharma.s3.us-east-2.amazonaws.com/streamlit_img/Rlogo.svg"
    return df