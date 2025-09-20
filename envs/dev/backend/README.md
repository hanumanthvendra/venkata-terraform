# AWS Terraform Backend Implementation Guide

This directory contains the Terraform configuration for setting up a robust S3 backend with DynamoDB state locking for the entire infrastructure project.

## 🏗️ Backend Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Terraform     │    │      AWS        │    │   State         │
│   Workspaces    │    │   Resources     │    │   Management    │
│                 │    │                 │    │                 │
│ • Multiple Envs │────│ • S3 Bucket     │────│ • Versioning    │
│ • State Files   │    │ • DynamoDB      │────│ • Encryption    │
│ • Locking       │────│ • KMS Keys      │────│ • Locking       │
│ • Collaboration │    │ • IAM Policies  │    │ • Consistency   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📁 Directory Structure

```
envs/dev/backend/
├── main.tf           # Main Terraform configuration
├── outputs.tf        # Output values
├── providers.tf      # AWS provider configuration
├── versions.tf       # Terraform/AWS provider versions
├── backend.hcl       # Backend configuration
└── README.md         # This documentation
```

## 🔐 Backend Implementation Details

### S3 Backend Configuration

The backend uses S3 for storing Terraform state files with enterprise-grade features:

- **Bucket**: `terraform-backend-venkata`
- **Region**: `ap-south-1`
- **Encryption**: AES256 (AWS-managed) or KMS
- **Versioning**: Enabled for state history
- **Public Access**: Blocked for security
- **TLS Enforcement**: Required for all operations

### DynamoDB State Locking

DynamoDB provides distributed locking mechanism:

- **Table**: `terraform-backend-venkata-locks`
- **Key**: `LockID` (hash key)
- **Billing**: Pay-per-request (cost-effective)
- **Consistency**: Strongly consistent reads/writes

### KMS Encryption

- **Key Alias**: `alias/terraform-backend`
- **Rotation**: Automatic key rotation enabled
- **Purpose**: Encrypt S3 bucket contents
- **Deletion**: 10-day deletion window

## 🚀 Backend Setup and Usage

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0
- IAM permissions for S3, DynamoDB, and KMS

### Step 1: Initialize Backend Infrastructure

```bash
# Navigate to backend directory
cd envs/dev/backend

# Initialize with backend configuration
terraform init -backend-config=backend.hcl

# Review what will be created
terraform plan

# Apply the backend infrastructure
terraform apply
```

**What gets created:**
- S3 bucket with encryption and versioning
- DynamoDB table for state locking
- KMS key for encryption
- IAM policies and roles

### Step 2: Verify Backend Setup

```bash
# Check backend initialization
terraform show

# List outputs
terraform output

# Verify S3 bucket exists
aws s3 ls | grep terraform-backend-venkata

# Verify DynamoDB table exists
aws dynamodb describe-table --table-name terraform-backend-venkata-locks
```

## 🔍 Backend Configuration Files

### Backend Configuration (backend.hcl)

```hcl
bucket         = "terraform-backend-venkata"
key            = "backend/dev/terraform.tfstate"
region         = "ap-south-1"
encrypt        = true
kms_key_id     = "alias/terraform-backend"
dynamodb_table = "terraform-backend-venkata-locks"
```

**Configuration Parameters:**
- `bucket`: S3 bucket name for state storage
- `key`: State file path within the bucket
- `region`: AWS region
- `encrypt`: Enable server-side encryption
- `kms_key_id`: KMS key for encryption (optional)
- `dynamodb_table`: DynamoDB table for state locking

### Environment-Specific Keys

Each environment uses different state file keys:
- **Backend**: `backend/dev/terraform.tfstate`
- **Network**: `dev/network/terraform.tfstate`
- **EKS**: `dev/eks/terraform.tfstate`
- **EKS Auto Mode**: `dev/eks-auto-mode/terraform.tfstate`

## 🔒 State Locking Mechanism

### How S3 + DynamoDB Locking Works

1. **Lock Acquisition**:
   ```bash
   # When terraform plan/apply runs:
   # 1. Terraform attempts to acquire lock in DynamoDB
   # 2. Creates entry with LockID = <state-file-path>
   # 3. Only one process can hold the lock at a time
   ```

