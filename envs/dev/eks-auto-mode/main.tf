############################
# Backend initialization
############################
terraform {
  backend "s3" {}
}

############################
# Pull VPC outputs from existing "network" state
############################
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket       = "terraform-backend-venkata"
    key          = "dev/network/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    kms_key_id   = "alias/terraform-backend"
    use_lockfile = true
  }
}

locals {
  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = tolist(data.terraform_remote_state.network.outputs.private_subnet_ids)
}

############################
# IAM for THIS new cluster (Auto Mode)
############################
# Cluster role
resource "aws_iam_role" "cluster" {
  name = "${var.iam_role_prefix}-${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${var.iam_role_prefix}-${var.cluster_name}-cluster-role" })
}

# Required cluster-role policies for Auto Mode
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSComputePolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
}
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSNetworkingPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
}
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSLoadBalancingPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
}
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSBlockStoragePolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
}

# Optional node role for Auto Mode–launched nodes (not MNGs)
resource "aws_iam_role" "node" {
  name = "${var.iam_role_prefix}-${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = ["ec2.amazonaws.com", "eks.amazonaws.com"] },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Name = "${var.iam_role_prefix}-${var.cluster_name}-node-role" })
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodeMinimalPolicy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
}
resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryPullOnly" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

############################
# EKS cluster (Auto Mode)
############################
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  # Required by Auto Mode (AWS manages core add-ons)
  bootstrap_self_managed_addons = false

  # Access Entries authentication (required by Auto Mode)
  access_config {
    authentication_mode                         = "API" # or "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true  # creator gets admin initially
  }

  # --- All three feature flags MUST be TRUE for Auto Mode ---
  compute_config {
    enabled       = true
    node_pools    = ["general-purpose"]   # optional default pool
    node_role_arn = aws_iam_role.node.arn # optional but supported
  }

  kubernetes_network_config {
    elastic_load_balancing { enabled = true }
  }

  storage_config {
    block_storage { enabled = true }
  }
  # ----------------------------------------------------------

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    subnet_ids              = local.subnet_ids
  }

  enabled_cluster_log_types = [
    "api", "audit", "authenticator", "controllerManager", "scheduler"
  ]

  tags = merge(var.tags, { Name = var.cluster_name, ManagedBy = var.iam_role_prefix })

  # Ensure IAM permissions are in place before EKS provisions infra
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSComputePolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSNetworkingPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSLoadBalancingPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSBlockStoragePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodeMinimalPolicy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryPullOnly,
  ]
}


# Who is calling (for defaulting to account root)
data "aws_caller_identity" "me" {}

locals {
  # If admin_assume_principals is non-empty, use it; else default to account root.
  admin_role_trust_principals = length(var.admin_assume_principals) > 0 ? var.admin_assume_principals : [
    "arn:aws:iam::${data.aws_caller_identity.me.account_id}:root"
  ]
}

############################
# Cluster admin via dedicated IAM role
############################

resource "aws_iam_role" "dev_eks_auto_admin" {
  name = "${var.cluster_name}-admin" # e.g., dev-eks-auto-admin

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect : "Allow",
      Principal : { AWS : local.admin_role_trust_principals },
      Action : "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Purpose = "EKS Cluster Admin", Cluster = var.cluster_name })
}

resource "aws_iam_policy" "dev_eks_auto_admin_cli" {
  name        = "${var.cluster_name}-admin-cli"
  description = "Minimal IAM for EKS CLI access (DescribeCluster/ListClusters)"
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [{
      Effect : "Allow",
      Action : [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      Resource : "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dev_eks_auto_admin_cli_attach" {
  role       = aws_iam_role.dev_eks_auto_admin.name
  policy_arn = aws_iam_policy.dev_eks_auto_admin_cli.arn
}

# WHO can authenticate
resource "aws_eks_access_entry" "cluster_admin_role" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.dev_eks_auto_admin.arn
  type          = "STANDARD"
  depends_on    = [aws_eks_cluster.this]
}

# WHAT they can do (cluster-admin)
resource "aws_eks_access_policy_association" "cluster_admin_role_assoc" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.dev_eks_auto_admin.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope { type = "cluster" }
}
