# Secrets CSI Driver - Changes Summary

## Overview
Fixed and restructured the AWS Secrets Manager CSI Driver test deployments to follow AWS best practices with proper support for both IRSA and Pod Identity authentication methods.

## Changes Made

### 1. Updated Files

#### `deployment.yaml` (IRSA Version)
- **Before**: Basic deployment with incorrect volume mount path and naming
- **After**: Properly structured IRSA deployment following AWS examples
- **Key Changes**:
  - Changed volume mount path from `/mnt/secrets` to `/mnt/secrets-store`
  - Updated naming convention to `nginx-irsa-deployment`
  - Moved Service definition before Deployment
  - Updated SecretProviderClass name to `nginx-irsa-deployment-aws-secrets`
  - Changed service account to `nginx-irsa-deployment-sa`
  - Increased replicas from 1 to 2
  - Removed custom nginx startup script (simplified)
  - Fixed volume name to `secrets-store-inline`

### 2. New Files Created

#### `deployment-pod-identity.yaml`
- Complete Pod Identity deployment example
- Includes `usePodIdentity: "true"` parameter in SecretProviderClass
- Uses dedicated service account: `nginx-pod-identity-deployment-sa`
- Separate naming convention to avoid conflicts with IRSA deployment

#### `service-account-irsa.yaml`
- Service account for IRSA method
- Includes IAM role annotation: `eks.amazonaws.com/role-arn`
- Points to role: `dev-eks-auto-mode-3-secrets-store-csi-driver`

#### `service-account-pod-identity.yaml`
- Service account for Pod Identity method
- No IAM role annotation (uses Pod Identity Association instead)

#### `README.md`
- Comprehensive documentation covering:
  - Both deployment methods (IRSA and Pod Identity)
  - Prerequisites for each method
  - Step-by-step deployment instructions
  - Testing procedures
  - Troubleshooting guide
  - Comparison table between methods
  - Cleanup instructions

#### `deploy.sh`
- Automated deployment script
- Supports both IRSA and Pod Identity methods
- Usage: `./deploy.sh [irsa|pod-identity]`
- Includes verification and testing commands

#### `cleanup.sh`
- Automated cleanup script
- Can cleanup individual or all deployments
- Usage: `./cleanup.sh [irsa|pod-identity|all]`

#### `CHANGES.md` (this file)
- Documents all changes made to the secrets CSI driver setup

## Key Improvements

### 1. Proper Structure
- Follows AWS official examples exactly
- Service defined before Deployment
- Correct volume mount paths
- Proper naming conventions

### 2. Two Authentication Methods
- **IRSA (Recommended)**: Uses IAM Roles for Service Accounts
- **Pod Identity**: Alternative method using EKS Pod Identity

### 3. Better Documentation
- Clear prerequisites for each method
- Step-by-step instructions
- Troubleshooting section
- Comparison between methods

### 4. Automation
- Deploy script for easy deployment
- Cleanup script for easy removal
- Both scripts support multiple methods

### 5. Separation of Concerns
- Separate files for each deployment method
- Separate service accounts
- No naming conflicts

## File Structure

```
secrets-csi-driver/
├── deployment.yaml                      # IRSA deployment
├── deployment-pod-identity.yaml         # Pod Identity deployment
├── service-account-irsa.yaml           # IRSA service account
├── service-account-pod-identity.yaml   # Pod Identity service account
├── deploy.sh                           # Deployment script
├── cleanup.sh                          # Cleanup script
├── README.md                           # Documentation
└── CHANGES.md                          # This file
```

## Testing

### IRSA Method
```bash
# Deploy
./deploy.sh irsa

# Verify
kubectl get pods -l app=nginx-irsa
POD_NAME=$(kubectl get pods -l app=nginx-irsa -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- cat /mnt/secrets-store/test-secret

# Cleanup
./cleanup.sh irsa
```

### Pod Identity Method
```bash
# Deploy
./deploy.sh pod-identity

# Verify
kubectl get pods -l app=nginx-pod-identity
POD_NAME=$(kubectl get pods -l app=nginx-pod-identity -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -- cat /mnt/secrets-store/test-secret

# Cleanup
./cleanup.sh pod-identity
```

## Secret Information

- **Name**: test-secret
- **ARN**: arn:aws:secretsmanager:ap-south-1:817928572948:secret:test-secret-2qVI2z
- **Content**: {"secret-value":"my-test-secret-value"}
- **Region**: ap-south-1

## IAM Requirements

The IAM role must have these permissions:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:ap-south-1:817928572948:secret:test-secret-*"
    }
  ]
}
```

## Next Steps

1. Ensure IAM role has proper permissions (see SECRETS-CSI-FIX.md)
2. Choose deployment method (IRSA recommended)
3. Run deployment script: `./deploy.sh irsa`
4. Verify pods are running and secrets are mounted
5. Test accessing the secret

## References

- [AWS Secrets Manager CSI Driver](https://github.com/aws/secrets-store-csi-driver-provider-aws)
- [EKS IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
