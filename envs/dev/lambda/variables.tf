variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "dev-lambda-app"
}

variable "lambda_runtime" {
  description = "Runtime for Lambda function"
  type        = string
  default     = "nodejs18.x"
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda function"
  type        = number
  default     = 256
}

variable "lambda_timeout" {
  description = "Timeout for Lambda function"
  type        = number
  default     = 30
}

variable "api_gateway_name" {
  description = "Name of the API Gateway"
  type        = string
  default     = "dev-api-gateway"
}

variable "api_path_part" {
  description = "Path part for the API resource"
  type        = string
  default     = "hello"
}

variable "http_method" {
  description = "HTTP method for the API method"
  type        = string
  default     = "GET"
}

variable "source_dir" {
  description = "Path to the Lambda function source code directory"
  type        = string
  default     = "./src"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "dev-lambda-api"
    ManagedBy   = "terraform"
  }
}
