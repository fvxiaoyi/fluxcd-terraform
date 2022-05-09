terraform {
  required_version = ">= 0.13"

  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = ">= 3.11.1"
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
      version = ">= 0.11.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "3.1.0"
    }
    github = {
      source  = "integrations/github"
      version = "4.24.0"
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

provider "gitlab" {
  token = data.sops_file.secrets.data["gitlab_token"]
}

# SSH
locals {
  known_hosts = "gitlab.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFSMqzJeV9rUzU4kWitGjeR4PWSa29SPqJ1fVkhtj3Hw9xjLVXVYrU9QlYWrOLXBpQ6KWjbjTDTdDkoohFzgbEY="
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
  url         = "ssh://git@gitlab.com/${var.gitlab_owner}/${var.repository_name}.git"
  branch      = var.branch
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

# Gitlab
resource "gitlab_project" "main" {
  name                   = var.repository_name
  visibility_level       = var.repository_visibility
  initialize_with_readme = true
  default_branch         = var.branch
}

resource "gitlab_deploy_key" "main" {
  title   = "staging-cluster"
  project = gitlab_project.main.id
  key     = tls_private_key.main.public_key_openssh

  depends_on = [gitlab_project.main]
}

resource "gitlab_repository_file" "install" {
  project        = gitlab_project.main.id
  branch         = gitlab_project.main.default_branch
  file_path      = data.flux_install.main.path
  content        = base64encode(data.flux_install.main.content)
  commit_message = "Add ${data.flux_install.main.path}"

  depends_on = [gitlab_project.main]
}

resource "gitlab_repository_file" "sync" {
  project        = gitlab_project.main.id
  branch         = gitlab_project.main.default_branch
  file_path      = data.flux_sync.main.path
  content        = base64encode(data.flux_sync.main.content)
  commit_message = "Add ${data.flux_sync.main.path}"

  depends_on = [gitlab_repository_file.install]
}

resource "gitlab_repository_file" "kustomize" {
  project        = gitlab_project.main.id
  branch         = gitlab_project.main.default_branch
  file_path      = data.flux_sync.main.kustomize_path
  content        = base64encode(data.flux_sync.main.kustomize_content)
  commit_message = "Add ${data.flux_sync.main.kustomize_path}"

  depends_on = [gitlab_repository_file.sync]
}

locals {
  files = fileset(path.module, "../source/*.yaml")
  data  = [ for f in local.files : {
    name: basename(f)
    content: file("${path.module}/${f}")
  } ]
}

resource "gitlab_repository_file" "apps" {
  for_each = { for f in local.data : f.name => f }
  project        = gitlab_project.main.id
  branch         = gitlab_project.main.default_branch
  file_path      =  "/${var.target_path}/${each.value.name}"
  content        = each.value.content
  commit_message = "init flux cd"
}

data "local_file" "infrastructure" {
  filename = "../source/infrastructure.yaml"
}

resource "gitlab_repository_file" "infrastructure" {
  project        = gitlab_project.main.id
  branch         = gitlab_project.main.default_branch
  file_path      =  "/${var.target_path}/infrastructure.yaml"
  content        = data.local_file.apps.content
  commit_message = "init flux cd"

  depends_on = [gitlab_repository_file.install]
}

data "local_file" "flux-system-automation" {
  filename = "../source/flux-system-automation.yaml"
}

resource "gitlab_repository_file" "flux-system-automation" {
  project        = gitlab_project.main.id
  branch         = gitlab_project.main.default_branch
  file_path      =  "/${var.target_path}/flux-system-automation.yaml"
  content        = data.local_file.apps.content
  commit_message = "init flux cd"

  depends_on = [gitlab_repository_file.install]
}


data "local_file" "slack-alert" {
  filename = "../source/slack-alert.yaml"
}

resource "gitlab_repository_file" "slack-alert" {
  project        = gitlab_project.main.id
  branch         = gitlab_project.main.default_branch
  file_path      =  "/${var.target_path}/slack-alert.yaml"
  content        = data.local_file.apps.content
  commit_message = "init flux cd"

  depends_on = [gitlab_repository_file.install]
}

data "local_file" "slack-provider" {
  filename = "../source/slack-provider.yaml"
}

resource "gitlab_repository_file" "slack-provider" {
  project        = gitlab_project.main.id
  branch         = gitlab_project.main.default_branch
  file_path      =  "/${var.target_path}/slack-provider.yaml"
  content        = data.local_file.apps.content
  commit_message = "init flux cd"

  depends_on = [gitlab_repository_file.install]
}

data "local_file" "generic-receiver" {
  filename = "../source/generic-receiver.yaml"
}

resource "gitlab_repository_file" "generic-receiver" {
  project        = gitlab_project.main.id
  branch         = gitlab_project.main.default_branch
  file_path      =  "/${var.target_path}/generic-receiver.yaml"
  content        = data.local_file.apps.content
  commit_message = "init flux cd"

  depends_on = [gitlab_repository_file.install]
}
