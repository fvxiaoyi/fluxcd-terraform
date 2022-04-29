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
  }
}

provider "flux" {
  # Configuration options
}

provider "kubectl" {
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}
