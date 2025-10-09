# EKS Addons Comprehensive Testing Guide

This guide provides comprehensive testing for three critical EKS addons in Auto Mode:
- **EBS CSI Driver** - Persistent storage
- **Secrets CSI Driver** - Secure secrets management
- **Pod Identity** - IAM role assumption for pods

## Prerequisites

- EKS cluster with Auto Mode enabled
- ALB Controller installed for ingress access
- kubectl configured to access the cluster
- AWS CLI configured with appropriate permissions

## 1. EBS CSI Driver Test

### What is EBS CSI Driver?
The EBS CSI Driver allows Kubernetes pods to use Amazon EBS volumes as persistent storage. In EKS Auto Mode, this is essential for stateful applications that require durable, high-performance block storage.

### Significance
- **Persistent Storage**: Data survives pod restarts and rescheduling
- **Performance**: Direct attachment to EC2 instances via Auto Mode
- **Scalability**: Dynamic provisioning of EBS volumes
- **Security**: Encrypted volumes by default

### Deployment Components
- **StorageClass**: `ebs-csi-driver` with gp3 volumes and encryption
- **PVC**: 5Gi persistent volume claim
- **Deployment**: Nginx pod serving content from EBS volume
- **Service**: ClusterIP service for internal access
- **Ingress**: ALB ingress for external access at `/ebs-test`

### Testing Steps

1. **Deploy the test**
   ```bash
   kubectl apply -f eks-addons-testing/ebs-csi-driver/deployment.yaml
   ```

2. **Check PVC status**
   ```bash
   kubectl get pvc ebs-test-pvc
   ```
   Expected: STATUS = `Bound`

3. **Check pod status**
   ```bash
   kubectl get pods -l app=ebs-csi-test
   ```
   Expected: STATUS = `Running`

4. **Access the application**
   - Find ALB endpoint: `kubectl get ingress ebs-csi-test-ingress`
   - Access: `http://<ALB-URL>/ebs-test`

5. **Verify persistence**
   ```bash
   # Get pod name
   POD_NAME=$(kubectl get pods -l app=ebs-csi-test -o jsonpath='{.items[0].metadata.name}')

   # Write to volume
   kubectl exec $POD_NAME -- sh -c "echo 'Test data' > /usr/share/nginx/html/test.txt"

   # Delete pod
   kubectl delete pod $POD_NAME

   # Check if data persists (new pod should start automatically)
   kubectl exec $(kubectl get pods -l app=ebs-csi-test -o jsonpath='{.items[0].metadata.name}') -- cat /usr/share/nginx/html/test.txt
   ```
   Expected: Should display "Test data"

6. **Cleanup**
   ```bash
   kubectl delete -f eks-addons-testing/ebs-csi-driver/deployment.yaml
   ```

## 2. Secrets CSI Driver Test

### What is Secrets CSI Driver?
The AWS Secrets & Configuration Provider CSI Driver allows Kubernetes pods to consume secrets from AWS Secrets Manager and AWS Systems Manager Parameter Store as mounted volumes.

### Significance
- **Security**: Secrets are never stored in pod memory or logs
- **Centralized Management**: All secrets managed in AWS
- **Automatic Rotation**: Supports secret rotation without pod restarts
- **Access Control**: IAM-based permissions for secret access

### Deployment Components
- **SecretProviderClass**: References AWS Secrets Manager secret
- **Service Account**: `secrets-sa` with Pod Identity association
- **Deployment**: Nginx pod with secrets mounted as files
- **Service**: ClusterIP service for internal access
- **Ingress**: ALB ingress for external access at `/secrets-test`

### Testing Steps

1. **Create a test secret in AWS Secrets Manager**
   ```bash
   aws secretsmanager create-secret \
     --name test-secret \
     --secret-string '{"username":"test-user","password":"test-pass"}' \
     --region ap-south-1
   ```

2. **Deploy the test**
   ```bash
   kubectl apply -f eks-addons-testing/secrets-csi-driver/deployment.yaml
   ```

3. **Check pod status**
   ```bash
   kubectl get pods -l app=secrets-csi-test
   ```
   Expected: STATUS = `Running`

4. **Access the application**
   - Find ALB endpoint: `kubectl get ingress secrets-csi-test-ingress`
   - Access: `http://<ALB-URL>/secrets-test`

