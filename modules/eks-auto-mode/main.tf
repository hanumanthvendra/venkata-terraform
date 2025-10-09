################################################################################
# EKS Auto Mode Module
# This module creates an EKS cluster with Auto Mode and all necessary addons
################################################################################

locals {
  name = "${var.environment}-${var.cluster_name}"
  
  tags = merge({
    Environment = var.environment
    Project     = "eks-auto-mode"
    ManagedBy   = "terraform"
  }, var.tags)
}

################################################################################
# EKS Cluster with Auto Mode
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                   = local.name
  cluster_version                = var.kubernetes_version
  cluster_endpoint_public_access = var.enable_public_access

  # Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  # EKS Auto Mode Configuration
  cluster_compute_config = {
    enabled    = true
    node_pools = var.node_pools
  }

  # Network configuration
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # Cluster addons with configurable versions
  cluster_addons = {
    coredns = {
      addon_version = var.addon_versions.coredns
    }
    kube-proxy = {
      addon_version = var.addon_versions.kube_proxy
    }
    vpc-cni = {
      addon_version = var.addon_versions.vpc_cni
    }
    aws-ebs-csi-driver = {
      addon_version = var.addon_versions.aws_ebs_csi_driver
    }
    eks-pod-identity-agent = {
      addon_version = var.addon_versions.eks_pod_identity_agent
    }
  }

  tags = local.tags
}

################################################################################
# AWS Load Balancer Controller
################################################################################

module "alb_controller" {
  source = "../eks-addons/alb-controller"

  cluster_name       = local.name
  region             = var.region
  vpc_id             = var.vpc_id
  install_helm_chart = var.install_alb_controller
  tags               = local.tags

  depends_on = [module.eks]
}

################################################################################
# EBS CSI Driver IAM Configuration
################################################################################

module "ebs_csi_driver" {
  source = "../eks-addons/ebs-csi-driver"

  cluster_name              = local.name
  region                    = var.region
  annotate_service_account  = var.annotate_ebs_csi_sa
  tags                      = local.tags

  depends_on = [module.eks]
}

################################################################################
# Secrets Store CSI Driver
################################################################################

module "secrets_csi_driver" {
  source = "../eks-addons/secrets-csi-driver"

  cluster_name                    = local.name
  namespace                       = var.secrets_namespace
  service_account_name            = var.secrets_service_account_name
  secrets_manager_arns            = var.secrets_manager_arns
  create_service_account          = var.create_secrets_service_account
  create_pod_identity_association = var.create_secrets_pod_identity
  tags                            = local.tags

  depends_on = [module.eks]
}

################################################################################
# EKS Cluster Subnet Tagging for ALB Controller Auto-Discovery
# This ensures ALB Controller can automatically discover subnets for load balancer creation
################################################################################

# Tag public subnets with cluster ownership for internet-facing ALB auto-discovery
resource "aws_ec2_tag" "public_subnet_cluster_ownership" {
  for_each    = toset(var.public_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.name}"
  value       = "owned"

  depends_on = [module.eks]
}

# Tag private subnets with cluster ownership for internal ALB auto-discovery
resource "aws_ec2_tag" "private_subnet_cluster_ownership" {
  for_each    = toset(var.private_subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${local.name}"
  value       = "owned"

  depends_on = [module.eks]
}
