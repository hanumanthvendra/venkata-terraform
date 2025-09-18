# AWS EKS Cluster with IRSA and ALB Controller

This repository contains Terraform configurations for deploying a complete AWS EKS (Elastic Kubernetes Service) cluster with IAM Roles for Service Accounts (IRSA) and AWS Load Balancer Controller.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Terraform     │    │      AWS        │    │   Kubernetes    │
│   Modules       │    │   Resources     │    │   Resources     │
│                 │    │                 │    │                 │
│ • VPC & Subnets │    │ • VPC & Subnets │    │ • Service       │
│ • EKS Cluster   │────│ • EKS Cluster   │────│   Account       │
│ • IAM Roles     │    │ • IAM Roles     │    │ • ALB Ingress   │
│ • OIDC Provider │    │ • OIDC Provider │    │ • Deployments   │
│ • ALB Controller│    │ • ALB Controller│    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📁 Project Structure

```
venkata-terraform/
├── modules/                    # Reusable Terraform modules
│   ├── vpc/                   # VPC and networking resources
│   ├── eks/                   # EKS cluster and related resources
│   └── s3-backend/           # S3 backend for Terraform state
├── envs/                      # Environment-specific configurations
│   └── dev/
│       ├── network/          # VPC and networking setup
│       ├── eks/              # EKS cluster setup
│       └── backend/          # S3 backend configuration
└── README.md                 # This documentation
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0
- kubectl
- Helm 3.x
- AWS IAM permissions for EKS, VPC, IAM, and ELB

### 1. Clone and Setup

```bash
git clone <repository-url>
cd venkata-terraform
```

### 2. Configure AWS CLI

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and default region (ap-south-1)
```

### 3. Initialize Terraform Backend

```bash
cd envs/dev/backend
terraform init
terraform plan
terraform apply
```

### 4. Create VPC and Networking

```bash
cd ../network
terraform init
terraform plan
terraform apply
```

### 5. Deploy EKS Cluster

```bash
cd ../eks
terraform init
terraform plan
terraform apply
```

## 🔧 Detailed Setup Guide

### Phase 1: S3 Backend Setup

The S3 backend stores Terraform state files remotely for collaboration and state locking.

**Files:**
- `envs/dev/backend/main.tf` - S3 bucket and DynamoDB table
- `envs/dev/backend/backend.hcl` - Backend configuration

**Commands:**
```bash
cd envs/dev/backend
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

**What it creates:**
- S3 bucket: `terraform-backend-venkata`
- DynamoDB table for state locking
- IAM policies for backend access

### Phase 2: VPC and Networking

Creates the network infrastructure required for EKS.

**Files:**
- `modules/vpc/main.tf` - VPC, subnets, internet gateway, NAT gateway
- `envs/dev/network/main.tf` - Environment-specific network configuration

**Key Resources:**
- VPC with CIDR `10.0.0.0/16`
- Public and private subnets across availability zones
- Internet Gateway for public access
- NAT Gateway for private subnet internet access
- Route tables and security groups

**Commands:**
```bash
cd envs/dev/network
terraform init
terraform plan
terraform apply
```

### Phase 3: EKS Cluster with IRSA

Creates the EKS cluster with OIDC provider and IAM roles for service accounts.

**Files:**
- `modules/eks/main.tf` - EKS cluster, node groups, IAM roles, OIDC provider
- `envs/dev/eks/main.tf` - Environment-specific EKS configuration

**Key Components:**

#### EKS Cluster
```hcl
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }
}
```

#### OIDC Provider for IRSA
```hcl
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_iam_openid_connect_provider.eks.url
}
```

#### IAM Role for ALB Controller
```hcl
resource "aws_iam_role" "alb_controller" {
  name = "${var.cluster_name}-alb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_role_policy.json
}

data "aws_iam_policy_document" "alb_controller_assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}
```

#### Kubernetes Service Account
```hcl
resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
  }
}
```

**Commands:**
```bash
cd envs/dev/eks
terraform init
terraform plan
terraform apply
```

## 🔐 IRSA (IAM Roles for Service Accounts) Deep Dive

### What is IRSA?

IRSA allows Kubernetes service accounts to assume IAM roles, providing secure access to AWS resources without storing credentials in pods.

### Why OIDC is Required

OIDC (OpenID Connect) enables web identity federation:

1. **Trust Establishment**: OIDC provider acts as a trusted identity provider
2. **Token Generation**: Kubernetes generates JWT tokens for service accounts
3. **Role Assumption**: AWS STS validates the token and issues temporary credentials
4. **Secure Access**: Pods use temporary credentials to access AWS resources

### IRSA Flow

```
1. Pod requests AWS resource access
2. Kubernetes injects JWT token
3. Pod calls sts:AssumeRoleWithWebIdentity
4. AWS validates token with OIDC provider
5. AWS issues temporary credentials
6. Pod accesses AWS resources securely
```

### Benefits of IRSA

- **Security**: No long-term credentials stored in pods
- **Rotation**: Automatic credential rotation
- **Scope**: Granular permissions per service account
- **Audit**: Clear identity in CloudTrail logs

## 🚀 ALB Controller Setup

### Manual Installation (Recommended)

After EKS cluster is created, install ALB controller via Helm:

```bash
# Add EKS charts repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install ALB Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=dev-eks-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set vpcId=vpc-0aab67577cbe739bd \
  --set region=ap-south-1
