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

## Configuration Files

### TFLint Configuration (.tflint.hcl)
TFLint is a Terraform linter that helps identify potential issues in Terraform code. The configuration file includes:

- **Plugin**: AWS ruleset (version 0.21.2) for AWS-specific best practices
- **Disabled Rules**:
  - `aws_instance_invalid_type`: Disabled to allow custom instance types
  - `aws_db_instance_invalid_type`: Disabled for flexibility in database instance selection
- **Module Type**: Set to "all" to check all module types
- **Force**: Disabled to allow warnings without failing builds

### Policy-as-Code (policy/terraform.rego)
This Open Policy Agent (OPA) policy file enforces security and compliance rules on Terraform plans. Key policies include:

- **Security Group Rules**: Blocks 0.0.0.0/0 ingress except on allowed ports (80, 443)
- **Encryption**: Requires server-side encryption for S3 buckets, encryption for EBS volumes, and storage encryption for RDS instances
- **Load Balancer Security**: Enforces WAF enablement for Application Load Balancers
- **S3 Public Access**: Blocks public ACLs and requires Block Public Access settings
- **Resource Tagging**: Mandates required tags (Owner, CostCenter, Environment)
- **TLS Policies**: Enforces minimum TLS 1.2 policies for ALB listeners

### Gitleaks SARIF Report (gitleaks.sarif)
Gitleaks is a secret scanning tool that detects exposed credentials and sensitive information. The SARIF (Static Analysis Results Interchange Format) report contains:

- **Tool Information**: Gitleaks v8.0.0 with comprehensive rule set
- **Rules**: Over 200 predefined rules covering various secret types (API keys, tokens, certificates, etc.)
- **Results**: Empty results array indicates no secrets were detected in the current scan
- **Supported Secrets**: AWS credentials, GitHub tokens, database passwords, private keys, and many more

## CI/CD Pipeline (Jenkins)

This project uses Jenkins for continuous integration and deployment. The pipeline is defined in `Jenkinsfile.groovy` and includes the following stages:

### 1. Clean Workspace
- **Purpose**: Ensures a clean environment for each build by deleting any existing files from previous runs.
- **Actions**: Removes all files and directories in the workspace.

### 2. Clone Repo
- **Purpose**: Retrieves the latest code from the Git repository.
- **Actions**:
  - Uses SSH agent for authentication.
  - Sets up SSH keys and known hosts.
  - Clones the repository from GitHub using the specified branch (main).

### 3. Parallel Security Scans
- **Purpose**: Performs security checks on the codebase to identify vulnerabilities and secrets.
- **Parallel Stages**:
  - **Secret Scan (Gitleaks)**: Scans for exposed secrets using Gitleaks tool in a Docker container. Outputs results to `gitleaks.sarif`.
  - **Secret Scan (Trivy Repo)**: Scans the repository for secrets using Trivy. Fails the build if secrets are found.

### 4. Terraform Format
- **Purpose**: Ensures Terraform code is properly formatted.
- **Actions**:
  - Runs `terraform fmt -recursive` to format all `.tf` and `.tfvars` files.
  - If changes are detected, commits and pushes them back to the repository with a "ci: terraform fmt" message.

### 5. Parallel Lint & Validate
- **Purpose**: Lints and validates Terraform code for best practices and security issues.
- **Parallel Stages**:
  - **TFLint**: Lints Terraform code using TFLint (pinned to v0.53.0). Initializes and runs recursively.
  - **TFsec**: Scans for security issues in Terraform code using TFsec. Outputs results to `tfsec-results.xml`.
  - **Checkov**: Scans for misconfigurations and security issues using Checkov. Includes extra volume mount for modules to avoid load warnings. Outputs to `checkov-results.xml`.

### 6. Terraform Validate
- **Purpose**: Validates the Terraform configuration syntax and consistency.
- **Actions**:
  - Initializes Terraform with backend configuration.
  - Runs `terraform validate` to check for errors.

### 7. Terraform Plan
- **Purpose**: Generates an execution plan showing what changes Terraform will make.
- **Actions**:
  - Runs `terraform plan` and saves the plan to `tfplan.binary`.
  - Converts the plan to JSON format (`tfplan.json`) for further processing.

### 8. Policy-as-Code on Plan (Conftest)
- **Purpose**: Applies policy checks against the Terraform plan using Open Policy Agent (OPA).
- **Actions**:
  - If a `policy/` directory and `tfplan.json` exist, runs Conftest to validate the plan against defined policies.
  - Outputs results to `conftest-results.xml`.

### 9. Infracost (Optional)
- **Purpose**: Estimates the monthly cost of infrastructure changes.
- **Actions**:
  - Uses Infracost to analyze the Terraform plan and generate a cost breakdown in JSON format (`infracost.json`).

### 10. Approval for Apply
- **Purpose**: Requires manual approval before applying changes to production.
- **Actions**:
  - Prompts the user to choose "Yes" or "No" for applying the Terraform plan.
  - Sets environment variable `APPLY_CHANGES` based on the response.

### 11. Terraform Apply (Conditional)
- **Purpose**: Applies the Terraform plan to create, update, or destroy infrastructure.
- **Actions** (only if approved):
  - Runs `terraform apply tfplan.binary` to execute the changes.

### 12. Post-Apply Tests (Optional)
- **Purpose**: Runs additional tests after infrastructure changes.
- **Actions**: Placeholder for unit tests, integration tests, or other validations (e.g., Kitchen-Terraform, Terratest).

### 13. Generate Docs & Graph
- **Purpose**: Generates documentation and visual representations of the infrastructure.
- **Actions**:
  - Creates a dependency graph using `terraform graph` piped to Graphviz container (`graphviz/graphviz:stable`).
  - Generates README documentation using `terraform-docs`.

### 14. SBOM & License Scan
- **Purpose**: Creates a Software Bill of Materials and scans for licenses.
- **Actions**:
  - Generates SBOM using Syft (`anchore/syft`) in SPDX JSON format.
  - Scans for licenses and vulnerabilities using Trivy.

### 15. Cleanup
- **Purpose**: Cleans up temporary files and resources.
- **Actions**: Removes any temporary files generated during the build.

### Exception Handling
- **Purpose**: Handles build failures and sends notifications.
- **Actions**:
  - On failure, sends a Slack notification with build details and error message.

### Configuration
- **Node**: `ec2-fleet`
- **Terraform Version**: 1.5.7
- **AWS Region**: ap-south-1
- **Environment**: dev
- **Workspace Directory**: envs/dev/lambda

### Artifacts
The pipeline archives the following artifacts:
- `gitleaks.sarif`
- `tfsec-results.xml`
- `checkov-results.xml`
- `tfplan.json`
- `conftest-results.xml`
- `infracost.json`
- `graph.png`
- `README.md` (generated)
- `sbom.json`
- `trivy-results.json`
