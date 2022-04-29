variable "gitlab_owner" {
  description = "gitlab owner"
  type        = string
  default     = "ebinsu"
}

variable "gitlab_token" {
  description = "gitlab token"
  type        = string
  sensitive   = true
  default     = "*"
}

variable "repository_name" {
  description = "gitlab repository name"
  type        = string
  default     = "flux-cd"
}

variable "repository_visibility" {
  description = "how visible is the gitlab repo"
  type        = string
  default     = "public"
}

variable "branch" {
  description = "branch name"
  type        = string
  default     = "main"
}

variable "target_path" {
  description = "flux sync target path"
  type        = string
  default     = "cluster/staging"
}