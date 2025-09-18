variable "name_prefix" {
  description = "Prefix for naming resources"
  type        = string
  default     = "eks"
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
  default     = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
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

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_logs_log_group" {
  description = "CloudWatch Log Group name for VPC Flow Logs"
  type        = string
  default     = "/aws/vpc/flowlogs"
}

variable "flow_logs_retention_days" {
  description = "Retention period for VPC Flow Logs"
  type        = number
  default     = 30
}

variable "flow_logs_kms_key_id" {
  description = "KMS key ID for VPC Flow Logs encryption"
  type        = string
  default     = null
}

variable "flow_logs_traffic_type" {
  description = "Traffic type for VPC Flow Logs"
  type        = string
  default     = "ALL"
  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_logs_traffic_type)
    error_message = "Traffic type must be ACCEPT, REJECT, or ALL"
  }
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
  default = {}
}

variable "cluster_name" {
  description = "EKS cluster name for subnet tagging"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
