variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-auto-mode-3"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.33"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
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
  description = "Versions for EKS addons. Set to null to use most_recent"
  type = object({
    coredns                = optional(string, null)
    kube_proxy             = optional(string, null)
    vpc_cni                = optional(string, null)
    aws_ebs_csi_driver     = optional(string, null)
    eks_pod_identity_agent = optional(string, null)
  })
  default = {
    coredns                = "v1.12.4-eksbuild.1"  # Current version
    kube_proxy             = "v1.33.3-eksbuild.6"  # Current version
    vpc_cni                = "v1.20.2-eksbuild.1"  # Current version
    aws_ebs_csi_driver     = "v1.48.0-eksbuild.2"  # Current version
    eks_pod_identity_agent = "v1.3.8-eksbuild.2"   # Force redeploy
  }
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
