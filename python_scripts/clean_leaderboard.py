import pandas as pd
from typing import List
from sklearn.preprocessing import MinMaxScaler
from datetime import datetime, timedelta

YEAR_RANGE = (datetime.today() - timedelta(days=365)).isoformat()


def preproc_people(df_people: pd.DataFrame)-> pd.DataFrame:
    try:
        df_people = df_people.dropna(subset=['author']).reset_index(drop=True)
        df_people["repo_list"] = df_people["repo_list"].fillna("").apply(lambda x: x.split(" | "))
    except:
        print("An exception occurred in preproc_people function")
    return df_people


def altruist_metric(df_people: pd.DataFrame, df_gh: pd.DataFrame)-> pd.DataFrame:
    try:
        scaler = MinMaxScaler()
        #From json to dataframe
        df_issues = df_gh.join(pd.json_normalize(df_gh['issues.edges'])).drop(columns=['issues.edges'])
        df_issues = df_issues.apply(lambda x: x.explode()).reset_index(drop=True)
        df_issues = df_issues.join(pd.json_normalize(df_issues['node.comments.nodes'])).drop(columns=['node.comments.nodes'])
        df_issues = df_issues.drop(columns=['author'])
        # Filter one year
        df_issues = df_issues[df_issues["node.createdAt"] >= YEAR_RANGE].reset_index(drop=True)
        #Merge with people csv list_repos post level and first comment level : df_gmh1-> post level ; df_gmh2 -> first comment level
        df_ghm1 = df_issues.merge(df_people[['author', 'repo_list']], how='left', left_on='node.author.login', right_on='author').drop(columns=['author'])
        df_ghm2 = df_issues.merge(df_people[['author', 'repo_list']], how='left', left_on='author.login', right_on='author').drop(columns=['author'])
        df_ghm2 = df_ghm2.dropna(subset=['repo_list']).reset_index(drop=True)
        df_ghm1 = df_ghm1.dropna(subset=['repo_list']).reset_index(drop=True)

        #filter data based on repo_list_contrib -> main difference between altruist metric and self-maintainer metric
        #post level
        binary_altruist = [a not in b for a, b in zip(df_ghm1['name'], df_ghm1['repo_list'])]
        df_ghm1 = df_ghm1[binary_altruist].reset_index(drop=True)
        #first comment level
        binary_fc = [a not in b for a, b in zip(df_ghm2['name'], df_ghm2['repo_list'])]
        df_ghm2 = df_ghm2[binary_fc].reset_index(drop=True)

        #Calculate metrics
        df_ghm1 = df_ghm1.groupby('node.author.login', as_index=False)[["node.comments.totalCount", "node.reactions.totalCount"]].sum()
        df_ghm1 = df_ghm1.rename(columns={"node.comments.totalCount": "#comments_altruist", "node.reactions.totalCount": "#reactions_altruist"})
        #Calculate metrics
        df_ghm2["reactions.totalCount"] += 1
        df_ghm2 = df_ghm2.groupby('author.login', as_index=False)[["reactions.totalCount"]].sum()
        df_ghm2 = df_ghm2.rename(columns={"reactions.totalCount": "#first_comments_altruist"})
        #Rename column
        df_people = df_people.merge(df_ghm1, how='left', left_on='author', right_on='node.author.login')
        df_people = df_people.merge(df_ghm2, how='left', left_on='author', right_on='author.login')

        #Scale metrics
        columns_metric = ["#comments_altruist", "#reactions_altruist", "#first_comments_altruist"]
        df_people[columns_metric] = df_people[columns_metric].fillna(0)
        df_people[["#m1_alt", "#m2_alt", "#m3_alt"]] = scaler.fit_transform(df_people[columns_metric])
        df_people["altruist_metric"] = 100*(df_people["#m1_alt"]+df_people["#m2_alt"]+df_people["#m3_alt"])/3
        df_people[["altruist_metric"]] = (100*scaler.fit_transform(df_people[["altruist_metric"]])).astype(int)
    except:
        print("An exception occurred in altruist metric function")
    return df_people


