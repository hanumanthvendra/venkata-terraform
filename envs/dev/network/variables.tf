variable "name_prefix" {
  description = "Prefix for naming resources"
  type        = string
  default     = "dev"
}

variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC"
  type        = bool
  default     = true
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = false
}

variable "flow_logs_log_group" {
  description = "CloudWatch Log Group name for VPC Flow Logs"
  type        = string
  default     = "/aws/vpc/flowlogs"
}

variable "flow_logs_kms_key_id" {
  description = "KMS key ID for VPC Flow Logs encryption"
  type        = string
  default     = null
}

variable "vpc_endpoints" {
  description = "VPC Endpoints configuration"
  type = map(object({
    service_name        = string
    type                = string
    security_group_ids  = optional(list(string))
    subnet_ids          = optional(list(string))
    route_table_ids     = optional(list(string))
    private_dns_enabled = optional(bool, true)
    tags                = optional(map(string), {})
  }))
  default = {
    s3 = {
      service_name = "com.amazonaws.ap-south-1.s3"
      type         = "Gateway"
      route_table_ids = []  # Will be populated with private route table IDs
    }
    dynamodb = {
      service_name = "com.amazonaws.ap-south-1.dynamodb"
      type         = "Gateway"
      route_table_ids = []  # Will be populated with private route table IDs
    }
  }
}

variable "cluster_name" {
  description = "EKS cluster name for subnet tagging"
  type        = string
  default     = "dev-eks-cluster"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {
    Environment = "dev"
    Project     = "eks"
  }
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "nat_gateway_mode" {
  description = "NAT Gateway mode: 'shared' or 'dedicated'"
  type        = string
  default     = "shared"
  validation {
    condition     = contains(["shared", "dedicated"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be either 'shared' or 'dedicated'"
  }
}
