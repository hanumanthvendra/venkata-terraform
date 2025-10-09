# EKS Auto Mode Cluster Setup Guide

## Overview

This directory contains a complete Terraform configuration for deploying an Amazon EKS cluster with **EKS Auto Mode** enabled. The setup includes automated compute management, storage provisioning, and load balancer creation through AWS's managed EKS Auto Mode.

### Key Features

- **EKS Auto Mode**: Fully managed compute, storage, and load balancing
- **Remote State Management**: S3 backend with encryption and DynamoDB locking
- **Network Integration**: References existing VPC infrastructure
- **AWS Load Balancer Controller**: Automated ALB management for ingress resources
- **Security**: IAM roles, security groups, and encryption enabled

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Terraform     │───▶│   EKS Cluster    │───▶│   Node Pools    │
│   Management    │    │  (Auto Mode)     │    │  (Auto-scaling) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   ALB Controller│    │   Storage (EBS)  │    │   Security      │
│   (Helm Install)│    │   (Auto-provision)│   │   Groups        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Prerequisites

### 1. AWS Infrastructure
- **VPC**: Existing VPC with private subnets
- **S3 Backend**: `terraform-backend-venkata` bucket
- **DynamoDB**: `terraform-backend-venkata-locks` table
- **KMS Key**: `alias/terraform-backend` for encryption

### 2. Tools Required
- **Terraform**: Version >= 1.5.7
- **AWS CLI**: Configured with appropriate permissions
- **kubectl**: For cluster interaction
- **Helm**: For ALB controller installation

### 3. IAM Permissions
The deployment requires IAM permissions for:
- EKS cluster management
- EC2 instance management (Auto Mode)
- Load balancer creation
- IAM role creation
- KMS encryption

## Configuration Files

### 1. `main.tf` - Main Configuration

#### EKS Module Configuration
```hcl
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                   = local.name
  cluster_version                = local.kubernetes_version
  cluster_endpoint_public_access = var.enable_public_access

  # EKS Auto Mode Configuration
  cluster_compute_config = {
    enabled    = true
    node_pools = var.node_pools
  }

  # Network configuration from remote state
  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

  # Required addons for Auto Mode
  cluster_addons = {
    coredns = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni = { most_recent = true }
    aws-ebs-csi-driver = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
  }
}
```

#### AWS Load Balancer Controller Setup
The configuration includes a complete ALB controller installation:

1. **IAM Role Creation**: Dedicated role for ALB controller
2. **Custom Policy**: Comprehensive permissions for ALB management
3. **Helm Installation**: Automated deployment via null_resource

**Key Features:**
- Service Account with IRSA (IAM Roles for Service Accounts)
- VPC and region configuration
- Automatic namespace creation
- Proper dependency management

### 2. `variables.tf` - Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `cluster_name` | `eks-auto-mode-3` | Name of the EKS cluster |
| `kubernetes_version` | `1.33` | Kubernetes version |
| `environment` | `dev` | Environment identifier |
| `region` | `ap-south-1` | AWS region |
| `enable_public_access` | `true` | Public API access |
| `node_pools` | `["general-purpose"]` | Auto Mode node pools |

### 3. `backend.hcl` - State Management

```hcl
bucket         = "terraform-backend-venkata"
key            = "dev/eks-auto-mode-3/terraform.tfstate"
region         = "ap-south-1"
encrypt        = true
kms_key_id     = "alias/terraform-backend"
dynamodb_table = "terraform-backend-venkata-locks"
```

**Security Features:**
- **Encryption**: KMS key encryption for state files
- **Locking**: DynamoDB table prevents concurrent modifications
- **Versioning**: S3 bucket versioning enabled

### 4. `outputs.tf` - Exposed Information

The configuration exposes critical cluster information:
- Cluster endpoint and authentication data
- Security group IDs
- IAM role ARNs
- OIDC provider information
- Node pool configurations

## Deployment Process

### Step 1: Initialize Terraform
```bash
cd /Users/venkata/Documents/repos/venkata-terraform/envs/dev/eks-auto-mode
terraform init
```

### Step 2: Review Configuration
```bash
terraform plan
```

### Step 3: Deploy Infrastructure
```bash
terraform apply
```

### Step 4: Configure kubectl
```bash
aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region ap-south-1
```

## ALB Controller Analysis

### What `alb-test.yaml` Does

The `alb-test.yaml` file is a **comprehensive test configuration** that demonstrates ALB functionality:

#### 1. IngressClass Definition
```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: ingress.k8s.aws/alb
```

**Purpose**: Defines the default ingress class for ALB controller

#### 2. Test Application Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-alb-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-alb-test
  template:
    metadata:
      labels:
        app: nginx-alb-test
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        ports:
        - containerPort: 80
