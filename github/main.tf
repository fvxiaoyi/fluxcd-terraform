terraform {
  required_version = ">= 0.13"

  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 4.5.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.2"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.10.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = ">= 0.0.13"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "3.1.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = ">= 0.7.0"
    }
  }
}

provider "sops" {}

provider "flux" {}

provider "kubectl" {}

provider "kubernetes" {
  config_path = "/etc/rancher/k3s/k3s.yaml"
}

data "sops_file" "secrets" {
  source_file = "../secrets/secrets.enc.json"
}

provider "github" {
  # Configuration options
  owner = var.github_owner
  token = data.sops_file.secrets.data["github_token"]
}

# SSH
locals {
  known_hosts = "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
}

resource "tls_private_key" "main" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

# Flux
data "flux_install" "main" {
  target_path      = var.target_path
  components_extra = ["image-reflector-controller", "image-automation-controller"]
}

data "flux_sync" "main" {
  target_path = var.target_path
  url         = "ssh://git@github.com/${var.github_owner}/${var.repository_name}.git"
  branch      = var.branch
  interval    = 720
}

# Kubernetes
resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
    ]
  }
}

data "kubectl_file_documents" "install" {
  content = data.flux_install.main.content
}

data "kubectl_file_documents" "sync" {
  content = data.flux_sync.main.content
}

locals {
  install = [for v in data.kubectl_file_documents.install.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
  sync = [for v in data.kubectl_file_documents.sync.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
}

resource "kubectl_manifest" "install" {
  for_each   = { for v in local.install : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace.flux_system]
  yaml_body  = each.value
}

resource "kubectl_manifest" "sync" {
  for_each   = { for v in local.sync : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace.flux_system]
  yaml_body  = each.value
}

resource "kubernetes_secret" "main" {
  depends_on = [kubectl_manifest.install]

  metadata {
    name      = data.flux_sync.main.secret
    namespace = data.flux_sync.main.namespace
  }

  data = {
    identity       = tls_private_key.main.private_key_pem
    "identity.pub" = tls_private_key.main.public_key_pem
    known_hosts    = local.known_hosts
  }
}

# GitHub
resource "github_repository" "main" {
  name       = var.repository_name
  visibility = var.repository_visibility
  auto_init  = true
}

resource "github_branch_default" "main" {
  repository = github_repository.main.name
  branch     = var.branch
}

resource "github_repository_deploy_key" "main" {
  title      = "flux-cluster"
  repository = github_repository.main.name
  key        = tls_private_key.main.public_key_openssh
  read_only  = false
}

resource "github_repository_file" "install" {
  repository = github_repository.main.name
  file       = data.flux_install.main.path
  content    = data.flux_install.main.content
  branch     = github_branch_default.main.branch
}

resource "github_repository_file" "sync" {
  repository = github_repository.main.name
  file       = data.flux_sync.main.path
  content    = data.flux_sync.main.content
  branch     = github_branch_default.main.branch
}

resource "github_repository_file" "kustomize" {
  repository = github_repository.main.name
  file       = data.flux_sync.main.kustomize_path
  content    = data.flux_sync.main.kustomize_content
  branch     = github_branch_default.main.branch
}

# The project directory structure
locals {
  files = fileset(path.module, "../source/*.yaml")
  data = [for f in local.files : {
    name : basename(f)
    content : file("${path.module}/${f}")
  }]
}

resource "github_repository_file" "apps" {
  for_each       = { for f in local.data : f.name => f }
  repository     = github_repository.main.name
  file           = "${var.target_path}/${each.value.name}"
  content        = each.value.content
  branch         = github_branch_default.main.branch
  commit_message = "init flux cd"
}

resource "kubernetes_secret" "slack-url" {
  metadata {
    name      = "slack-url"
    namespace = "flux-system"
  }

  data = {
    address = data.sops_file.secrets.data["slack_url"]
  }
}

resource "kubernetes_secret" "webhook-token" {
  metadata {
    name      = "webhook-token"
    namespace = "flux-system"
  }

  data = {
    token = data.sops_file.secrets.data["webhook_token"]
  }
}

data "sops_file" "sops" {
  source_file = "../secrets/sop.enc.asc"
  input_type  = "raw"
}

resource "kubernetes_secret" "sops-gpg" {
  metadata {
    name      = "sops-gpg"
    namespace = "flux-system"
  }

  data = {
    "sops.asc" = data.sops_file.sops.raw
  }
}

resource "github_repository_file" "app-base-folders" {
  repository     = github_repository.main.name
  branch         = github_repository.main.default_branch
  file           = "apps/base/README.md"
  content        = "base apps definition."
  commit_message = "init flux cd"
}

resource "github_repository_file" "app-overlays-folders" {
  repository     = github_repository.main.name
  branch         = github_repository.main.default_branch
  file           = "apps/overlays/README.md"
  content        = "apps diff env config."
  commit_message = "init flux cd"
}

resource "github_repository_file" "infrastructure-source-folders" {
  repository     = github_repository.main.name
  branch         = github_repository.main.default_branch
  file           = "infrastructure/source/README.md"
  content        = "HelmRepository, ImageRepository definition."
  commit_message = "init flux cd"
}