2. **Lock Information**:
   ```json
   {
     "LockID": "backend/dev/terraform.tfstate",
     "Info": "Terraform lock info...",
     "Operation": "OperationTypePlan",
     "Path": "backend/dev/terraform.tfstate",
     "Version": "0.15.0",
     "Created": "2024-01-01T10:00:00Z",
     "Who": "user@example.com"
   }
   ```

3. **Lock Release**:
   - Automatic when terraform operation completes
   - Manual unlock if needed (see troubleshooting)

### Lock Status Commands

```bash
# Check current locks
terraform show

# View lock details in state file
terraform state list

# Check if lock is held
aws dynamodb get-item \
  --table-name terraform-backend-venkata-locks \
  --key '{"LockID": {"S": "backend/dev/terraform.tfstate"}}'
```

## 🛠️ Using Backend for Other Environments

### Initialize Other Environments

```bash
# For network setup
cd ../network
terraform init -backend-config=backend.hcl
terraform plan
terraform apply

# For EKS setup
cd ../eks
terraform init -backend-config=backend.hcl
terraform plan
terraform apply

# For EKS Auto Mode
cd ../eks-auto-mode
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

### Backend Configuration for Each Environment

Each environment uses the same backend configuration but different state keys:

```bash
# Network backend
key = "dev/network/terraform.tfstate"

# EKS backend
key = "dev/eks/terraform.tfstate"

# EKS Auto Mode backend
key = "dev/eks-auto-mode/terraform.tfstate"
```

## 🔍 Validation and Testing

### 1. Backend Validation Commands

```bash
# Validate configuration
terraform validate

# Check plan (should show no changes after setup)
terraform plan

# Show current state
terraform show

# List all resources
terraform state list
```

### 2. AWS Resource Validation

```bash
# Verify S3 bucket
aws s3api head-bucket --bucket terraform-backend-venkata

# Check bucket versioning
aws s3api get-bucket-versioning --bucket terraform-backend-venkata

# Check bucket encryption
aws s3api get-bucket-encryption --bucket terraform-backend-venkata

# Verify DynamoDB table
aws dynamodb describe-table --table-name terraform-backend-venkata-locks

# Check KMS key
aws kms describe-key --key-id alias/terraform-backend
```

### 3. Test State Locking

```bash
# Start a terraform plan in one terminal (will acquire lock)
terraform plan

# In another terminal, try to run terraform plan (should fail with lock error)
terraform plan
# Expected: "Error: Error acquiring the state lock"

# Complete the first operation to release lock
# Then the second operation should work
```

## 🔓 Unlocking State

### Automatic Unlock

Locks are automatically released when Terraform operations complete successfully.

### Manual Unlock (Use with Caution)

```bash
# Force unlock if lock is stuck
terraform force-unlock LOCK_ID

# Example:
terraform force-unlock backend/dev/terraform.tfstate

# Or using AWS CLI to manually delete lock
aws dynamodb delete-item \
  --table-name terraform-backend-venkata-locks \
  --key '{"LockID": {"S": "backend/dev/terraform.tfstate"}}'
```

### Unlock Scenarios

1. **Process killed during operation**:
   ```bash
   terraform force-unlock <LOCK_ID>
   ```

2. **Multiple users with stale locks**:
   ```bash
   # Check who holds the lock
   terraform show

   # Contact the user or force unlock if appropriate
   terraform force-unlock <LOCK_ID>
   ```

3. **Emergency unlock**:
   ```bash
   # Only use in emergency situations
   aws dynamodb delete-item \
     --table-name terraform-backend-venkata-locks \
     --key '{"LockID": {"S": "<FULL_LOCK_ID>"}}'
   ```

## 🛠️ Maintenance Commands

### State Management

```bash
# Refresh state
terraform refresh

# Show state
terraform show

# List resources
terraform state list

# Show specific resource
terraform state show <RESOURCE_ADDRESS>

# Move resource
terraform state mv <SOURCE> <DESTINATION>

# Remove resource
terraform state rm <RESOURCE_ADDRESS>
```

### Workspace Management

```bash
# List workspaces
terraform workspace list

# Create new workspace
terraform workspace new <WORKSPACE_NAME>

# Select workspace
terraform workspace select <WORKSPACE_NAME>

