# Secrets CSI Driver - IAM Permissions Fix

## Issue
The Secrets CSI Driver pod is failing with:
```
Failed to fetch secret from all regions. Verify secret exists and required permissions are granted for: test-secret
```

## Root Cause
The IAM role `dev-eks-auto-mode-3-secrets-store-csi-driver` doesn't have permissions to access the AWS Secrets Manager secret.

## Solution

### Option 1: Add IAM Policy via AWS Console

1. Go to AWS IAM Console
2. Find role: `dev-eks-auto-mode-3-secrets-store-csi-driver`
3. Add inline policy or attach managed policy with these permissions:

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

### Option 2: Add IAM Policy via AWS CLI

```bash
# Create policy document
cat > /tmp/secrets-policy.json <<EOF
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
EOF

# Add inline policy to the role
aws iam put-role-policy \
  --role-name dev-eks-auto-mode-3-secrets-store-csi-driver \
  --policy-name SecretsManagerAccess \
  --policy-document file:///tmp/secrets-policy.json \
  --region ap-south-1
```

### Option 3: Update Terraform Module

Update the Terraform module at `venkata-terraform/modules/eks-addons/secrets-csi-driver/main.tf` to include the secret ARN in the IAM policy.

## After Fixing Permissions

1. Delete the existing pods to force recreation:
```bash
kubectl delete pod -l app=secrets-csi-test -n default
```

2. Wait for new pods to start:
```bash
kubectl get pods -l app=secrets-csi-test -n default -w
```

3. Verify the secret is mounted:
```bash
POD_NAME=$(kubectl get pods -l app=secrets-csi-test -n default -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD_NAME -n default -- ls -la /mnt/secrets/
kubectl exec $POD_NAME -n default -- cat /mnt/secrets/test-secret
```

## Expected Result

The pod should start successfully and the secret should be accessible at `/mnt/secrets/test-secret`.
