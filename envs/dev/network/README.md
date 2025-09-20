# AWS VPC Network Infrastructure Implementation Guide

This directory contains the Terraform configuration for setting up a comprehensive VPC network infrastructure with multi-tier subnet architecture, NAT gateways, and VPC endpoints for the EKS cluster deployment.

## 🏗️ Network Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Internet      │    │      VPC        │    │   Private       │
│   Gateway       │────│   (10.0.0.0/16) │────│   Resources     │
│                 │    │                 │    │                 │
│ • Public Access │    │ • Public Subnets│    │ • EKS Cluster   │
│ • Route Tables  │────│ • Private Subnets│────│ • RDS Databases │
│ • NAT Gateways  │    │ • DB Subnets    │────│ • Internal ELB  │
│ • Flow Logs     │────│ • VPC Endpoints │────│ • Secure Access │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📁 Directory Structure

```
envs/dev/network/
├── main.tf           # Main VPC configuration
├── outputs.tf        # Network outputs for other environments
├── providers.tf      # AWS provider configuration
├── variables.tf      # Input variables
├── versions.tf       # Terraform/AWS provider versions
├── backend.hcl       # Backend configuration
└── README.md         # This documentation
```

## 🏗️ VPC Implementation Details

### Network Architecture

The VPC is designed with a multi-tier subnet architecture:

- **VPC CIDR**: `10.0.0.0/16`
- **Public Subnets**: `10.0.48.0/20`, `10.0.64.0/20` (ap-south-1a, ap-south-1b)
- **Private Subnets**: `10.0.0.0/20`, `10.0.16.0/20` (ap-south-1a, ap-south-1b)
- **Database Subnets**: `10.0.52.0/24`, `10.0.53.0/24` (ap-south-1a, ap-south-1b)

### NAT Gateway Configuration

Supports two NAT gateway modes:

- **Shared Mode**: Single NAT Gateway for all private subnets (cost-effective)
- **Dedicated Mode**: One NAT Gateway per availability zone (high availability)

### VPC Endpoints

Pre-configured VPC endpoints for AWS services:

- **S3 Gateway Endpoint**: Direct access to S3 without internet
- **DynamoDB Gateway Endpoint**: Direct access to DynamoDB without internet

### Security Features

- **Security Groups**: Default security group with VPC-only access
- **Network ACLs**: Permissive rules for both public and private subnets
- **Flow Logs**: Optional VPC flow logging to CloudWatch (disabled by default)

## 🚀 Network Setup and Usage

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0
- Backend infrastructure already deployed
- IAM permissions for VPC, subnets, NAT gateways, and VPC endpoints

### Step 1: Initialize Network Infrastructure

```bash
# Navigate to network directory
cd envs/dev/network

# Initialize with backend configuration
terraform init -backend-config=backend.hcl

# Review what will be created
terraform plan

# Apply the network infrastructure
terraform apply
```

**What gets created:**
- VPC with CIDR 10.0.0.0/16
- Public subnets with internet access
- Private subnets with NAT gateway access
- Database private subnets (isolated)
- Internet Gateway and NAT Gateways
- Route tables and associations
- Security groups and Network ACLs
- VPC endpoints for S3 and DynamoDB
- Optional VPC flow logs

### Step 2: Verify Network Setup

```bash
# Check network initialization
terraform show

# List all outputs
terraform output

# Verify VPC creation
aws ec2 describe-vpcs --filters Name=tag:Name,Values=dev-vpc

# Check subnets
aws ec2 describe-subnets --filters Name=vpc-id,Values=<VPC_ID>

# Verify NAT gateways
aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=<VPC_ID>
```

## 🔍 Network Configuration Details

### VPC Configuration

```hcl
module "vpc" {
  source = "../../../modules/vpc"

  # VPC configuration variables
  vpc_cidr_block       = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  azs                  = ["ap-south-1a", "ap-south-1b"]

  # NAT Gateway options
  enable_nat_gateway = true
  nat_gateway_mode   = "shared"

  # VPC Endpoints
  vpc_endpoints = {
    s3 = {
      service_name = "com.amazonaws.ap-south-1.s3"
      type         = "Gateway"
    }
    dynamodb = {
      service_name = "com.amazonaws.ap-south-1.dynamodb"
      type         = "Gateway"
    }
  }

  name_prefix  = "dev"
  cluster_name = "dev-eks-cluster"
  tags = {
    Environment = "dev"
    Project     = "eks"
  }
}
```

### Key Configuration Options

- **vpc_cidr_block**: Main VPC CIDR range
- **azs**: Availability zones for subnet distribution
- **enable_nat_gateway**: Enable internet access for private subnets
- **nat_gateway_mode**: "shared" or "dedicated" NAT gateway configuration
- **vpc_endpoints**: AWS service endpoints for private access
- **enable_flow_logs**: Enable VPC flow logging (default: false)