5. **Verify secrets access**
   ```bash
   # Get pod name
   POD_NAME=$(kubectl get pods -l app=secrets-csi-test -o jsonpath='{.items[0].metadata.name}')

   # Check mounted secrets
   kubectl exec $POD_NAME -- ls -la /mnt/secrets/
   kubectl exec $POD_NAME -- cat /mnt/secrets/username
   kubectl exec $POD_NAME -- cat /mnt/secrets/password
   ```
   Expected: Should show username and password from AWS Secrets Manager

6. **Cleanup**
   ```bash
   kubectl delete -f eks-addons-testing/secrets-csi-driver/deployment.yaml
   aws secretsmanager delete-secret --secret-id test-secret --force-delete-without-recovery --region ap-south-1
   ```

## 3. Pod Identity Test

### What is Pod Identity?
EKS Pod Identity allows pods to assume IAM roles without storing AWS credentials. In Auto Mode, this works natively without requiring the eks-pod-identity-agent daemonset.

### Significance
- **Security**: No long-lived credentials in pods
- **Least Privilege**: Granular IAM permissions per pod
- **Simplicity**: No credential management overhead
- **Compatibility**: Works with all AWS SDKs and CLI

### Deployment Components
- **Service Account**: `secrets-sa` with Pod Identity association
- **Deployment**: Amazon Linux container with AWS CLI v2
- **Service**: ClusterIP service for internal access
- **Ingress**: ALB ingress for external access at `/pod-identity-test`

### Testing Steps

1. **Deploy the test**
   ```bash
   kubectl apply -f eks-addons-testing/pod-identity/deployment.yaml
   ```

2. **Check pod status**
   ```bash
   kubectl get pods -l app=pod-identity-test
   ```
   Expected: STATUS = `Running`

3. **Access the application**
   - Find ALB endpoint: `kubectl get ingress pod-identity-test-ingress`
   - Access: `http://<ALB-URL>/pod-identity-test`

4. **Verify Pod Identity**
   ```bash
   # Get pod name
   POD_NAME=$(kubectl get pods -l app=pod-identity-test -o jsonpath='{.items[0].metadata.name}')

   # Test AWS CLI
   kubectl exec $POD_NAME -- aws sts get-caller-identity
   ```
   Expected: Should show assumed role ARN with session name

5. **Check logs**
   ```bash
   kubectl logs $POD_NAME
   ```
   Expected: Should show successful AWS CLI test

6. **Cleanup**
   ```bash
   kubectl delete -f eks-addons-testing/pod-identity/deployment.yaml
   ```

## Common Issues and Troubleshooting

### EBS CSI Driver Issues
- **PVC stuck in Pending**: Check storage class and EBS CSI driver pods
- **Volume not mounting**: Verify node has proper IAM permissions
- **Data not persisting**: Check volume attachment and mount path

### Secrets CSI Driver Issues
- **Secrets not mounting**: Check SecretProviderClass configuration
- **Permission denied**: Verify Pod Identity association and IAM policies
- **Secret not found**: Ensure secret exists in AWS Secrets Manager

### Pod Identity Issues
- **Access denied**: Check Pod Identity association exists
- **Old AWS CLI**: Must use AWS CLI v2.7.0+ for Pod Identity support
- **Wrong region**: Ensure AWS_DEFAULT_REGION is set correctly

## Performance Considerations

### EBS CSI Driver
- Use gp3 for better performance/cost ratio
- Consider volume types based on workload (io1 for high IOPS, st1 for throughput)
- Enable encryption for security

### Secrets CSI Driver
- Secrets are cached for performance
- Consider secret size limits (64KB for Secrets Manager)
- Use Parameter Store for smaller, frequently accessed values

### Pod Identity
- No additional latency for credential retrieval
- Credentials automatically rotated
- Supports all AWS services

## Security Best Practices

### EBS CSI Driver
- Always enable encryption
- Use appropriate volume types for data sensitivity
- Implement backup strategies

### Secrets CSI Driver
- Use least-privilege IAM policies
- Enable secret rotation
- Audit secret access logs

### Pod Identity
- Create specific IAM roles per application
- Use principle of least privilege
- Regularly review and rotate roles

## Monitoring and Observability

### Key Metrics to Monitor
- PVC binding times
- Secret access latency
- Pod Identity credential refresh rates
- EBS volume I/O metrics

### Logging
- Check pod logs for errors
- Monitor AWS CloudTrail for API calls
- Review EKS control plane logs

## Conclusion

These tests validate that your EKS Auto Mode cluster has properly configured:
- ✅ Persistent storage with EBS CSI Driver
- ✅ Secure secrets management with Secrets CSI Driver
- ✅ IAM role assumption with Pod Identity

All deployments are accessible via ALB ingress for easy testing and demonstration.
