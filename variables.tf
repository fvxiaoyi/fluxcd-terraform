variable "github_owner" {
  type    = string
  default = "fvxiaoyi"
}

variable "github_token" {
  type    = string
  default = "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"
}

variable "repository_name" {
  type    = string
  default = "fluxcd"
}

variable "repository_visibility" {
  type    = string
  default = "public"
}

variable "branch" {
  type    = string
  default = "main"
}

variable "target_path" {
  type    = string
  default = "clusters/staging-cluster"
}