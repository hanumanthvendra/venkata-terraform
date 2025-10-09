# AWS Secrets Manager CSI Driver - Deployment Guide

This directory contains deployment configurations for testing the AWS Secrets Manager CSI Driver with two authentication methods, aligned with the Terraform configuration in `venkata-terraform/modules/eks-addons/secrets-csi-driver/`.

## Terraform Configuration

The deployments are designed to work with the Terraform module that creates:

- **Pod Identity (Default)**: IAM role `dev-eks-auto-mode-3-secrets-store-csi-driver` with broad access (`*`)
- **IRSA (Alternative)**: IAM role `dev-eks-auto-mode-3-nginx-irsa-role` with restricted access (`test-secret-*`)

## Files

### Core Deployment Files
- **deployment.yaml** - IRSA (IAM Roles for Service Accounts) deployment
- **deployment-pod-identity.yaml** - Pod Identity deployment (matches Terraform defaults)

### Supporting Files
- **secret-provider-class-irsa.yaml** - SecretProviderClass for IRSA
- **secret-provider-class-pod-identity.yaml** - SecretProviderClass for Pod Identity
- **service-account-irsa.yaml** - Service Account for IRSA deployment
- **service-account-pod-identity.yaml** - Service Account for Pod Identity (matches Terraform: `secrets-sa`)

### Utilities
- **deploy.sh** - Deployment script for both methods
- **cleanup.sh** - Cleanup script
- **README.md** - This documentation

## Secret Information

- **Secret Name**: `test-secret`
- **Secret ARN**: `arn:aws:secretsmanager:ap-south-1:817928572948:secret:test-secret-2qVI2z`
- **Secret Content**: `{"secret-value":"my-test-secret-value"}`
- **Region**: `ap-south-1`

## Currently Deployed Services

### 1. IRSA Deployment (`nginx-irsa-deployment`)
- **Deployment**: `nginx-irsa-deployment` (2 replicas)
- **Service**: `nginx-irsa-deployment` (ClusterIP:172.20.71.158)
- **SecretProviderClass**: `nginx-irsa-deployment-aws-secrets`
- **Service Account**: `nginx-irsa-deployment-sa`
- **Labels**: `app=nginx-irsa`

### 2. Pod Identity Deployment (`secrets-csi-test-app`)
- **Deployment**: `secrets-csi-test-app` (2 replicas)
- **Service**: `secrets-csi-test-service` (ClusterIP:172.20.76.0)
- **SecretProviderClass**: `aws-secrets-test-pod-identity`
- **Service Account**: `secrets-sa`
- **Labels**: `app=secrets-csi-test`

## Deployment Methods

### Method 1: Pod Identity (Terraform Default - Recommended)

Pod Identity is the default authentication method configured by the Terraform module.

#### Prerequisites

1. **Terraform-managed resources** (automatically created):
   - Service Account: `secrets-sa` (namespace: `default`)
   - IAM Role: `dev-eks-auto-mode-3-secrets-store-csi-driver`
   - Pod Identity Association
   - IAM Policy with broad access (`*`)

2. **SecretProviderClass** with Pod Identity enabled:
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: aws-secrets-test-pod-identity
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "test-secret"
        objectType: "secretsmanager"
    region: "ap-south-1"
    usePodIdentity: "true"
```

#### Deploy

```bash
# Deploy SecretProviderClass
kubectl apply -f secret-provider-class-pod-identity.yaml

# Deploy Service Account (matches Terraform)
kubectl apply -f service-account-pod-identity.yaml

# Deploy the application
kubectl apply -f deployment-pod-identity.yaml

