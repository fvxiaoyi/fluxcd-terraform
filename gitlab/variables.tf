variable "gitlab_owner" {
  description = "gitlab owner"
  type        = string
  default     = "ebinsu"
}

variable "repository_name" {
  description = "gitlab repository name"
  type        = string
  default     = "flux"
}

variable "repository_visibility" {
  description = "how visible is the gitlab repo"
  type        = string
  default     = "public"
}

variable "target_path" {
  description = "flux sync target path"
  type        = string
  default     = "cluster"
}

variable "kubernetes_config_path" {
  description = "kubernetes config path"
  type        = string
  default     = "/etc/rancher/k3s/k3s.yaml"
}
