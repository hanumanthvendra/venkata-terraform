output "pod_identity_iam_role_arn" {
  description = "ARN of the Pod Identity IAM role for Secrets Store CSI Driver"
  value       = aws_iam_role.pod_identity.arn
}

output "pod_identity_iam_role_name" {
  description = "Name of the Pod Identity IAM role for Secrets Store CSI Driver"
  value       = aws_iam_role.pod_identity.name
}

output "pod_identity_iam_policy_arn" {
  description = "ARN of the Pod Identity IAM policy for Secrets Store CSI Driver"
  value       = aws_iam_policy.pod_identity.arn
}

output "irsa_iam_role_arn" {
  description = "ARN of the IRSA IAM role for Secrets Store CSI Driver"
  value       = aws_iam_role.irsa.arn
}

output "irsa_iam_role_name" {
  description = "Name of the IRSA IAM role for Secrets Store CSI Driver"
  value       = aws_iam_role.irsa.name
}

output "service_account_name" {
  description = "Name of the Kubernetes service account"
  value       = var.service_account_name
}

output "pod_identity_association_id" {
  description = "ID of the EKS Pod Identity Association"
  value       = var.create_pod_identity_association ? aws_eks_pod_identity_association.this[0].id : null
}