## 📊 Network Outputs

The network environment provides the following outputs for consumption by other environments:

```bash
# VPC Information
output "vpc_id"                    # Main VPC ID
output "vpc_cidr_block"           # VPC CIDR range

# Subnet Information
output "public_subnet_ids"        # Public subnet IDs
output "private_subnet_ids"       # Private subnet IDs
output "db_private_subnet_ids"    # Database subnet IDs

# Gateway Information
output "internet_gateway_id"      # Internet Gateway ID
output "nat_gateway_ids"          # NAT Gateway IDs

# Route Table Information
output "public_route_table_id"    # Public route table ID
output "private_route_table_ids"  # Private route table IDs
output "db_private_route_table_id" # Database route table ID

# Security Information
output "default_security_group_id" # Default security group ID
output "availability_zones"        # Availability zones used
```

## 🔧 Using Network Outputs in Other Environments

### EKS Environment Integration

```hcl
# In EKS main.tf
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "terraform-backend-venkata"
    key    = "dev/network/terraform.tfstate"
    region = "ap-south-1"
  }
}

module "eks" {
  source = "../../../modules/eks"

  # Use network outputs
  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  # ... other configuration
}
```

### Backend Configuration

The network environment uses the same backend configuration as other environments:

```hcl
bucket         = "terraform-backend-venkata"
key            = "dev/network/terraform.tfstate"
region         = "ap-south-1"
encrypt        = true
kms_key_id     = "alias/terraform-backend"
dynamodb_table = "terraform-backend-venkata-locks"
```

## 🔍 Validation and Testing

### 1. Network Validation Commands

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
# Verify VPC
aws ec2 describe-vpcs --filters Name=tag:Name,Values=dev-vpc

# Check subnet configuration
aws ec2 describe-subnets --filters Name=vpc-id,Values=<VPC_ID>

# Verify route tables
aws ec2 describe-route-tables --filters Name=vpc-id,Values=<VPC_ID>

# Check NAT gateways
aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=<VPC_ID>

# Verify VPC endpoints
aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=<VPC_ID>

# Check security groups
aws ec2 describe-security-groups --filters Name=vpc-id,Values=<VPC_ID>
```

### 3. Network Connectivity Tests

```bash
# Test internet access from public subnets
aws ec2 run-instances --image-id ami-0f5ee92e2d63afc18 --count 1 \
  --instance-type t2.micro --key-name <KEY_NAME> \
  --subnet-id <PUBLIC_SUBNET_ID> --associate-public-ip-address

# Test NAT gateway access from private subnets
aws ec2 run-instances --image-id ami-0f5ee92e2d63afc18 --count 1 \
  --instance-type t2.micro --key-name <KEY_NAME> \
  --subnet-id <PRIVATE_SUBNET_ID>

# Test VPC endpoint access
aws s3 ls  # Should work without internet gateway
```

## 🛠️ Maintenance Commands

### Network Management

```bash
# Refresh network state
terraform refresh

# Update network configuration
terraform plan
terraform apply

# Show specific resource
terraform state show aws_vpc.this

# List all network resources
terraform state list | grep -E "(vpc|subnet|nat|route|security)"
```

### Subnet Management

```bash
# Add new subnet
# Modify variables.tf and add subnet configuration to main.tf

# Update route tables
terraform plan  # Review changes
terraform apply

# Modify NAT gateway configuration
# Change nat_gateway_mode in variables.tf
terraform plan
terraform apply
```

### VPC Endpoints Management

```bash
# Add new VPC endpoint
# Update vpc_endpoints variable in variables.tf

# Test endpoint connectivity
aws s3 ls  # Should work from private subnets

# Verify endpoint routing
aws ec2 describe-route-tables --filters Name=vpc-id,Values=<VPC_ID>
```

## 🐛 Troubleshooting

### Common Network Issues

#### 1. NAT Gateway Not Working

**Error:**
```
Private instances cannot access internet
```

**Solution:**
```bash
# Check NAT gateway status
aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=<VPC_ID>

# Verify route table configuration
aws ec2 describe-route-tables --filters Name=vpc-id,Values=<VPC_ID>

# Check subnet associations
aws ec2 describe-route-tables --route-table-ids <ROUTE_TABLE_ID>

# Test NAT gateway
aws ec2 describe-nat-gateways --nat-gateway-ids <NAT_GATEWAY_ID>
```

#### 2. VPC Endpoint Access Issues

**Error:**
```
S3 access failing from private subnets
```

**Solution:**
```bash
# Check VPC endpoint status
aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=<VPC_ID>

# Verify route table entries
aws ec2 describe-route-tables --filters Name=vpc-id,Values=<VPC_ID>