# Show current workspace
terraform workspace show
```

### Backup and Recovery

```bash
# Create state backup
terraform state pull > terraform.tfstate.backup

# Restore from backup
terraform state push terraform.tfstate.backup

# S3 bucket versioning provides automatic backups
aws s3api list-object-versions \
  --bucket terraform-backend-venkata \
  --prefix backend/dev/terraform.tfstate
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Backend Initialization Fails

**Error:**
```
Failed to get existing workspaces: S3 error: Access Denied
```

**Solution:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify bucket permissions
aws s3 ls s3://terraform-backend-venkata

# Check IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:user/USER \
  --action-names s3:GetObject,s3:PutObject,dynamodb:GetItem
```

#### 2. State Lock Errors

**Error:**
```
Error: Error acquiring the state lock
```

**Solution:**
```bash
# Check current locks
terraform show

# Force unlock if safe
terraform force-unlock <LOCK_ID>

# Or check DynamoDB directly
aws dynamodb scan --table-name terraform-backend-venkata-locks
```

#### 3. KMS Key Issues

**Error:**
```
Error: AccessDeniedException: Access denied
```

**Solution:**
```bash
# Check KMS key policy
aws kms get-key-policy --key-id alias/terraform-backend

# Verify key grants
aws kms list-grants --key-id alias/terraform-backend

# Check IAM permissions for KMS
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:user/USER \
  --action-names kms:Decrypt,kms:GenerateDataKey
```

#### 4. Region Mismatch

**Error:**
```
Error: S3 bucket region is ap-south-1 but provider region is us-east-1
```

**Solution:**
```bash
# Ensure region consistency in backend.hcl and AWS config
aws configure get region
# Should match region in backend.hcl (ap-south-1)
```

### Debug Commands

```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform plan

# Check backend configuration
terraform init -backend-config=backend.hcl -reconfigure

# Validate all configurations
terraform validate

# Check provider versions
terraform version

# Test AWS connectivity
aws s3 ls
aws dynamodb list-tables
```

## 📊 Monitoring and Observability

### CloudWatch Metrics

```bash
# Monitor S3 bucket metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name BucketSizeBytes \
  --dimensions Name=BucketName,Value=terraform-backend-venkata \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Average

# Monitor DynamoDB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/DynamoDB \
  --metric-name ConsumedReadCapacityUnits \
  --dimensions Name=TableName,Value=terraform-backend-venkata-locks \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

### Cost Monitoring

```bash
# Check S3 costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter '{"Dimensions": {"Key": "SERVICE", "Values": ["Amazon S3"]}}'

# Check DynamoDB costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter '{"Dimensions": {"Key": "SERVICE", "Values": ["Amazon DynamoDB"]}}'
```

## 🔐 Security Best Practices

### IAM Permissions

- Use least privilege principle
- Regularly rotate access keys
- Enable MFA for console access
- Use IAM roles instead of users where possible

### Network Security

- Enable VPC endpoints for S3 and DynamoDB (if needed)
- Use private endpoints for production
- Monitor access logs
- Enable CloudTrail for API tracking

### Data Protection

- Enable S3 versioning for state history
- Use KMS encryption for sensitive data
- Regular backup verification
- Test restore procedures

## 📞 Support and Resources

### Useful Links

- [Terraform Backend Configuration](https://www.terraform.io/docs/backends/types/s3.html)
- [DynamoDB State Locking](https://www.terraform.io/docs/backends/types/s3.html#dynamodb-state-locking)
- [KMS Encryption](https://docs.aws.amazon.com/kms/latest/developerguide/overview.html)
- [S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)

### Getting Help

1. Check Terraform documentation
2. Review CloudWatch logs
3. Verify IAM permissions
4. Check terraform state: `terraform show`
5. Review AWS service health dashboard

## 🎯 Next Steps

After successful backend setup:

1. **Initialize Other Environments**: Use this backend for network, EKS, and other environments
2. **Set up CI/CD**: Configure automated deployment pipelines
3. **Implement Monitoring**: Set up alerts for backend resources
4. **Security Hardening**: Implement additional security measures
5. **Backup Strategy**: Establish regular backup and recovery procedures

---

**Note**: This backend setup provides a production-ready foundation for Terraform state management. Always test thoroughly in non-production environments before deploying to production.
