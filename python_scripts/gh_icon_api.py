import os
import pandas as pd
import yaml
import requests
from requests.adapters import HTTPAdapter
from requests.packages.urllib3.util.retry import Retry

#another try

GITHUB_URL_ICON = 'https://api.github.com/repos/pharmaverse/pharmaverse/contents/data/packages'
OPENPHARMA_PAT = os.getenv('OPENPHARMA_PAT')
AUTH_NAME = 'MathieuCayssol'

def get_icon_package_gh_api(path: str=GITHUB_URL_ICON):
    try:
        session = requests.Session()
        retry = Retry(connect=3, backoff_factor=0.5)
        adapter = HTTPAdapter(max_retries=retry)
        session.mount('http://', adapter)
        session.mount('https://', adapter)
        response = requests.get(path, auth=(AUTH_NAME, OPENPHARMA_PAT))
        json_packages = [response.json()[i]['download_url'] for i in range(len(response.json()))]
        l_repo = []
        l_icon = []
        print("Breakpoint")
        for x in json_packages:
            yaml_file = yaml.load(requests.get(x, auth=(AUTH_NAME, OPENPHARMA_PAT)).text)
            if (yaml_file['repo'] != None and yaml_file['hex'] != None):
                l_repo.append(yaml_file['repo'])
                l_icon.append(yaml_file['hex'])
        d = {'full_name': l_repo, 'icon_package': l_icon}
        df = pd.DataFrame(d)
        return df
    except BaseException as error:
        print('An exception occurred: {}'.format(error))
        return pd.DataFrame()