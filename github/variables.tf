variable "github_owner" {
  type        = string
  description = "github owner"
  default     = "fvxiaoyi"
}

variable "github_token" {
  type        = string
  description = "github token"
  default     = "*"
}

variable "repository_name" {
  type        = string
  default     = "flux-cd"
  description = "github repository name"
}

variable "repository_visibility" {
  type        = string
  default     = "public"
  description = "How visible is the github repo"
}

variable "branch" {
  type        = string
  default     = "main"
  description = "branch name"
}

variable "target_path" {
  type        = string
  default     = "cluster"
  description = "flux sync target path"
}