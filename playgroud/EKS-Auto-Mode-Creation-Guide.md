# EKS Auto Mode Creation Process - Complete Guide

## Overview
This guide provides a comprehensive breakdown of how an EKS cluster with Auto Mode is created using the terraform-aws-eks module, covering every step from infrastructure setup to testing.

## 1. Prerequisites & Setup

### Terraform Requirements
- **Terraform version:** `>= 1.5.7`
- **AWS Provider version:** `>= 6.13`
- **Region:** Configurable (defaults to us-west-2)

### File: `versions.tf`
```hcl
terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.13"
    }
  }
}
```

## 2. VPC Infrastructure Creation

### Module Configuration
**Module:** `terraform-aws-modules/vpc/aws` (version ~> 6.0)

### Network Architecture
- **VPC CIDR:** `10.0.0.0/16`
- **Availability Zones:** 3 AZs (configurable)
- **Private Subnets:** `/20` subnets per AZ
- **Public Subnets:** `/24` subnets per AZ
- **Intra Subnets:** `/24` subnets per AZ

### What Gets Created
1. **VPC** with specified CIDR block
2. **3 Private Subnets** (one per AZ) using `cidrsubnet(local.vpc_cidr, 4, k)`
3. **3 Public Subnets** (one per AZ) using `cidrsubnet(local.vpc_cidr, 8, k + 48)`
4. **3 Intra Subnets** (one per AZ) using `cidrsubnet(local.vpc_cidr, 8, k + 52)`
5. **NAT Gateway** (single, for cost optimization)
6. **Route tables** and **Internet Gateway**
7. **Security Groups** for load balancers

### Kubernetes-Specific Tags
```hcl
public_subnet_tags = {
  "kubernetes.io/role/elb" = 1
}
private_subnet_tags = {
  "kubernetes.io/role/internal-elb" = 1
}
```

## 3. EKS Cluster Creation with Auto Mode

### Main Module Configuration
```hcl
module "eks" {
  source = "../.."  # terraform-aws-eks root module

  name                   = local.name  # "ex-eks-auto-mode"
  kubernetes_version     = "1.33"
  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
}
```

### A. Cluster Resources Created

#### 1. EKS Cluster
- **Kubernetes Version:** 1.33
- **API Server Access:** Public endpoint enabled
- **Deletion Protection:** Configurable
- **Platform Version:** Latest

#### 2. Enhanced IAM Role for Auto Mode
The cluster IAM role gets additional policies for Auto Mode:
- `AmazonEKSClusterPolicy` (standard)
- `AmazonEKSComputePolicy` (auto mode)
- `AmazonEKSBlockStoragePolicy` (auto mode)
- `AmazonEKSLoadBalancingPolicy` (auto mode)
- `AmazonEKSNetworkingPolicy` (auto mode)

#### 3. Security Configuration
- **Cluster Security Group** with ingress rules for node-to-cluster communication (port 443)
- **Access Entries** for cluster creator admin permissions
- **OIDC Provider** for IRSA (IAM Roles for Service Accounts)

### B. Auto Mode Specific Resources

#### 1. Node IAM Role
**Role Name:** `{cluster-name}-eks-auto`
**Attached Policies:**
- `AmazonEKSWorkerNodeMinimalPolicy`
- `AmazonEC2ContainerRegistryPullOnly`

#### 2. Compute Configuration
```hcl
compute_config = {
  enabled    = true
  node_pools = ["general-purpose"]
}
```
- **Auto Mode:** Enabled
- **Node Pools:** "general-purpose" pool
- **Automatic Scaling:** Based on pod resource requests
- **Instance Selection:** Automatic based on workload requirements

#### 3. Storage Configuration
- **EBS Volume Provisioning:** Automatic for persistent workloads
- **Storage Classes:** Managed by Auto Mode
- **Encryption:** Configurable KMS encryption

#### 4. Load Balancer Configuration
- **ALB/NLB Creation:** Automatic for LoadBalancer services
- **Security Groups:** Managed automatically
- **Target Groups:** Created as needed

#### 5. Network Configuration
- **VPC CNI:** Configured for pod networking
- **Security Groups:** Automatic management
- **Network Policies:** Support enabled

### C. Observability & Monitoring

#### 1. CloudWatch Logging
- **Log Group:** `/aws/eks/${cluster-name}/cluster`
- **Retention:** 90 days (configurable)
- **Log Types:** audit, api, authenticator

#### 2. Cluster Addons
- **VPC CNI:** For pod networking
- **CoreDNS:** For service discovery
- **Kube-proxy:** For load balancing

