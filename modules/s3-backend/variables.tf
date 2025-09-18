variable "bucket_name" {
  description = "S3 bucket for Terraform backend"
  type        = string
}

variable "force_destroy" {
  description = "Allow bucket force destroy (usually false in prod)"
  type        = bool
  default     = false
}

variable "kms_master_key_id" {
  description = "Optional KMS CMK for SSE-KMS (leave empty for AWS-managed key)"
  type        = string
  default     = ""
}

variable "tags" {
  type        = map(string)
  default     = {}
}
