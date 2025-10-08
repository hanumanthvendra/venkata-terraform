terraform {
  required_version = ">= 1.5.0"
  backend "s3" {}
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

# EKS Auto Mode subnet tagging for ALB discovery
locals {
  public_subnets  = module.vpc.public_subnet_ids
  private_subnets = module.vpc.private_subnet_ids
  all_subnets     = concat(local.public_subnets, local.private_subnets)
  cluster_name    = var.cluster_name
}

# Public subnets: discoverable for internet-facing ALBs
resource "aws_ec2_tag" "public_elb_role" {
  for_each   = toset(local.public_subnets)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

# Private subnets: discoverable for internal ALBs
resource "aws_ec2_tag" "private_elb_role" {
  for_each   = toset(local.private_subnets)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}


