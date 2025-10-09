variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the service account"
  type        = string
  default     = "default"
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account"
  type        = string
  default     = "secrets-sa"
}

variable "secrets_manager_arns" {
  description = "List of AWS Secrets Manager ARNs that the role can access"
  type        = list(string)
  default     = ["*"]
}

variable "create_service_account" {
  description = "Whether to create the Kubernetes service account"
  type        = bool
  default     = true
}

variable "create_pod_identity_association" {
  description = "Whether to create the EKS Pod Identity Association"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
