variable "api_gateway_name" {
  description = "Name of the API Gateway"
  type        = string
  default     = "sample-lambda-api"
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

variable "stage_name" {
  description = "Stage name for the API Gateway deployment"
  type        = string
  default     = "dev"
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