def self_maintainer_metric(df_people: pd.DataFrame, df_gh: pd.DataFrame)-> pd.DataFrame:
    try:
        scaler = MinMaxScaler()
        #From json to dataframe
        df_issues = df_gh.join(pd.json_normalize(df_gh['issues.edges'])).drop(columns=['issues.edges'])
        df_issues = df_issues.apply(lambda x: x.explode()).reset_index(drop=True)
        df_issues = df_issues.join(pd.json_normalize(df_issues['node.comments.nodes'])).drop(columns=['node.comments.nodes'])
        df_issues = df_issues.drop(columns=['author'])
        # Filter one year
        df_issues = df_issues[df_issues["node.createdAt"] >= YEAR_RANGE].reset_index(drop=True)
        #Merge with people csv list_repos post level and first comment level : df_gmh1-> post level ; df_gmh2 -> first comment level
        df_ghm1 = df_issues.merge(df_people[['author', 'repo_list']], how='left', left_on='node.author.login', right_on='author').drop(columns=['author'])
        df_ghm2 = df_issues.merge(df_people[['author', 'repo_list']], how='left', left_on='author.login', right_on='author').drop(columns=['author'])
        df_ghm2 = df_ghm2.dropna(subset=['repo_list']).reset_index(drop=True)
        df_ghm1 = df_ghm1.dropna(subset=['repo_list']).reset_index(drop=True)

        #filter data based on repo_list_contrib -> main difference between altruist metric and self-maintainer metric
        #post level
        binary_altruist = [a in b for a, b in zip(df_ghm1['name'], df_ghm1['repo_list'])]
        df_ghm1 = df_ghm1[binary_altruist].reset_index(drop=True)
        #first comment level
        binary_fc = [a in b for a, b in zip(df_ghm2['name'], df_ghm2['repo_list'])]
        df_ghm2 = df_ghm2[binary_fc].reset_index(drop=True)

        #Calculate metrics
        df_ghm1 = df_ghm1.groupby('node.author.login', as_index=False)[["node.comments.totalCount", "node.reactions.totalCount"]].sum()
        df_ghm1 = df_ghm1.rename(columns={"node.comments.totalCount": "#comments_self_maintainer", "node.reactions.totalCount": "#reactions_self_maintainer"})
        #Calculate metrics
        df_ghm2["reactions.totalCount"] += 1
        df_ghm2 = df_ghm2.groupby('author.login', as_index=False)[["reactions.totalCount"]].sum()
        df_ghm2 = df_ghm2.rename(columns={"reactions.totalCount": "#first_comments_self_maintainer"})
        #Rename column
        df_people = df_people.merge(df_ghm1, how='left', left_on='author', right_on='node.author.login')
        df_people = df_people.merge(df_ghm2, how='left', left_on='author', right_on='author.login')

        #Scale metrics
        columns_metric = ['#comments_self_maintainer', '#reactions_self_maintainer', '#first_comments_self_maintainer']
        df_people[columns_metric] = df_people[columns_metric].fillna(0)
        df_people[["#m1_sm", "#m2_sm", "#m3_sm"]] = scaler.fit_transform(df_people[columns_metric])
        df_people['self_maintainer_metric'] = 100*(df_people['#m1_sm']+df_people['#m2_sm']+df_people['#m3_sm'])/3
        df_people[['self_maintainer_metric']] = (100*scaler.fit_transform(df_people[['self_maintainer_metric']])).astype(int)
    except:
        print("An exception occurred in self maintainer metric function")
    return df_people


def coder_metric(df_people: pd.DataFrame, df_commits: pd.DataFrame, scope: str)-> pd.DataFrame:
    scaler = MinMaxScaler()
    df_pcopy = df_people.copy()
    df_pcopy = df_pcopy.drop(columns=["contributed_to", "commits"])
    # Filter for 12 months range
    df_commits = df_commits[df_commits["datetime"] >= YEAR_RANGE].reset_index(drop=True)
    # Filter for pharmaverse repos only
    if scope == "pharmaverse":
        PATH_PHARMAVERSE_PACKAGES = "scratch/pharmaverse_packages.csv"
        df_pharmaverse = pd.read_csv(PATH_PHARMAVERSE_PACKAGES)
        df_commits = df_commits[df_commits['full_name'].isin(df_pharmaverse['full_name'].to_list())].reset_index(drop=True)
    # Count all occurences of project involvment (full_name) and sha (number of commits)
    df_commits = df_commits.groupby(by="author", as_index=False).nunique()
    # Merge with people
    df_pcopy = df_pcopy.merge(df_commits[["author", "full_name", "sha"]], how='left', left_on='author', right_on='author')
    df_pcopy = df_pcopy.rename(columns = {"full_name": "contributed_to", "sha": "commits"})
    df_pcopy[["contributed_to", "commits"]] = df_pcopy[["contributed_to", "commits"]].fillna(0)

    df_pcopy[["contributed_to_metric", "commits_metric"]] = scaler.fit_transform(df_pcopy[["contributed_to", "commits"]])
    # Average of both
    df_pcopy["coder_metric"] = (df_pcopy["contributed_to_metric"]+df_pcopy["commits_metric"])/2
    #Scale coder metric
    df_pcopy[["coder_metric"]] = scaler.fit_transform(df_pcopy[["coder_metric"]])
    # Scale on 100
    df_pcopy["coder_metric"] = (100*df_pcopy['coder_metric']).astype(int)
    return df_pcopy


def main_overall_metric(path_people: str, path_gh_graphql: str, path_commits: str, scope: str)-> pd.DataFrame:
    df_people = pd.read_csv(path_people)
    df_commits = pd.read_csv(path_commits)
    try:
        df_gh = pd.read_parquet(path_gh_graphql)
        df_people = preproc_people(df_people)
        df_people = coder_metric(df_people=df_people, df_commits=df_commits, scope=scope)
        df1 = self_maintainer_metric(df_people=df_people, df_gh=df_gh)
        df_people = df_people.merge(df1[["author", "self_maintainer_metric","#comments_self_maintainer", "#reactions_self_maintainer", "#first_comments_self_maintainer", "#m1_sm", "#m2_sm", "#m3_sm"]], how="left", on="author")
        df2 = altruist_metric(df_people=df_people, df_gh=df_gh)
        df_people = df_people.merge(df2[["author", "altruist_metric", "#comments_altruist", "#reactions_altruist", "#first_comments_altruist", "#m1_alt", "#m2_alt", "#m3_alt"]], how="left", on="author")
        df_people["overall_metric"] = (df_people["coder_metric"]+df_people["self_maintainer_metric"]+df_people["altruist_metric"])/3
        df_people["overall_metric"] = (100*MinMaxScaler().fit_transform(df_people[["overall_metric"]])).astype(int)
        df_people["repo_list"] = df_people["repo_list"].apply(' | '.join)
    except:
        print("An exception occurred into main_overall_metric function")
    return df_people