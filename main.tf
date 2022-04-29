terraform {
  required_providers {
    flux = {
      source = "fluxcd/flux"
      version = ">=0.13.5"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.10.0"
    }
  }
}

provider "flux" {
  # Configuration options
}

provider "kubectl" {
}

# Generate manifests
data "flux_install" "main" {
  target_path    = "clusters/my-cluster"
  network_policy = false
}

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

# Split multi-doc YAML with
# https://registry.terraform.io/providers/gavinbunney/kubectl/latest
data "kubectl_file_documents" "apply" {
  content = data.flux_install.main.content
}

# Convert documents list to include parsed yaml data
locals {
  apply = [ for v in data.kubectl_file_documents.apply.documents : {
    data: yamldecode(v)
    content: v
  }
  ]
}

# Apply manifests on the cluster
resource "kubectl_manifest" "apply" {
  for_each   = { for v in local.apply : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace.flux_system]
  yaml_body = each.value
}