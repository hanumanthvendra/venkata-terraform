variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "dev-eks-cluster"
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_groups" {
  description = "Map of EKS node groups"
  type = map(object({
    desired_capacity = number
    max_capacity     = number
    min_capacity     = number
    instance_types   = list(string)
    key_name         = string
  }))
  default = {
    default = {
      desired_capacity = 2
      max_capacity     = 5
      min_capacity     = 1
      instance_types   = ["t3.medium"]
      key_name         = ""
    }
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
