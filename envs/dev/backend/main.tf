terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

# KMS Key for S3 bucket encryption
resource "aws_kms_key" "terraform_backend" {
  description             = "KMS key for Terraform backend S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags = {
    Name        = "terraform-backend-kms"
    Project     = "platform"
    Environment = "dev"
  }
}

resource "aws_kms_alias" "terraform_backend" {
  name          = "alias/terraform-backend"
  target_key_id = aws_kms_key.terraform_backend.key_id
}

# S3 Bucket for Terraform state
module "s3_backend" {
  source         = "../../../modules/s3-backend"
  bucket_name    = "terraform-backend-venkata"
  force_destroy  = false
  kms_master_key_id = aws_kms_key.terraform_backend.key_id
  tags = {
    Project     = "platform"
    Environment = "dev"
  }
}

# DynamoDB Table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-backend-venkata-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "terraform-backend-locks"
    Project     = "platform"
    Environment = "dev"
  }
}
