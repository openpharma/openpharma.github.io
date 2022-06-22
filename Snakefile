rule read_yaml:
    input: 
        "scripts/scrape-packages.R",
        "openpharma_included.yaml"
    output: "scratch/yaml_repos.rds"
    shell: "Rscript scripts/scrape-packages.R"
    
rule get_s3_old_data:
    input: "scripts/scrape-s3.R"
    output: 
        "scratch/commits_s3.rds",
        "scratch/people_s3.rds",
        "scratch/repos_s3.rds"
    shell: "Rscript scripts/scrape-s3.R"
    
rule get_metacran:
    input: "scripts/scrape-metacran.R", "scratch/yaml_repos.rds"
    output: "scratch/metacran_repos.rds"
    shell: "Rscript scripts/scrape-metacran.R"
    
rule get_riskmetric:
    input: "scripts/scrape-riskmetric.R", "scratch/yaml_repos.rds"
    output: "scratch/riskmetric.rds"
    shell: "Rscript scripts/scrape-riskmetric.R"
    
rule get_github:
    input: 
        "scripts/scrape-github.R", 
        "scratch/yaml_repos.rds",
        "scratch/commits_s3.rds",
        "scratch/people_s3.rds"
    output: 
        "scratch/gh_commits.rds",
        "scratch/gh_issues.rds",
        "scratch/gh_people.rds",
        "scratch/gh_repos.rds",
        "scratch/gh_issues_help.rds"
    shell: "Rscript scripts/scrape-github.R"
    
rule merge_data:
    input: 
        "scripts/merge-data.R", 
        "scratch/yaml_repos.rds",
        "scratch/gh_commits.rds",
        "scratch/gh_issues.rds",
        "scratch/gh_people.rds",
        "scratch/gh_repos.rds",
        "scratch/gh_issues_help.rds",
        "scratch/metacran_repos.rds",
        "scratch/commits_s3.rds",
        "scratch/people_s3.rds",
        "scratch/repos_s3.rds",
        "scratch/riskmetric.rds"
    output: 
        "scratch/repos.csv",
        "scratch/people.csv",
        "scratch/help.csv",
        "scratch/help.rds",
        "scratch/repos.rds",
        "scratch/people.rds",
        "scratch/commits.rds",
        "scratch/commits.csv"
    shell: "Rscript scripts/merge-data.R"


rule python_clean_data:
    input:
        "python_scripts/main_clean.py",
        "scratch/repos.csv",
        "scratch/people.csv",
        "scratch/help.csv",
        "scratch/commits.csv"
    output:
        "scratch/repos_clean.csv",
        "scratch/help_clean.csv"
    shell: "python3 python_scripts/main_clean.py"


rule python_scraping_issues_graphql:
    input:
        "python_scripts/main_graphql.py",
        "scratch/repos_clean.csv"
    output:
        "scratch/lead_open_issues.csv",
        "scratch/lead_closed_issues.csv"
    shell: "python3 python_scripts/main_graphql.py"


rule generate_badges:
    input: "scripts/generate-badges.R", "scratch/repos.rds"
    output: "scratch/badges.csv"
    shell: "Rscript scripts/generate-badges.R"
    
rule upload_data:
    input: 
        "scripts/upload-data.R", 
        "scratch/repos.csv",
        "scratch/people.csv",
        "scratch/help.csv",
        "scratch/badges.csv",
        "scratch/commits.csv"
    output: 
        "scratch/contents.rds"
    shell: "Rscript scripts/upload-data.R"
    
rule generate_website:
    input: 
        "index.Rmd", 
        "scratch/commits.rds",
        "scratch/help.rds",
        "scratch/badges.csv",
        "scratch/repos.rds",
        "scratch/people.rds"
    output: 
        report("index.html")
    shell: 
        """
        Rscript -e "rmarkdown::render(
            'index.Rmd', 
            output_dir = '.'
        )"
        """
        
rule os_health:
    input: 
        "os-health.Rmd", 
        "scratch/repos.rds"
    output: 
        report("os-health.html")
    shell: 
        """
        Rscript -e "rmarkdown::render(
            'os-health.Rmd', 
            output_dir = '.'
        )"
        """


rule all:
    input: 
        "index.html",
        "os-health.html",
        "scratch/contents.rds"