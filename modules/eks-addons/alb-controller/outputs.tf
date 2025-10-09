output "iam_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = aws_iam_role.this.arn
}

output "iam_role_name" {
  description = "Name of the IAM role for AWS Load Balancer Controller"
  value       = aws_iam_role.this.name
}

output "iam_policy_arn" {
  description = "ARN of the IAM policy for AWS Load Balancer Controller"
  value       = aws_iam_policy.this.arn
}
