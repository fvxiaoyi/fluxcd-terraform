terraform {
  required_version = ">= 0.13"

  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 4.5.2"
    }
  }
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}

# GitHub
resource "github_repository" "main" {
  name       = var.repository_name
  visibility = var.repository_visibility
  auto_init  = true
}

resource "github_branch" "development" {
  repository = github_repository.main.name
  branch     = "main"
}

resource "github_repository_file" "install" {
  repository = github_repository.main.name
  file       = "/a"
  content    = "a"
  branch     = var.branch
}
