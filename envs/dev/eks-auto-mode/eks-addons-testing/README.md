# EKS Addons Testing Suite

A comprehensive testing suite for EKS Auto Mode addons with unified ALB ingress and hostname-based routing.

## Overview

This testing suite validates three critical EKS addons:
- **EBS CSI Driver** - Persistent storage with Amazon EBS
- **Secrets CSI Driver** - Secure secrets management with AWS Secrets Manager
- **Pod Identity** - IAM role assumption for pods

All three test applications are accessible through a **single unified ALB** with hostname-based routing:
- `ebs-csi.example.com` → EBS CSI Driver Test
- `secrets-csi.example.com` → Secrets CSI Driver Test
- `pod-identity.example.com` → Pod Identity Test

## Architecture

```
                                    ┌─────────────────────┐
                                    │   Application       │
                                    │   Load Balancer     │
                                    │      (ALB)          │
                                    └──────────┬──────────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          │                          │
         ┌──────────▼──────────┐    ┌─────────▼─────────┐    ┌──────────▼──────────┐
         │  ebs-csi.example.com│    │secrets-csi.example│    │pod-identity.example │
         │                     │    │       .com        │    │       .com          │
         └──────────┬──────────┘    └─────────┬─────────┘    └──────────┬──────────┘
                    │                          │                          │
         ┌──────────▼──────────┐    ┌─────────▼─────────┐    ┌──────────▼──────────┐
         │  EBS CSI Test Pod   │    │ Secrets CSI Test  │    │  Pod Identity Test  │
         │  + EBS Volume       │    │ Pod + Secrets     │    │  Pod + AWS CLI      │
         └─────────────────────┘    └───────────────────┘    └─────────────────────┘
```

## Prerequisites

- EKS cluster with Auto Mode enabled
- ALB Controller installed and configured
- kubectl configured to access the cluster
- AWS CLI configured with appropriate permissions
- Proper IAM roles and policies for:
  - EBS CSI Driver
  - Secrets CSI Driver
  - Pod Identity

## Quick Start

### 1. Deploy All Tests

```bash
cd eks-addons-testing
chmod +x deploy-all.sh
./deploy-all.sh
```

The script will:
1. Deploy the service account with Pod Identity
2. Deploy all three test applications
3. Deploy the unified ALB ingress
4. Wait for resources to be ready
5. Display the ALB endpoint and test URLs

### 2. Access the Applications

#### Option A: Using Host Headers (No DNS Required)

```bash
# Get ALB endpoint
ALB_ENDPOINT=$(kubectl get ingress eks-addons-unified-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test EBS CSI Driver
curl -H "Host: ebs-csi.example.com" http://$ALB_ENDPOINT

# Test Secrets CSI Driver
curl -H "Host: secrets-csi.example.com" http://$ALB_ENDPOINT

# Test Pod Identity
curl -H "Host: pod-identity.example.com" http://$ALB_ENDPOINT
```

#### Option B: Using /etc/hosts (For Browser Access)

```bash
# Get ALB endpoint
ALB_ENDPOINT=$(kubectl get ingress eks-addons-unified-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Add to /etc/hosts (requires sudo)
sudo sh -c "echo '$ALB_ENDPOINT ebs-csi.example.com secrets-csi.example.com pod-identity.example.com' >> /etc/hosts"

# Now access via browser:
# - http://ebs-csi.example.com
# - http://secrets-csi.example.com
# - http://pod-identity.example.com
```

#### Option C: Using Route53 (Production Setup)

Create Route53 A records (alias) pointing to the ALB:
- `ebs-csi.example.com` → ALB
- `secrets-csi.example.com` → ALB
- `pod-identity.example.com` → ALB

### 3. Verify Deployments

```bash
# Check all pods
kubectl get pods -l 'app in (ebs-csi-test,secrets-csi-test,pod-identity-test)'

# Check services
kubectl get svc -l 'app in (ebs-csi-test,secrets-csi-test,pod-identity-test)'

# Check ingress
kubectl get ingress eks-addons-unified-ingress

# Check PVC (EBS volume)
kubectl get pvc ebs-test-pvc
```

