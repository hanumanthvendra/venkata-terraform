variable "region" {
  type    = string
  default = "ap-south-1"
}

# NEW cluster name to avoid 409 with your existing cluster
variable "cluster_name" {
  type    = string
  default = "dev-eks-auto"
}

# Set to your target version
variable "cluster_version" {
  type    = string
  default = "1.33"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "iam_role_prefix" {
  type    = string
  default = "eks-auto-mode"
}

# Turn on after cluster is ACTIVE to create NodePools
variable "enable_nodepools" {
  type    = bool
  default = false
}

# One of these must be set (or admin_principal_arn directly)
variable "admin_user_name" {
  type        = string
  default     = null # e.g., "venkata"  (must already exist)
  description = "Existing IAM user name to grant cluster-admin (optional)."
}

variable "admin_role_name" {
  type        = string
  default     = null # e.g., "OrganizationAccountAccessRole" (must already exist)
  description = "Existing IAM role name to grant cluster-admin (optional)."
}

variable "admin_principal_arn" {
  type        = string
  default     = null # e.g., arn:aws:iam::<acct-id>:role/YourRole  OR  arn:aws:iam::<acct-id>:user/YourUser
  description = "Direct IAM principal ARN (role or user). Overrides the name-based lookup."
}

# (Optional) Who is allowed to assume the dev-eks-auto-admin role.
# Leave empty to default to your account root (any principal in the same account can assume,
# provided their own identity policy allows sts:AssumeRole).
variable "admin_assume_principals" {
  type        = list(string)
  default     = [] # e.g., ["arn:aws:iam::817928572948:user/terraform"]
  description = "Allowed IAM principals that can assume the dev-eks-auto-admin role."
}

