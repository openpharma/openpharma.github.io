from ctypes import Union
import os
import requests
import yaml
import pandas as pd
from typing import List

GITHUB_URL_ICON = 'https://api.github.com/repos/pharmaverse/pharmaverse/contents/data/packages'
OPENPHARMA_PAT = os.getenv('OPENPHARMA_PAT')
AUTH_NAME = 'MathieuCayssol'
PATH_GRAPHQL_API = 'https://api.github.com/graphql'


"""
Getting nodes ID to iterate over all issues in all repos using graphQL
(Filter repos with at least 1 open issue)
"""
def get_node_id_repos(df: pd.DataFrame)-> List[str]:
    list_path = ['https://api.github.com/repos/{}'.format(x) for x in df['full_name'].to_list()]
    ids_list = []
    for i in range(0, len(list_path)):
        try:
            response = requests.get(list_path[i], auth=(AUTH_NAME, OPENPHARMA_PAT))
            if(response.json()['open_issues'] > 0):
                ids_list.append(response.json()['node_id'])
        except BaseException as error:
            print('An exception occurred: {}'.format(error))
    return ids_list

"""
Internal function for get_issues_content
"""
def flatten_output(l_1: List[dict], l_2: List[dict])-> tuple([List[dict], List[dict]]):
    l_o = []
    l_c = []
    if(len(l_1)==len(l_2)):
        for i in range(len(l_1)):
            for j in range(len(l_1[i]['data']['nodes'])):
                l_o.append(l_1[i]['data']['nodes'][j])
                l_c.append(l_2[i]['data']['nodes'][j])
    return l_o, l_c


"""
Getting open issues reactions, comments, author and so one
- for each repos : 
    - 50 most recent issues (OPEN and CLOSED)
    - Author
    - Reactions
    - #comments
    - 1st comment
        - Reactions
        - Author
"""
def get_issues_content(ids_node_list: List[str])-> tuple([List[dict], List[dict]]): 
    #Divide list in sublist of size 10, why ? -> tradoff between #nodes and #request
    l_o = []
    l_c = []
    l_open = []
    l_closed = []
    if(len(ids_node_list) >= 0):
        ids_node_list_divided = [ids_node_list[i:i+10] for i in range(0, len(ids_node_list), 10)]
        #try:
        # len(ids_node_list)/10 requests
        for i in range(0, len(ids_node_list_divided)):
            try:
                query = """query($list_ids: [ID!]!, $status: [IssueState!]) {
                            rateLimit{
                                cost
                            }
                            nodes(ids: $list_ids) {
                                ... on Repository {
                                name
                                owner {
                                    login
                                }
                                object(expression: "HEAD:README.md") {
                                    ... on Blob {
                                        text
                                    }
                                }
                                issues(first: 50, states: $status, orderBy: {field: UPDATED_AT, direction: DESC}) {
                                edges{
                                    node{
                                        title
                                        author{
                                            login
                                        }
                                        comments(first: 1){
                                            totalCount
                                            nodes{
                                            author{
                                                login
                                            }
                                            reactions(first: 30) {
                                                totalCount
                                            }
                                        }
                                    }
                                    reactions(first: 30) {
                                        totalCount
                                    }
                                    }
                                }
                                }
                            }
                            }
                            }"""
                #OPEN ISSUES
                
                variables1 = {'list_ids': ids_node_list_divided[i], 'status': 'OPEN'}
                response1 = requests.post(
                    url=PATH_GRAPHQL_API,
                    json={'query': query, 'variables': variables1}, 
                    auth=(AUTH_NAME, OPENPHARMA_PAT)
                )
                #CLOSED ISSUES
                variables2 = {'list_ids': ids_node_list_divided[i], 'status': 'CLOSED'}
                response2 = requests.post(
                    url=PATH_GRAPHQL_API, 
                    json={'query': query, 'variables': variables2}, 
                    auth=(AUTH_NAME, OPENPHARMA_PAT)
                )
                print("Response open issues status :", response1.status_code)
                print("Response closed issues status :", response2.status_code)
                if(response1.status_code == 200 and response2.status_code == 200):
                    l_o.append(response1.json())
                    l_c.append(response2.json())

            #Flatten the output -> the granularity will be repos by repos
            except BaseException as error:
                print('An exception occurred: {}'.format(error))
        l_open, l_closed = flatten_output(l_o, l_c)
    return l_open, l_closed

"""
Transform JSON into pandas dataframe
"""
def transform_json_to_df(l_open: List[dict], l_closed: List[dict])-> tuple([pd.DataFrame, pd.DataFrame]):
    df_open = pd.json_normalize(l_open)
    df_closed = pd.json_normalize(l_closed)
    df_open = df_open.apply(lambda x: x.explode()).reset_index(drop=True)
    df_closed = df_closed.apply(lambda x: x.explode()).reset_index(drop=True)
    return df_open, df_closed

"""
Concat open and closed issues
"""
def concat_open_closed(df1: pd.DataFrame, df2: pd.DataFrame)-> pd.DataFrame: 
    frames = [df1, df2]
    return pd.concat(frames, ignore_index=True)



"""
Main Function to call all previous functions
"""
def main_gh_issues(df_repos_clean: pd.DataFrame, scope: str)-> pd.DataFrame:
    # Step 1 : Getting id_node for each repo
    # Step 2 : Get the data from graphQL API
    ids_list = get_node_id_repos(df_repos_clean)
    l_open, l_closed = get_issues_content(ids_node_list=ids_list)
    df_open, df_closed = transform_json_to_df(l_open=l_open, l_closed=l_closed)
    if (scope=="all"):
        df_issues = concat_open_closed(df_open, df_closed)
    if(scope=="pharmaverse"):
        df_issues = concat_open_closed(df_open, df_closed)
        df_pharmaverse = pd.read_csv("scratch/pharmaverse_packages.csv")
        df_issues['full_name'] = df_issues['owner.login']+"/"+df_issues['name']
        df_issues = df_issues[df_issues["full_name"].isin(df_pharmaverse['full_name'].to_list())].reset_index(drop=True)
    return df_issues