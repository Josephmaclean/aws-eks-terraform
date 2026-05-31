variable "namespace" {
  description = "Namespace where Argo CD will be installed."
  type        = string
}

variable "chart_version" {
  description = "Argo CD Helm chart version."
  type        = string
}

variable "server_service_type" {
  description = "Kubernetes Service type for argocd-server."
  type        = string
}

variable "values" {
  description = "Additional values merged into the Argo CD Helm chart."
  type        = any
  default     = {}
}
