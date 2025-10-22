terraform {
  backend "s3" {}
}

# Data source to get network state
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket         = "terraform-backend-venkata"
    key            = "dev/network/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    kms_key_id     = "alias/terraform-backend"
    use_lockfile   = true
  }
}

# Lambda Module
module "lambda" {
  source = "../../../modules/lambda"

  lambda_function_name = var.lambda_function_name
  lambda_runtime       = var.lambda_runtime
  lambda_memory_size   = var.lambda_memory_size
  lambda_timeout       = var.lambda_timeout
  vpc_id               = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids   = data.terraform_remote_state.network.outputs.private_subnet_ids
  environment          = var.environment
  source_dir           = var.source_dir
  tags                 = var.tags
}

# API Gateway Module
module "api_gateway" {
  source = "../../../modules/api-gateway"

  api_gateway_name = var.api_gateway_name
  api_path_part    = var.api_path_part
  http_method      = var.http_method
  stage_name       = var.environment

  lambda_invoke_arn   = module.lambda.lambda_function_arn
  lambda_function_name = module.lambda.lambda_function_name

  tags = var.tags
}



# Outputs
output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.lambda.lambda_function_arn
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = module.api_gateway.api_gateway_url
}



output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda.lambda_function_name
}
