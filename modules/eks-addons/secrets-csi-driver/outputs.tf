output "iam_role_arn" {
  description = "ARN of the IAM role for Secrets Store CSI Driver"
  value       = aws_iam_role.this.arn
}

output "iam_role_name" {
  description = "Name of the IAM role for Secrets Store CSI Driver"
  value       = aws_iam_role.this.name
}

output "iam_policy_arn" {
  description = "ARN of the IAM policy for Secrets Store CSI Driver"
  value       = aws_iam_policy.this.arn
}

output "service_account_name" {
  description = "Name of the Kubernetes service account"
  value       = var.service_account_name
}

output "pod_identity_association_id" {
  description = "ID of the EKS Pod Identity Association"
  value       = var.create_pod_identity_association ? aws_eks_pod_identity_association.this[0].id : null
}
