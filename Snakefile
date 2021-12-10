rule read_yaml:
    input: "scrape-packages.R"
    output: "scratch/yaml_repos.rds"
    shell: "Rscript scrape-packages.R"
    
rule get_s3_old_data:
    input: "scrape-s3.R"
    output: 
        "scratch/commits_s3.rds",
        "scratch/people_s3.rds",
        "scratch/repos_s3.rds"
    shell: "Rscript scrape-s3.R"
    
rule get_metacran:
    input: "scrape-metacran.R", "scratch/yaml_repos.rds"
    output: "scratch/metacran_repos.rds"
    shell: "Rscript scrape-metacran.R"
    
rule get_riskmetric:
    input: "scrape-riskmetric.R", "scratch/yaml_repos.rds"
    output: "scratch/riskmetric.rds"
    shell: "Rscript scrape-riskmetric.R"
    
rule get_github:
    input: 
        "scrape-github.R", 
        "scratch/yaml_repos.rds",
        "scratch/repos_s3.rds"
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
        "scratch/metacran_repos.rds",
        "scratch/commits_s3.rds",
        "scratch/people_s3.rds",
        "scratch/repos_s3.rds",
        "scratch/riskmetric.rds"
    output: 
        "scratch/repos.csv",
        "scratch/people.csv",
        "scratch/help.csv",
        "scratch/repos.rds",
        "scratch/people.rds",
        "scratch/commits.rds"
    shell: "Rscript merge-data.R"
    
rule generate_badges:
    input: "generate-badges.R", "scratch/repos.rds"
    output: "scratch/badges.csv"
    shell: "Rscript generate-badges.R"
    
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


rule all:
    input: 
        "index.html"