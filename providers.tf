terraform {
  required_providers {
    flux = {
      source  = "fluxcd/flux"
      version = ">=0.13.5"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.10.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.2"
    }

    github = {
      source  = "integrations/github"
      version = ">= 4.5.2"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "3.1.0"
    }
  }
}

provider "flux" {
  # Configuration options
}

provider "kubectl" {
}

provider "kubernetes" {
  config_path = "/etc/rancher/k3s/k3s.yaml"
}

provider "github" {
  owner = var.github_owner
  token = var.github_token
}