# Test endpoint from instance
aws s3 ls  # Should work without internet

# Check endpoint policies
aws ec2 describe-vpc-endpoints --vpc-endpoint-ids <ENDPOINT_ID>
```

#### 3. Subnet Routing Problems

**Error:**
```
Instances in subnet cannot reach expected destinations
```

**Solution:**
```bash
# Check route table associations
aws ec2 describe-route-tables --filters Name=vpc-id,Values=<VPC_ID>

# Verify subnet associations
aws ec2 describe-subnets --subnet-ids <SUBNET_ID>

# Check route table entries
aws ec2 describe-route-tables --route-table-ids <ROUTE_TABLE_ID>

# Test connectivity
aws ec2 describe-instances --filters Name=subnet-id,Values=<SUBNET_ID>
```

#### 4. Security Group Issues

**Error:**
```
Traffic blocked by security groups
```

**Solution:**
```bash
# Check security group rules
aws ec2 describe-security-groups --group-ids <SECURITY_GROUP_ID>

# Verify network ACLs
aws ec2 describe-network-acls --filters Name=vpc-id,Values=<VPC_ID>

# Check instance security groups
aws ec2 describe-instances --instance-ids <INSTANCE_ID>
```

### Debug Commands

```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform plan

# Check VPC configuration
terraform show | grep -A 10 -B 10 vpc

# Validate network connectivity
aws ec2 describe-instances --filters Name=vpc-id,Values=<VPC_ID>

# Check flow logs (if enabled)
aws logs describe-log-groups --log-group-name-prefix /aws/vpc/flowlogs

# Test VPC endpoint DNS
nslookup s3.ap-south-1.amazonaws.com
```

## 📊 Monitoring and Observability

### VPC Flow Logs (if enabled)

```bash
# Check flow log configuration
aws ec2 describe-flow-logs --filter Name=vpc-id,Values=<VPC_ID>

# View flow logs in CloudWatch
aws logs tail /aws/vpc/flowlogs --follow

# Query flow logs
aws logs start-query \
  --log-group-name /aws/vpc/flowlogs \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string "fields @timestamp, srcAddr, dstAddr, action"
```

### Network Performance Monitoring

```bash
# Monitor NAT gateway metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name PacketsOutToDestination \
  --dimensions Name=NatGatewayId,Value=<NAT_GATEWAY_ID> \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum

# Monitor VPC endpoint metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/VPCEndpoint \
  --metric-name PacketsOut \
  --dimensions Name=EndpointId,Value=<ENDPOINT_ID> \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

### Cost Monitoring

```bash
# Check VPC costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter '{"Dimensions": {"Key": "SERVICE", "Values": ["AmazonVPC"]}}'

# Check NAT Gateway costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter '{"Dimensions": {"Key": "SERVICE", "Values": ["Amazon EC2"]}}' \
  --group-by '{"Type": "DIMENSION", "Key": "USAGE_TYPE"}' \
  --group-by '{"Type": "DIMENSION", "Key": "OPERATION"}'
```

## 🔐 Security Best Practices

### Network Security

- **Subnet Isolation**: Database subnets are isolated from public access
- **Security Groups**: Default deny-all approach with explicit allow rules
- **Network ACLs**: Additional layer of network traffic control
- **Flow Logs**: Monitor and audit network traffic (when enabled)

### Access Control

- **VPC Endpoints**: Private access to AWS services without internet
- **NAT Gateway**: Controlled internet access for private resources
- **Route Tables**: Proper traffic routing and isolation
- **Security Groups**: Instance-level traffic filtering

### Compliance Considerations

- **Resource Tagging**: Consistent tagging for cost allocation and organization
- **Encryption**: Support for KMS encryption of flow logs
- **Audit Trail**: Flow logs provide network traffic visibility
- **Least Privilege**: Minimal required permissions for network operations

## 📞 Support and Resources

### Useful Links

- [VPC Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [Subnet Planning](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html)
- [NAT Gateway Guide](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
- [VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-endpoints.html)
- [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)

### Getting Help

1. Check VPC documentation
2. Review CloudWatch metrics and logs
3. Verify security group and NACL rules
4. Test connectivity with simple instances
5. Check AWS service health dashboard

## 🎯 Next Steps

After successful network setup:

1. **Deploy EKS Cluster**: Use network outputs for EKS deployment
2. **Configure Security**: Set up application-specific security groups
3. **Enable Monitoring**: Configure VPC flow logs for traffic analysis
4. **Network Optimization**: Consider VPC endpoint policies for fine-grained access
5. **Cost Optimization**: Monitor NAT Gateway usage and optimize as needed

---

**Note**: This network infrastructure provides a production-ready foundation for EKS cluster deployment. The modular design allows for easy scaling and modification as requirements evolve.
