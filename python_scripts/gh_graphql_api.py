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
    - 15 first comments
        - Reactions
        - Author
"""
def get_issues_content(ids_node_list: List[str])-> tuple([List[dict], List[dict]]): 
    #Divide list in sublist of size 50
    l_o = []
    l_c = []
    l_open = []
    l_closed = []
    if(len(ids_node_list) >= 0):
        ids_node_list_divided = [ids_node_list[i:i+10] for i in range(0, len(ids_node_list), 10)]
        #try:
        # len(ids_node_list)/10 requests
        for i in range(0, len(ids_node_list_divided)):
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
                            issues(first: 50, states: $status, orderBy: {field: UPDATED_AT, direction: DESC}) {
                            edges{
                                node{
                                    title
                                    author{
                                        login
                                    }
                                    comments(first: 15){
                                        totalCount
                                        nodes{
                                        author{
                                            login
                                        }
                                        reactions(first: 15) {
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
            variables = {'list_ids': ids_node_list_divided[i], 'status': 'OPEN'}
            response = requests.post(
                url=PATH_GRAPHQL_API,
                json={'query': query, 'variables': variables}, 
                auth=(AUTH_NAME, OPENPHARMA_PAT)
            )
            l_o.append(response.json())
            #CLOSED ISSUES
            variables = {'list_ids': ids_node_list_divided[i], 'status': 'CLOSED'}
            response = requests.post(
                url=PATH_GRAPHQL_API, 
                json={'query': query, 'variables': variables}, 
                auth=(AUTH_NAME, OPENPHARMA_PAT)
            )
            l_c.append(response.json())

            #Flatten the output -> the granularity will be repos by repos
        l_open, l_closed = flatten_output(l_o, l_c)
        #except BaseException as error:
            #print('An exception occurred: {}'.format(error))
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
Final Function to call all previous functions
"""
def main_gh_issues(df: pd.DataFrame):
    # Step 1 : Getting id_node for each repo
    # Step 2 : Get the data from graphQL API
    ids_list = get_node_id_repos(df)
    l_open, l_closed = get_issues_content(ids_node_list=ids_list)
    df_open, df_closed = transform_json_to_df(l_open=l_open, l_closed=l_closed)
    return df_open, df_closed