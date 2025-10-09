variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.33"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "enable_public_access" {
  description = "Enable public access to EKS cluster endpoint"
  type        = bool
  default     = true
}

variable "node_pools" {
  description = "List of node pools for EKS Auto Mode"
  type        = list(string)
  default     = ["general-purpose"]
}

variable "addon_versions" {
  description = "Versions for EKS addons"
  type = object({
    coredns                = optional(string, null)
    kube_proxy             = optional(string, null)
    vpc_cni                = optional(string, null)
    aws_ebs_csi_driver     = optional(string, null)
    eks_pod_identity_agent = optional(string, null)
  })
  default = {
    coredns                = null  # Uses most_recent when null
    kube_proxy             = null
    vpc_cni                = null
    aws_ebs_csi_driver     = null
    eks_pod_identity_agent = null
  }
}

variable "install_alb_controller" {
  description = "Whether to install AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "annotate_ebs_csi_sa" {
  description = "Whether to annotate EBS CSI Driver service account"
  type        = bool
  default     = true
}

variable "secrets_namespace" {
  description = "Kubernetes namespace for secrets service account"
  type        = string
  default     = "default"
}

variable "secrets_service_account_name" {
  description = "Name of the Kubernetes service account for secrets"
  type        = string
  default     = "secrets-sa"
}

variable "secrets_manager_arns" {
  description = "List of AWS Secrets Manager ARNs that can be accessed"
  type        = list(string)
  default     = ["*"]
}

variable "create_secrets_service_account" {
  description = "Whether to create the secrets service account"
  type        = bool
  default     = true
}

variable "create_secrets_pod_identity" {
  description = "Whether to create the secrets pod identity association"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB ELB role tagging"
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ALB internal-elb role tagging"
  type        = list(string)
  default     = []
}