## 4. Custom Node Pools Module

### Purpose
Demonstrates IAM resource creation for custom node pools without creating additional clusters.

```hcl
module "eks_auto_custom_node_pools" {
  source = "../.."

  create_auto_mode_iam_resources = true  # Only creates IAM, no cluster
  # ... other config
}
```

### Created Resources
- **IAM Role** with Auto Mode permissions
- **IAM Policies** for compute, storage, networking, load balancing
- **Custom Resource Permissions** for tagging and resource creation

## 5. Testing & Validation

### Test Deployment
**File:** `deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
spec:
  replicas: 3
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      terminationGracePeriodSeconds: 0
      containers:
        - name: inflate
          image: public.ecr.aws/eks-distro/kubernetes/pause:3.10
          resources:
            requests:
              cpu: 1
```

### Usage Commands
```bash
# Update kubeconfig
aws eks update-kubeconfig --name $(terraform output -raw cluster_name)

# Deploy test workload
kubectl apply -f deployment.yaml

# Verify Auto Mode creates nodes automatically
kubectl get nodes

# Check node pool status
kubectl get nodepools

# Verify pod scheduling
kubectl get pods -o wide
```

## 6. Key Auto Mode Features

### Compute Management
- **Automatic Node Provisioning:** Based on pod resource requests
- **Node Pool Management:** "general-purpose" pool with automatic scaling
- **Instance Type Selection:** Automatic based on workload requirements
- **Node Lifecycle Management:** Automatic upgrades and repairs

### Storage
- **EBS Volume Provisioning:** Automatic for StatefulSets and PVCs
- **Storage Class Management:** Built-in storage classes
- **Volume Encryption:** KMS encryption support
- **Snapshot Management:** Automated backups

### Networking
- **Load Balancer Creation:** ALB/NLB for LoadBalancer services
- **Security Group Management:** Automatic rule creation
- **VPC CNI Configuration:** Pod networking
- **Network Policy Support:** Security policies

### Security
- **IAM Roles for Service Accounts:** Pod identity
- **Pod Identity Associations:** Service account linking
- **Network Policies:** Traffic control
- **Security Group Rules:** Automatic management

## 7. Outputs & Monitoring

### Available Outputs
- **Cluster Endpoint:** API server endpoint
- **Cluster Certificate Authority:** Base64 encoded CA data
- **IAM Role ARNs:** Cluster and node roles
- **Security Group IDs:** Cluster and node security groups
- **OIDC Provider:** IRSA configuration
- **Node IAM Role:** Auto mode node role details

### Monitoring
- **CloudWatch Logs:** Cluster logs and metrics
- **EKS Console:** Cluster and node pool status
- **Auto Scaling:** Node pool scaling events
- **Resource Utilization:** CPU, memory, storage metrics

## 8. Cost Considerations

### Infrastructure Costs
- **EKS Cluster:** Standard EKS pricing
- **Auto Mode:** Additional costs for managed compute
- **NAT Gateway:** $0.045/hour + data transfer
- **CloudWatch Logs:** $0.50/GB ingested + storage

### Optimization Strategies
- **Single NAT Gateway:** Cost optimization (vs. one per AZ)
- **Log Retention:** Configurable retention period
- **Node Pool Sizing:** Right-sizing based on workload
- **Storage Classes:** Appropriate storage tiers

## 9. Security Best Practices

### IAM
- **Least Privilege:** Minimal required permissions
- **IRSA:** Use service account roles
- **Access Entries:** Explicit access control

### Network
- **Private Endpoints:** Consider private API access
- **Security Groups:** Minimal required rules
- **Network Policies:** Implement pod-to-pod security

### Encryption
- **KMS Encryption:** For secrets and EBS volumes
- **TLS:** API server communication
- **Pod Security:** Standards and policies

## 10. Troubleshooting

### Common Issues
1. **Node Pool Creation:** Check IAM permissions and limits
2. **Pod Scheduling:** Verify resource requests and limits
3. **Network Connectivity:** Check security group rules
4. **Storage Issues:** Verify KMS key permissions

### Debugging Commands
```bash
# Check cluster status
kubectl get nodes
kubectl get nodepools

# Check pod events
kubectl describe pod <pod-name>

# Check EKS events
aws eks list-clusters
aws eks describe-cluster --name <cluster-name>

# Check IAM roles
aws iam get-role --role-name <role-name>
```

This comprehensive setup provides a production-ready EKS cluster with Auto Mode that automatically manages compute resources, storage, and load balancers based on workload requirements.
