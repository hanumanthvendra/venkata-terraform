output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.this.id
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_version" {
  description = "EKS cluster version"
  value       = aws_eks_cluster.this.version
}

output "node_group_names" {
  description = "EKS node group names"
  value       = [for ng in aws_eks_node_group.this : ng.node_group_name]
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = aws_security_group.cluster.id
}

output "node_group_security_group_id" {
  description = "EKS node group security group ID"
  value       = aws_security_group.node_group.id
}

output "cluster_iam_role_arn" {
  description = "EKS cluster IAM role ARN"
  value       = aws_iam_role.cluster.arn
}

output "node_group_iam_role_arn" {
  description = "EKS node group IAM role ARN"
  value       = aws_iam_role.node_group.arn
}

output "oidc_provider_arn" {
  description = "EKS cluster OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "EKS cluster OIDC provider URL"
  value       = aws_iam_openid_connect_provider.eks.url
}
