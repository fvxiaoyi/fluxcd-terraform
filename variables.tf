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