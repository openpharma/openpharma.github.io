import pandas as pd
import requests
import yaml

GITHUB_URL_ICON = 'https://api.github.com/repos/pharmaverse/pharmaverse/contents/data/packages'

def get_icon_package_gh_api(path: str=GITHUB_URL_ICON):
    try:
        response = requests.get(path)
        json_packages = [response.json()[i]['download_url'] for i in range(len(response.json()))]
        l_repo = []
        l_icon = []
        for x in json_packages:
            yaml_file = yaml.load(requests.get(x).text)
            if (yaml_file['repo'] != None and yaml_file['hex'] != None):
                l_repo.append(yaml_file['repo'])
                l_icon.append(yaml_file['hex'])
        d = {'full_name': l_repo, 'icon_package': l_icon}
        df = pd.DataFrame(d)
        return df
    except BaseException as error:
        print('An exception occurred: {}'.format(error))
        return pd.DataFrame()