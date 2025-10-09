################################################################################
# Cluster
################################################################################

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks_auto_mode.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks_auto_mode.cluster_certificate_authority_data
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.eks_auto_mode.cluster_endpoint
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks_auto_mode.cluster_name
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks_auto_mode.cluster_oidc_issuer_url
}

output "cluster_platform_version" {
  description = "Platform version for the cluster"
  value       = module.eks_auto_mode.cluster_platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster"
  value       = module.eks_auto_mode.cluster_status
}

output "cluster_primary_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster"
  value       = module.eks_auto_mode.cluster_primary_security_group_id
}

################################################################################
# Security Group
################################################################################

output "cluster_security_group_arn" {
  description = "Amazon Resource Name (ARN) of the cluster security group"
  value       = module.eks_auto_mode.cluster_security_group_arn
}

output "cluster_security_group_id" {
  description = "ID of the cluster security group"
  value       = module.eks_auto_mode.cluster_security_group_id
}

################################################################################
# Node Security Group
################################################################################

output "node_security_group_arn" {
  description = "Amazon Resource Name (ARN) of the node shared security group"
  value       = module.eks_auto_mode.node_security_group_arn
}

output "node_security_group_id" {
  description = "ID of the node shared security group"
  value       = module.eks_auto_mode.node_security_group_id
}

################################################################################
# IRSA
################################################################################

output "oidc_provider" {
  description = "The OpenID Connect identity provider (issuer URL without leading `https://`)"
  value       = module.eks_auto_mode.oidc_provider
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if `enable_irsa = true`"
  value       = module.eks_auto_mode.oidc_provider_arn
}

################################################################################
# IAM Role
################################################################################

output "cluster_iam_role_name" {
  description = "Cluster IAM role name"
  value       = module.eks_auto_mode.cluster_iam_role_name
}

output "cluster_iam_role_arn" {
  description = "Cluster IAM role ARN"
  value       = module.eks_auto_mode.cluster_iam_role_arn
}

################################################################################
# EKS Auto Node IAM Role
################################################################################

output "node_iam_role_name" {
  description = "EKS Auto node IAM role name"
  value       = module.eks_auto_mode.node_iam_role_name
}

output "node_iam_role_arn" {
  description = "EKS Auto node IAM role ARN"
  value       = module.eks_auto_mode.node_iam_role_arn
}

################################################################################
# Additional Resources
################################################################################

output "region" {
  description = "AWS region"
  value       = var.region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

################################################################################
# Addon IAM Roles
################################################################################

output "alb_controller_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = module.eks_auto_mode.alb_controller_role_arn
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the IAM role for EBS CSI Driver"
  value       = module.eks_auto_mode.ebs_csi_driver_role_arn
}

output "secrets_csi_driver_pod_identity_role_arn" {
  description = "ARN of the Pod Identity IAM role for Secrets Store CSI Driver"
  value       = module.eks_auto_mode.secrets_csi_driver_pod_identity_role_arn
}

output "secrets_csi_driver_irsa_role_arn" {
  description = "ARN of the IRSA IAM role for Secrets Store CSI Driver"
  value       = module.eks_auto_mode.secrets_csi_driver_irsa_role_arn
}
