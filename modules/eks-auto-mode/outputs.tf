################################################################################
# Cluster Outputs
################################################################################

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_platform_version" {
  description = "Platform version for the cluster"
  value       = module.eks.cluster_platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster"
  value       = module.eks.cluster_status
}

output "cluster_primary_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster"
  value       = module.eks.cluster_primary_security_group_id
}

################################################################################
# Security Group Outputs
################################################################################

output "cluster_security_group_arn" {
  description = "Amazon Resource Name (ARN) of the cluster security group"
  value       = module.eks.cluster_security_group_arn
}

output "cluster_security_group_id" {
  description = "ID of the cluster security group"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_arn" {
  description = "Amazon Resource Name (ARN) of the node shared security group"
  value       = module.eks.node_security_group_arn
}

output "node_security_group_id" {
  description = "ID of the node shared security group"
  value       = module.eks.node_security_group_id
}

################################################################################
# IRSA Outputs
################################################################################

output "oidc_provider" {
  description = "The OpenID Connect identity provider (issuer URL without leading `https://`)"
  value       = module.eks.oidc_provider
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = module.eks.oidc_provider_arn
}

################################################################################
# IAM Role Outputs
################################################################################

output "cluster_iam_role_name" {
  description = "Cluster IAM role name"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_iam_role_arn" {
  description = "Cluster IAM role ARN"
  value       = module.eks.cluster_iam_role_arn
}

output "node_iam_role_name" {
  description = "EKS Auto node IAM role name"
  value       = module.eks.node_iam_role_name
}

output "node_iam_role_arn" {
  description = "EKS Auto node IAM role ARN"
  value       = module.eks.node_iam_role_arn
}

################################################################################
# ALB Controller Outputs
################################################################################

output "alb_controller_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = module.alb_controller.iam_role_arn
}

output "alb_controller_role_name" {
  description = "Name of the IAM role for AWS Load Balancer Controller"
  value       = module.alb_controller.iam_role_name
}

################################################################################
# EBS CSI Driver Outputs
################################################################################

output "ebs_csi_driver_role_arn" {
  description = "ARN of the IAM role for EBS CSI Driver"
  value       = module.ebs_csi_driver.iam_role_arn
}

output "ebs_csi_driver_role_name" {
  description = "Name of the IAM role for EBS CSI Driver"
  value       = module.ebs_csi_driver.iam_role_name
}

################################################################################
# Secrets CSI Driver Outputs
################################################################################

output "secrets_csi_driver_role_arn" {
  description = "ARN of the IAM role for Secrets Store CSI Driver"
  value       = module.secrets_csi_driver.iam_role_arn
}

output "secrets_csi_driver_role_name" {
  description = "Name of the IAM role for Secrets Store CSI Driver"
  value       = module.secrets_csi_driver.iam_role_name
}

output "secrets_service_account_name" {
  description = "Name of the Kubernetes service account for secrets"
  value       = module.secrets_csi_driver.service_account_name
}

output "secrets_pod_identity_association_id" {
  description = "ID of the EKS Pod Identity Association for secrets"
  value       = module.secrets_csi_driver.pod_identity_association_id
}
