

################################################################################
# Provider Configuration
################################################################################

provider "aws" {
  region = var.region
}

# Kubernetes provider for EKS cluster
provider "kubernetes" {
  host                   = module.eks_auto_mode.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_auto_mode.cluster_certificate_authority_data)

  # Authenticate via AWS CLI (no kubeconfig needed)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_auto_mode.cluster_name, "--region", var.region]
  }
}

################################################################################
# Data Sources
################################################################################

# Data source for network state
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "terraform-backend-venkata"
    key    = "dev/network/terraform.tfstate"
    region = "ap-south-1"
  }
}

################################################################################
# EKS Auto Mode Module
################################################################################

module "eks_auto_mode" {
  source = "../../../modules/eks-auto-mode"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  environment        = var.environment
  region             = var.region

  # Network configuration from remote state
  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  # EKS cluster runs on private subnets only
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  
  # Pass public and private subnets for ALB Controller tagging
  # Public subnets: for internet-facing ALBs
  # Private subnets: for internal ALBs
  public_subnet_ids  = data.terraform_remote_state.network.outputs.public_subnet_ids
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

  # Cluster configuration
  enable_public_access = var.enable_public_access
  node_pools           = var.node_pools

  # EKS Addon versions - specify versions to pin them
  addon_versions = {
    coredns                = var.addon_versions.coredns
    kube_proxy             = var.addon_versions.kube_proxy
    vpc_cni                = var.addon_versions.vpc_cni
    aws_ebs_csi_driver     = var.addon_versions.aws_ebs_csi_driver
    eks_pod_identity_agent = var.addon_versions.eks_pod_identity_agent
  }

  # Addon installation flags
  install_alb_controller = true
  annotate_ebs_csi_sa    = true

  # Secrets configuration
  secrets_namespace              = "default"
  secrets_service_account_name   = "secrets-sa"
  secrets_manager_arns           = ["*"]
  create_secrets_service_account = true
  create_secrets_pod_identity    = true

  tags = var.tags
}