```

### Configuration Parameters

- `clusterName`: EKS cluster name
- `serviceAccount.create`: false (use existing service account)
- `serviceAccount.name`: aws-load-balancer-controller
- `vpcId`: VPC ID where ALB will be created
- `region`: AWS region

## 🔍 Validation and Testing

### 1. Connect to EKS Cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --region ap-south-1 --name dev-eks-cluster

# Verify connection
kubectl get nodes
kubectl get pods -A
```

### 2. Verify Terraform Configuration

```bash
# Check terraform plan shows no changes
cd envs/dev/eks
terraform plan

# Expected output: "No changes. Your infrastructure matches the configuration."
```

### 3. Verify OIDC Provider

```bash
# Check OIDC provider exists in AWS
aws iam list-open-id-connect-providers

# Expected output should include:
# "Arn": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.ap-south-1.amazonaws.com/id/CLUSTER_ID"
```

### 4. Verify IRSA Configuration

```bash
# Check service account annotation
kubectl describe serviceaccount aws-load-balancer-controller -n kube-system

# Should show:
# Annotations: eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/dev-eks-cluster-alb-controller-role
```

### 5. Test ALB Controller Health

```bash
# Check pod status
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Expected output: Pods should be in "Running" status with "1/1" ready
# aws-load-balancer-controller-XXXXX-XXXXX   1/1     Running   0          XXm

# Check logs for errors
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50

# Should show successful startup logs without VPC ID fetch errors
```

### 6. Verify AWS Resource Access

```bash
# Check IAM role exists
aws iam get-role --role-name dev-eks-cluster-alb-controller-role

# Test ALB controller can access VPC resources
aws ec2 describe-vpcs --vpc-ids vpc-0aab67577cbe739bd
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-0aab67577cbe739bd"
```

### 7. Test Ingress Functionality

```bash
# Create a test application
kubectl create deployment nginx-test --image=nginx --port=80
kubectl expose deployment nginx-test --type=ClusterIP --port=80

# Create test ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-test
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-test
            port:
              number: 80
EOF

# Verify ingress and ALB creation
kubectl get ingress
kubectl get targetgroupbindings -A

# Check ALB in AWS Console or via CLI
aws elbv2 describe-load-balancers
```

### 8. Comprehensive Health Check

```bash
# Check all cluster components
kubectl get all -A

# Verify cluster events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check node health
kubectl describe nodes

# Verify ALB controller metrics
kubectl port-forward -n kube-system deployment/aws-load-balancer-controller 8080:8080
# Then visit http://localhost:8080/metrics
```

## 🐛 Troubleshooting

### Common Issues

#### 1. ALB Controller CrashLoopBackOff

**Symptoms:**
```bash
kubectl get pods -n kube-system
# Shows CrashLoopBackOff
```

**Cause:** IRSA not properly configured

**Solution:**
1. Verify OIDC provider exists
2. Check IAM role assume_role_policy
3. Ensure service account annotation is correct
4. Restart ALB controller pods

#### 2. VPC ID Fetch Error

**Error:**
```
failed to get VPC ID from instance metadata
```

**Cause:** IAM permissions or IRSA misconfiguration

**Solution:**
1. Verify IAM role has correct permissions
2. Check OIDC provider configuration
3. Ensure service account is properly annotated

#### 3. Terraform State Lock Issues

**Error:**
```
Error: Error acquiring the state lock
```

**Solution:**
```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID
```

### Debug Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A

# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check service account
kubectl describe serviceaccount aws-load-balancer-controller -n kube-system

# Check IAM role
aws iam get-role --role-name dev-eks-cluster-alb-controller-role

# Check OIDC provider
aws iam list-open-id-connect-providers
```

## 📊 Monitoring and Observability

### CloudWatch Metrics

```bash
# View EKS cluster metrics
aws cloudwatch list-metrics --namespace AWS/EKS

# View ALB metrics
aws cloudwatch list-metrics --namespace AWS/ApplicationELB
```

### Kubernetes Dashboard

```bash
# Install metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Check resource usage
kubectl top nodes
kubectl top pods
```

## 🔄 Updates and Maintenance

### Updating EKS Cluster

```bash
cd envs/dev/eks
terraform plan
terraform apply
```

### Updating ALB Controller

```bash
helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=dev-eks-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### Node Group Updates

```bash
# Update node group configuration in variables.tf
cd envs/dev/eks
terraform plan
terraform apply
```

## 🛡️ Security Best Practices

### IAM Policies

- Use least privilege principle
- Regularly rotate access keys
- Enable MFA for console access
- Use IAM roles instead of users where possible

### Network Security

- Use private subnets for worker nodes
- Configure security groups appropriately
- Enable VPC flow logs
- Use NAT gateways for outbound traffic

### Kubernetes Security

- Keep Kubernetes version up to date
- Use RBAC for authorization
- Enable audit logging
- Regularly scan for vulnerabilities

## 📞 Support and Resources

### Useful Links

- [EKS Documentation](https://docs.aws.amazon.com/eks/)
- [ALB Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)

### Getting Help

1. Check AWS documentation
2. Review CloudWatch logs
3. Check Kubernetes events: `kubectl get events`
4. Verify IAM permissions
5. Check terraform state: `terraform show`

## 🎯 Next Steps

After successful deployment:

1. **Deploy Applications**: Start deploying your applications to EKS
2. **Configure Ingress**: Create ALB ingress resources for external access
3. **Set up Monitoring**: Configure CloudWatch and Prometheus
4. **Implement CI/CD**: Set up automated deployment pipelines
5. **Security Hardening**: Implement additional security measures

---

**Note**: This setup provides a production-ready EKS cluster with IRSA and ALB controller. Always test thoroughly in non-production environments before deploying to production.
