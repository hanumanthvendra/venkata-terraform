terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket         = "terraform-backend-venkata"
    key            = "dev/network/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-backend"
    dynamodb_table = "terraform-backend-venkata-locks"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

module "vpc" {
  source = "../../../modules/vpc"

  # VPC configuration variables
  vpc_cidr_block       = var.vpc_cidr_block
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  azs                  = var.azs

  # NAT Gateway options
  enable_nat_gateway = var.enable_nat_gateway
  nat_gateway_mode   = var.nat_gateway_mode

  # Security options
  enable_flow_logs     = var.enable_flow_logs
  flow_logs_log_group  = var.flow_logs_log_group
  flow_logs_kms_key_id = var.flow_logs_kms_key_id

  # VPC Endpoints
  vpc_endpoints        = var.vpc_endpoints

  name_prefix  = var.name_prefix
  cluster_name = var.cluster_name
  tags         = var.tags
}