### 4. Cleanup

```bash
chmod +x cleanup-all.sh
./cleanup-all.sh
```

## File Structure

```
eks-addons-testing/
├── README.md                          # This file
├── EKS-Addons-Testing-Guide.md       # Detailed testing guide
├── service-account.yaml               # Service account for Pod Identity
├── unified-alb-ingress.yaml          # Single ALB with hostname routing
├── deploy-all.sh                      # Deployment automation script
├── cleanup-all.sh                     # Cleanup automation script
├── ebs-csi-driver/
│   └── deployment.yaml               # EBS CSI test deployment
├── secrets-csi-driver/
│   └── deployment.yaml               # Secrets CSI test deployment
└── pod-identity/
    └── deployment.yaml               # Pod Identity test deployment
```

## Testing Each Component

### EBS CSI Driver Test

**What it tests:**
- Dynamic EBS volume provisioning
- Volume mounting and persistence
- Data persistence across pod restarts

**Verification:**
```bash
# Check PVC status
kubectl get pvc ebs-test-pvc

# Test data persistence
POD_NAME=$(kubectl get pods -l app=ebs-csi-test -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- sh -c "echo 'Test data' > /usr/share/nginx/html/test.txt"
kubectl delete pod $POD_NAME
# Wait for new pod to start
kubectl exec $(kubectl get pods -l app=ebs-csi-test -o jsonpath='{.items[0].metadata.name}') -- cat /usr/share/nginx/html/test.txt
```

### Secrets CSI Driver Test

**What it tests:**
- AWS Secrets Manager integration
- Secret mounting as files
- Pod Identity for secret access

**Prerequisites:**
```bash
# Create test secret in AWS Secrets Manager
aws secretsmanager create-secret \
  --name test-secret \
  --secret-string '{"username":"test-user","password":"test-pass"}' \
  --region ap-south-1
```

**Verification:**
```bash
POD_NAME=$(kubectl get pods -l app=secrets-csi-test -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- ls -la /mnt/secrets/
kubectl exec $POD_NAME -- cat /mnt/secrets/username
```

### Pod Identity Test

**What it tests:**
- EKS Pod Identity functionality
- AWS CLI with assumed role
- IAM permissions for pods

**Verification:**
```bash
POD_NAME=$(kubectl get pods -l app=pod-identity-test -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- aws sts get-caller-identity
kubectl logs $POD_NAME
```

## Troubleshooting

### ALB Not Provisioning

```bash
# Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check ingress events
kubectl describe ingress eks-addons-unified-ingress
```

### Pods Not Starting

```bash
# Check pod events
kubectl describe pod <pod-name>

# Check pod logs
kubectl logs <pod-name>
```

### EBS Volume Not Mounting

```bash
# Check PVC status
kubectl describe pvc ebs-test-pvc

# Check storage class
kubectl get storageclass ebs-csi-driver
```

### Secrets Not Mounting

```bash
# Check SecretProviderClass
kubectl describe secretproviderclass aws-secrets-test

# Check service account
kubectl describe sa secrets-sa

# Verify Pod Identity association exists
aws eks list-pod-identity-associations --cluster-name <cluster-name>
```

## Cost Considerations

- **ALB**: ~$0.0225/hour + data processing charges
- **EBS Volume**: ~$0.08/GB-month (gp3)
- **Secrets Manager**: $0.40/secret/month + API calls

**Tip**: Run `cleanup-all.sh` when not testing to avoid unnecessary costs.

## Security Best Practices

1. **Use least-privilege IAM policies** for Pod Identity
2. **Enable encryption** for EBS volumes (already configured)
3. **Rotate secrets regularly** in AWS Secrets Manager
4. **Use private subnets** for pods (configure ALB for internet-facing)
5. **Enable ALB access logs** for audit trails

## Additional Resources

- [EKS Auto Mode Documentation](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
- [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)

## Support

For detailed testing procedures and troubleshooting, see [EKS-Addons-Testing-Guide.md](./EKS-Addons-Testing-Guide.md)
