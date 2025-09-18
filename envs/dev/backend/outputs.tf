output "kms_key_id" {
  description = "KMS key ID for Terraform backend encryption"
  value       = aws_kms_key.terraform_backend.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for Terraform backend encryption"
  value       = aws_kms_key.terraform_backend.arn
}

output "s3_bucket_name" {
  description = "S3 bucket name for Terraform backend"
  value       = "terraform-backend-venkata"
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}