```

**Purpose**: Deploys a test nginx application with 2 replicas

#### 3. Service Configuration
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-alb-test
spec:
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: nginx-alb-test
  type: ClusterIP
```

**Purpose**: Creates internal service for pod communication

#### 4. Ingress Resource
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-alb-test
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
spec:
  ingressClassName: alb
  rules:
  - host: test.dev-eks-auto-mode-3.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-alb-test
            port:
              number: 80
```

**Purpose**: Creates internet-facing ALB with health checks

#### 5. Alternative LoadBalancer Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb-test
  labels:
    app: nginx-alb-test
spec:
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: nginx-alb-test
  type: LoadBalancer
```

**Purpose**: Demonstrates traditional LoadBalancer service

## Helm Installation Analysis

### Current Implementation
The main.tf uses `null_resource` with `local-exec` provisioner:

```hcl
resource "null_resource" "install_alb_controller" {
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = <<EOT
      aws eks update-kubeconfig --name ${local.name} --region ${local.region}
      helm repo add eks https://aws.github.io/eks-charts
      helm repo update
      helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --create-namespace \
        --set clusterName=${local.name} \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=${aws_iam_role.aws_load_balancer_controller.arn} \
        --set region=${local.region} \
        --set vpcId=${data.terraform_remote_state.network.outputs.vpc_id} \
        --set enablePodIdentity=false \
        --set enableServiceAccountPermissions=true \
        --wait
    EOT
  }
}
```

### Analysis: Is Helm Installation Helpful or Stale?

#### ✅ **Advantages of Current Approach:**
1. **Full Automation**: Complete hands-off installation
2. **Dependency Management**: Proper ordering with `depends_on`
3. **Configuration**: All parameters set via Terraform variables
4. **Error Handling**: `--wait` flag ensures completion
5. **Reproducibility**: Consistent installation across environments

#### ⚠️ **Potential Issues:**
1. **State Management**: Helm releases not tracked in Terraform state
2. **Drift Detection**: Terraform doesn't know about Helm-managed resources
3. **Updates**: Manual intervention required for controller updates
4. **Rollback**: Limited rollback capabilities

#### 🔄 **Better Alternatives:**

**Option 1: Helm Provider (Recommended)**
```hcl
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  create_namespace = true
  version    = "1.8.1"  # Pin specific version

  set {
    name  = "clusterName"
    value = local.name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller.arn
  }

  set {
    name  = "region"
    value = local.region
  }

  set {
    name  = "vpcId"
    value = data.terraform_remote_state.network.outputs.vpc_id
  }
}
```

**Option 2: Kubernetes Provider**
```hcl
resource "kubernetes_manifest" "alb_controller" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "aws-load-balancer-controller"
      namespace = "kube-system"
    }
    # ... complete manifest
  }
}
```

## Cleanup Recommendations

### Current State Analysis
Based on the terraform plan output, your infrastructure is **clean** with no pending changes.

### Recommended Cleanup Actions

#### 1. Remove Test Files (Optional)
```bash
# Remove test files if not needed
rm alb-test.yaml
```

#### 2. Update Provider Versions
Consider updating to latest stable versions:
```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.70.0"
    }
  }
}
```

#### 3. Add Kubernetes Provider (Recommended)
```hcl
provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
```

#### 4. Consider Migrating to Helm Provider
Replace the `null_resource` with proper Helm provider for better state management.

## Security Considerations

### 1. IAM Permissions
- **Principle of Least Privilege**: Current policy is comprehensive but secure
- **IRSA**: Properly configured for service account authentication
- **KMS**: State encryption enabled

### 2. Network Security
- **Private Subnets**: Nodes deployed in private subnets
- **Security Groups**: Managed by EKS Auto Mode
- **Public Access**: API endpoint publicly accessible (consider restricting)

### 3. Cost Optimization
- **Auto Mode**: Automatically scales based on workload
- **Node Pools**: Configurable instance types
- **Load Balancers**: Created on-demand

## Monitoring and Troubleshooting

### Useful Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get nodepools

# Check ALB controller
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Check ingress resources
kubectl get ingress

# Check load balancers
aws elbv2 describe-load-balancers --region ap-south-1

# View controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

### Common Issues

1. **ALB Controller Not Installing**: Check IAM permissions and VPC configuration
2. **Ingress Not Working**: Verify DNS configuration and security groups
3. **Node Scaling Issues**: Check Auto Mode configuration and resource limits
4. **State Lock Issues**: Ensure DynamoDB table is accessible

## Conclusion

Your EKS Auto Mode setup is **well-architected** and follows AWS best practices. The Helm installation approach works but could be improved with proper Terraform providers for better state management. The configuration is production-ready with proper security, monitoring, and automation features.

**Recommendation**: Consider migrating to Helm provider for better infrastructure-as-code management, but the current setup is functional and secure.