# Verify deployment
kubectl get pods -l app=secrets-csi-test
kubectl get svc secrets-csi-test-service
```

#### Test

```bash
# Check if secret is mounted
POD_NAME=$(kubectl get pods -l app=secrets-csi-test -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- cat /mnt/secrets-store/test-secret

# Port-forward to access the service
kubectl port-forward svc/secrets-csi-test-service 8080:80

# Open browser to http://localhost:8080
```

### Method 2: IRSA (IAM Roles for Service Accounts)

IRSA provides an alternative authentication method with more restrictive permissions.

#### Prerequisites

1. **Service Account** with IAM role annotation:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nginx-irsa-deployment-sa
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::817928572948:role/dev-eks-auto-mode-3-nginx-irsa-role
```

2. **IAM role** with restricted permissions (scoped to `test-secret-*`)

3. **SecretProviderClass** without Pod Identity:
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: nginx-irsa-deployment-aws-secrets
spec:
  provider: aws
  parameters:
    objects: |
        - objectName: "test-secret"
          objectType: "secretsmanager"
    region: "ap-south-1"
```

#### Deploy

```bash
# Deploy SecretProviderClass
kubectl apply -f secret-provider-class-irsa.yaml

# Deploy Service Account
kubectl apply -f service-account-irsa.yaml

# Deploy the application
kubectl apply -f deployment.yaml

# Verify deployment
kubectl get pods -l app=nginx-irsa
kubectl get svc nginx-irsa-deployment
```

#### Test

```bash
# Check if secret is mounted
POD_NAME=$(kubectl get pods -l app=nginx-irsa -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- cat /mnt/secrets-store/test-secret

# Port-forward to access the service
kubectl port-forward svc/nginx-irsa-deployment 8081:80

# Open browser to http://localhost:8081
```

## Key Differences

| Feature | Pod Identity (Default) | IRSA |
|---------|----------------------|------|
| Terraform Module | ✅ Default | ❌ Manual setup required |
| Service Account | `secrets-sa` | `nginx-irsa-deployment-sa` |
| IAM Role | `dev-eks-auto-mode-3-secrets-store-csi-driver` | `dev-eks-auto-mode-3-nginx-irsa-role` |
| Permissions Scope | `*` (all secrets) | `test-secret-*` (restricted) |
| SecretProviderClass Parameter | `usePodIdentity: "true"` | None |
| Setup Complexity | ✅ Simple (Terraform-managed) | ⚠️ Manual annotation required |

## Quick Deployment Script

Use the provided deployment script for easy testing:

```bash
# Deploy Pod Identity (default)
./deploy.sh

# Deploy IRSA
./deploy.sh irsa
```

## IAM Roles Analysis

### Pod Identity Role: `dev-eks-auto-mode-3-secrets-store-csi-driver`
- **Type**: Pod Identity (pods.eks.amazonaws.com)
- **Permissions**: `secretsmanager:GetSecretValue`, `secretsmanager:DescribeSecret` on `*`
- **Scope**: Broad access to all secrets
- **Terraform-managed**: Yes

### IRSA Role: `dev-eks-auto-mode-3-nginx-irsa-role`
- **Type**: Web Identity (OIDC)
- **Permissions**: `secretsmanager:GetSecretValue`, `secretsmanager:DescribeSecret` on `test-secret-*`
- **Scope**: Restricted to test secrets
- **Terraform-managed**: No (manual setup)

## Troubleshooting

### Secret Not Mounting

1. **Check CSI Driver Pods**:
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=secrets-store-csi-driver
```

2. **Check Pod Events**:
```bash
kubectl describe pod <pod-name>
```

3. **Check IAM Permissions**:
```bash
# For Pod Identity
kubectl describe sa secrets-sa

# For IRSA
kubectl describe sa nginx-irsa-deployment-sa
```

4. **Check CSI Driver Logs**:
```bash
kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws
```

### Common Errors

**Error**: `Failed to fetch secret from all regions`
- **Solution**: Ensure IAM role has `secretsmanager:GetSecretValue` and `secretsmanager:DescribeSecret` permissions

**Error**: `SecretProviderClass not found`
- **Solution**: Ensure SecretProviderClass is created in the same namespace as the pod

**Error**: `Service account not found`
- **Solution**: Create the service account before deploying the application

## Cleanup

```bash
# Use the cleanup script
./cleanup.sh

# Or manual cleanup
kubectl delete -f deployment.yaml -f deployment-pod-identity.yaml
kubectl delete -f secret-provider-class-irsa.yaml -f secret-provider-class-pod-identity.yaml
kubectl delete -f service-account-irsa.yaml -f service-account-pod-identity.yaml
```

## Integration with Terraform

This YAML configuration is designed to work alongside the Terraform module:

```hcl
module "secrets_csi_driver" {
  source = "../eks-addons/secrets-csi-driver"

  cluster_name                    = "dev-eks-auto-mode-3"
  namespace                       = "default"
  service_account_name            = "secrets-sa"
  secrets_manager_arns            = ["*"]
  create_service_account          = true
  create_pod_identity_association = true
}
```

The Terraform module creates the Pod Identity setup, while these YAML files provide alternative IRSA deployment and testing configurations.

## References

- [AWS Secrets Manager CSI Driver](https://github.com/aws/secrets-store-csi-driver-provider-aws)
- [EKS IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [Terraform Module](../modules/eks-addons/secrets-csi-driver/)
