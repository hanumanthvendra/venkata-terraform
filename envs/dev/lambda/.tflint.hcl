config {
  # v0.54+ replacement for `module = true`
  call_module_type     = "all"   # valid values: "all", "callable", "none"
  force                = false
  disabled_by_default  = false
}

plugin "aws" {
  enabled = true
  version = "0.21.2"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "aws_instance_invalid_type" {
  enabled = false
}

rule "aws_db_instance_invalid_type" {
  enabled = false
}
