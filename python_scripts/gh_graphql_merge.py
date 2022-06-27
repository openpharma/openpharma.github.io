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
Calculate Author Contrib
"""
def author_contrib(df: pd.DataFrame)-> pd.DataFrame:
    try:
        df_ac = df.join(pd.json_normalize(df['issues.edges'])).drop(columns=['issues.edges'])
        df_ac['node.comments.totalCount'] += 1
        df_ac['node.reactions.totalCount'] += 1
        df_ac = df_ac.groupby('node.author.login', as_index=False)[['node.comments.totalCount', 'node.reactions.totalCount']].sum()
        df_ac = df_ac.rename(columns={"node.comments.totalCount": "P_comments", "node.reactions.totalCount": "P_reactions", "node.author.login": "author"})
    except:
        print("Error on columns header : JSON format from graphQL has changed")
        df_ac = pd.DataFrame()
    return df_ac


"""
Calculate Replier Contrib
"""
def replier_contrib(df: pd.DataFrame)-> tuple([pd.DataFrame, pd.DataFrame]):
    try:
        df_rc = df.join(pd.json_normalize(df['issues.edges'])).drop(columns=['issues.edges'])
        df_rc = df_rc.apply(lambda x: x.explode()).reset_index(drop=True)
        df_rc = df_rc.join(pd.json_normalize(df_rc['node.comments.nodes'])).drop(columns=['node.comments.nodes'])
        df_rc['reactions.totalCount'] += 1
        df_rc = df_rc.rename(columns={"owner.login": "repos_owner", "node.author.login": "author_issue", "author.login": "author_comment"})
        #Metric on first comment
        df_rc_firstcom = df_rc[df_rc['author_issue'] != df_rc['author_comment']].reset_index(drop=True)
        df_rc_firstcom = df_rc_firstcom[df_rc_firstcom['node.comments.totalCount']>0]
        df_rc_firstcom = df_rc_firstcom.groupby('node.title').first().reset_index()
        df_rc_firstcom = df_rc_firstcom.groupby('author_comment', as_index=False)[['reactions.totalCount']].sum()
        df_rc_firstcom = df_rc_firstcom.rename(columns={"reactions.totalCount": "FC_reactions", "author_comment": "author"})
        #Metric on comments
        df_rc_com = df_rc.drop(df_rc.groupby('node.title', as_index=False).nth(0).index).reset_index(drop=True)
        df_rc_com = df_rc_com.groupby('author_comment', as_index=False)[['reactions.totalCount']].sum()
        df_rc_com = df_rc_com.rename(columns={"reactions.totalCount": "C_reactions", "author_comment": "author"})
    except:
        print("Error on columns header : JSON format from graphQL has changed")
        df_rc_firstcom = pd.DataFrame()
        df_rc_com = pd.DataFrame()
    return df_rc_firstcom, df_rc_com

"""
Join with people table
"""
def merge_metrics_people(df_people: pd.DataFrame, df1: pd.DataFrame, df2: pd.DataFrame, df3: pd.DataFrame)-> pd.DataFrame:
    try:
        df_people = df_people.join(df1.set_index('author'), how='left', on='author')
        df_people = df_people.join(df2.set_index('author'), how='left', on='author')
        df_people = df_people.join(df3.set_index('author'), how='left', on='author')
        columns = ['P_comments', 'P_reactions', 'FC_reactions', 'C_reactions']
        df_people[columns] = df_people[columns].fillna(0)
        df_people['Best_author'] = df_people['P_comments']+df_people['P_reactions']
        df_people['Best_replier'] = df_people['FC_reactions']+df_people['C_reactions']
        # Cleaning stuff and formatting
        columns_clean = ['Best_replier', 'Best_author', 'P_comments', 'P_reactions', 'FC_reactions', 'C_reactions', 'days_last_active']
        df_people = df_people.dropna(subset=['author']).reset_index(drop=True)
        df_people['contributed_to'] = df_people['contributed_to'].fillna(0)
        df_people['days_last_active'] = df_people['days_last_active'].fillna(0)
        df_people[columns_clean] = df_people[columns_clean].astype(int)
    except:
        print("Issue to merge people.csv and data from open/closed issues")
    return df_people


"""
Main Function to call all previous functions
"""
def main_gh_issues(df_repos_clean: pd.DataFrame, df_people: pd.DataFrame):
    # Step 1 : Getting id_node for each repo
    # Step 2 : Get the data from graphQL API
    ids_list = get_node_id_repos(df_repos_clean)
    l_open, l_closed = get_issues_content(ids_node_list=ids_list)
    df_open, df_closed = transform_json_to_df(l_open=l_open, l_closed=l_closed)
    df_issues = concat_open_closed(df_open, df_closed)
    df_ac = author_contrib(df_issues)
    df_rc1, df_rc2 = replier_contrib(df_issues)
    df_final = merge_metrics_people(df_people=df_people, df1=df_ac, df2=df_rc1, df3=df_rc2)
    return df_final