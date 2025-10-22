# Lambda Function with API Gateway and CloudFront

This Terraform configuration creates a production-ready Lambda function deployed in a VPC with API Gateway and CloudFront distribution.

## Architecture

- **Lambda Function**: Node.js function deployed in VPC private subnets
- **API Gateway**: REST API with regional endpoint
- **CloudFront**: CDN distribution for global content delivery
- **VPC Integration**: Lambda function runs in VPC with security groups and subnets from network state

## Features

- Production-grade security with VPC deployment
- CORS enabled for web applications
- CloudWatch logging with 30-day retention
- Proper IAM roles and policies
- Environment variables support
- Remote state management for network dependencies

## Lambda Function Details

### Node.js Application
The Lambda function is written in Node.js and includes:
- **Handler**: `index.handler`
- **Runtime**: Node.js 18.x
- **Memory**: 256 MB
- **Timeout**: 30 seconds
- **Environment Variables**:
  - `ENVIRONMENT`: Set to "dev"

### Function Code
```javascript
exports.handler = async (event) => {
    const response = {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
            'Access-Control-Allow-Methods': 'GET,OPTIONS'
        },
        body: JSON.stringify({
            message: 'Hello venkata welcome to lambda deployment',
            timestamp: new Date().toISOString(),
            environment: process.env.ENVIRONMENT || 'dev',
            requestId: event.requestContext?.requestId || 'unknown'
        })
    };
    return response;
};
```

### Package Configuration
```json
{
  "name": "lambda-function",
  "version": "1.0.0",
  "description": "Sample Lambda function for API Gateway integration",
  "main": "index.js",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "keywords": ["lambda", "api-gateway", "serverless"],
  "author": "venkata",
  "license": "MIT"
}
```

## API Gateway Configuration

### REST API Settings
- **Name**: dev-lambda-api
- **Description**: API Gateway for Lambda function
- **Endpoint Type**: Regional
- **Stage**: dev
- **CORS**: Enabled for all origins

### Resource and Method
- **Resource**: /hello
- **Method**: GET
- **Integration**: Lambda function
- **Authorization**: None (open access)

## CloudFront Distribution

### Distribution Settings
- **Origin**: API Gateway regional endpoint
- **Behaviors**:
  - Path Pattern: /hello
  - Viewer Protocol Policy: Redirect to HTTPS
  - Allowed Methods: GET, HEAD, OPTIONS
  - Cache Policy: CachingOptimized
- **Price Class**: PriceClass_100 (US, Canada, Europe)

## VPC and Security

### VPC Configuration
- **VPC**: Retrieved from network remote state
- **Subnets**: Private subnets for Lambda function
- **Security Group**: Allows outbound traffic only

### IAM Roles and Policies
- **Lambda Execution Role**: Basic execution permissions
- **Policies**:
  - CloudWatch Logs access
  - VPC access (ENI management)

## Deployment

1. Ensure network infrastructure is deployed and state is available
2. Initialize Terraform:
   ```bash
   terraform init -backend-config=backend.hcl
   ```

3. Plan and apply:
   ```bash
   terraform plan
   terraform apply
   ```

## Testing

After deployment, test the endpoints:

1. **API Gateway Direct**:
   ```bash
   curl -X GET "https://rbicd2bdzb.execute-api.ap-south-1.amazonaws.com/dev/hello"
   ```
   Expected Response:
   ```json
   {
     "message": "Hello venkata welcome to lambda deployment",
     "timestamp": "2025-10-22T17:51:59.548Z",
     "environment": "dev",
     "requestId": "1e709727-48f4-46dd-8f3c-8a9bbcbb7691"
   }
   ```

2. **CloudFront**: `https://<cloudfront-domain>/hello`

## Outputs

- `lambda_function_arn`: ARN of the deployed Lambda function
- `api_gateway_url`: Direct API Gateway URL
- `cloudfront_url`: CloudFront distribution domain name
- `lambda_function_name`: Name of the Lambda function

## Security Considerations

- Lambda function runs in private subnets
- Security group allows outbound traffic only
- API Gateway uses regional endpoint
- CloudFront enforces HTTPS
- IAM roles follow least privilege principle
- CORS headers configured for web application access

## Monitoring

- CloudWatch Logs: `/aws/lambda/dev-lambda-app`
- Log Retention: 30 days
- Metrics: Available in CloudWatch for Lambda, API Gateway, and CloudFront

## Cost Optimization

- Lambda: Pay per request and compute time
- API Gateway: Pay per request
- CloudFront: Pay per request and data transfer
- CloudWatch Logs: Pay per GB stored
