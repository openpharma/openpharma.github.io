rule read_yaml:
    input: "scrape-packages.R"
    output: "scratch/yaml_repos.rds"
    shell: "Rscript scrape-packages.R"
    
rule get_metacran:
    input: "scrape-metacran.R", "scratch/yaml_repos.rds"
    output: "scratch/metacran_repos.rds"
    shell: "Rscript scrape-metacran.R"
    
rule get_github:
    input: "scrape-github.R", "scratch/yaml_repos.rds"
    output: 
        "scratch/gh_commits.rds",
        "scratch/gh_issues.rds",
        "scratch/gh_people.rds",
        "scratch/gh_repos.rds"
    shell: "Rscript scrape-github.R"
    
rule merge_data:
    input: 
        "merge-data.R", 
        "scratch/yaml_repos.rds",
        "scratch/gh_commits.rds",
        "scratch/gh_issues.rds",
        "scratch/gh_people.rds",
        "scratch/gh_repos.rds",
        "scratch/metacran_repos.rds"
    output: 
        "scratch/repos.csv",
        "scratch/people.csv",
        "scratch/help.csv",
        "scratch/repos.rds",
        "scratch/people.rds"
    shell: "Rscript merge-data.R"
    
rule upload_data:
    input: 
        "upload-data.R", 
        "scratch/repos.csv",
        "scratch/people.csv",
        "scratch/help.csv",
        "scratch/repos.rds",
        "scratch/people.rds"
    output: 
        "scratch/contents.rds"
    shell: "Rscript upload-data.R"
    
rule generate_website:
    input: 
        "index.Rmd", 
        "scratch/repos.csv",
        "scratch/people.csv",
        "scratch/help.csv",
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


rule all:
    input: 
        "index.html"