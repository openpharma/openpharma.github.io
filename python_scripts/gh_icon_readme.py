import pandas as pd
import re


def get_icon_from_readme(df_readme: pd.DataFrame, df_repos: pd.DataFrame)-> pd.DataFrame:
    try:
        PATH_RLOGO = "https://openpharma.s3.us-east-2.amazonaws.com/streamlit_img/Rlogo.svg"
        PATH_PYTHONLOGO = "https://openpharma.s3.us-east-2.amazonaws.com/streamlit_img/Python.svg"

        df1 = df_readme.copy()
        df2 = df_repos.copy()

        df1["full_name"] = df1["owner.login"]+"/"+df1["name"]
        df1 = df1.drop_duplicates(subset=["full_name"]).reset_index(drop=True)
        df1 = df1.dropna(subset=["object.text"]).reset_index(drop=True)
        df1["object.text"] = df1["object.text"].apply(lambda x: x.replace('<img src="https://img.shields',""))
        df1["object.text"] = df1["object.text"].apply(lambda x: x.replace('<img src="http://pharmaverse.org',""))
        df1["object.text"] = df1["object.text"].apply(lambda x: x.replace("'",'"'))
        df1["object.text"] = df1["object.text"].apply(lambda x: x.replace("\'",'"'))
        df1["object.text"] = df1["object.text"].apply(lambda x: x.replace("\"",'"'))
        df1["icon_link_html"] = df1["object.text"].apply(lambda x:  re.search('<img src="(.*?)"', x[:300]).group(1) if (re.search('<img src="(.*?)"', x[:300])!=None) else "")
        #https://raw.githubusercontent.com/adibender/coalitions/HEAD/man/figures/logo.png

        df1["icon_link_html"] = df1.apply(lambda x: "https://raw.githubusercontent.com/"+x["full_name"]+"/HEAD/"+x["icon_link_html"] if ('https://' not in x["icon_link_html"] and x["icon_link_html"]!= '') else x["icon_link_html"], axis=1)

        #Merge with repos_clean
        df2 = df2.merge(df1[["full_name","icon_link_html"]], how="left", on="full_name")
        df2["icon_link_html"] = df2["icon_link_html"].fillna("")
        df2["icon_package"] = df2.apply(lambda x: x["icon_link_html"] if ((x["icon_package"]==PATH_RLOGO or x["icon_package"]==PATH_PYTHONLOGO) and x["icon_link_html"]!= "") else x["icon_package"], axis=1)
        df2 = df2.drop(columns=['icon_package_link', 'icon_link_html'])
    except:
        df2 = df_repos.copy()
    return df2