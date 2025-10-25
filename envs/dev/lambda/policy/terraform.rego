package main

# Disallow 0.0.0.0/0 ingress except ports in an allowlist
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_security_group_rule"
  resource.change.after.type == "ingress"
  resource.change.after.cidr_blocks[_] == "0.0.0.0/0"
  not contains(data.allowed_ports, resource.change.after.from_port)
  msg := sprintf("Security group rule allows 0.0.0.0/0 ingress on port %d, which is not in the allowlist", [resource.change.after.from_port])
}

# Enforce encryption at rest (S3, EBS, RDS, EKS secrets)
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket"
  not resource.change.after.server_side_encryption_configuration
  msg := "S3 bucket must have server-side encryption enabled"
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_ebs_volume"
  not resource.change.after.encrypted
  msg := "EBS volume must be encrypted"
}

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_db_instance"
  not resource.change.after.storage_encrypted
  msg := "RDS instance must have storage encryption enabled"
}

# Require ALB/WAF for public services
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_lb"
  resource.change.after.load_balancer_type == "application"
  not resource.change.after.enable_waf_fail_open
  msg := "ALB must have WAF enabled"
}

# Block public S3 ACLs; require Block Public Access
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket_public_access_block"
  not resource.change.after.block_public_acls
  msg := "S3 bucket must block public ACLs"
}

# Enforce tag policy (Owner, CostCenter, Environment)
deny[msg] {
  resource := input.resource_changes[_]
  required_tags := {"Owner", "CostCenter", "Environment"}
  missing_tags := required_tags - {tag | tag := resource.change.after.tags[_]}
  count(missing_tags) > 0
  msg := sprintf("Resource is missing required tags: %v", [missing_tags])
}

# Require minimum TLS policies and IAM conditions (e.g., MFA, source IP, aws:PrincipalTag)
deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_lb_listener"
  resource.change.after.protocol == "HTTPS"
  resource.change.after.ssl_policy != "ELBSecurityPolicy-TLS-1-2-2017-01"
  msg := "ALB listener must use minimum TLS 1.2 policy"
}

# Data for allowed ports (example: 80, 443)
allowed_ports := "80,443"
