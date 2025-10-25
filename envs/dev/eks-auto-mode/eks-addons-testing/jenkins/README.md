# Jenkins Installation Guide for EKS Auto Mode

This guide covers installing Jenkins using Helm in an EKS Auto Mode cluster, with integration into an existing unified ALB ingress for host-based routing.

## Overview

Jenkins is deployed as a StatefulSet with persistent storage using the EBS CSI driver. The deployment includes:
- Jenkins controller with persistent volume for `/var/jenkins_home`
- Jenkins agent service for distributed builds
- Integration with existing unified ALB ingress at `jenkins.example.com`

## Prerequisites

- **EKS Cluster**: Auto Mode enabled with required addons
- **ALB Controller**: Installed and configured for ingress management
- **EBS CSI Driver**: Available for persistent storage (storage class: `ebs-csi-driver`)
- **Helm**: Version 3.x installed
- **kubectl**: Configured to access the cluster
- **AWS CLI**: Configured with appropriate permissions

## Installation Steps

### 1. Install Jenkins using Helm

```bash
# Add Jenkins Helm repository (if not already added)
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Install Jenkins with EBS CSI driver persistence
helm install jenkins jenkins/jenkins \
  --namespace default \
  --set controller.serviceType=ClusterIP \
  --set controller.servicePort=8080 \
  --set controller.ingress.enabled=false \
  --set persistence.storageClass=ebs-csi-driver
```

### 2. Wait for Jenkins to be Ready

```bash
# Wait for the pod to be ready
kubectl wait --for=condition=Ready pod/jenkins-0 -n default --timeout=300s
```

### 3. Get Admin Password

```bash
# Retrieve the initial admin password
kubectl exec --namespace default -it svc/jenkins -c jenkins \
  -- /bin/cat /run/secrets/additional/chart-admin-password && echo
```

### 4. Add Jenkins to Unified Ingress

Jenkins is already configured in the unified ALB ingress at `jenkins.example.com`. The ingress configuration includes:

```yaml
- host: jenkins.example.com
  http:
    paths:
    - path: /
      pathType: Prefix
      backend:
        service:
          name: jenkins
          port:
            number: 8080
```

## Access Jenkins

### Option A: Using Host Headers (No DNS Required)

```bash
# Get ALB endpoint
ALB_ENDPOINT=$(kubectl get ingress eks-addons-unified-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Access Jenkins
curl -H "Host: jenkins.example.com" http://$ALB_ENDPOINT
```

### Option B: Using /etc/hosts (For Browser Access)

```bash
# Get ALB endpoint
ALB_ENDPOINT=$(kubectl get ingress eks-addons-unified-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Add to /etc/hosts (requires sudo)
echo "$ALB_ENDPOINT jenkins.example.com" | sudo tee -a /etc/hosts

# Now access via browser:
# http://jenkins.example.com
```

### Option C: Using Route53 (Production Setup)

Create a Route53 A record (alias) pointing `jenkins.example.com` to the ALB.

## Initial Setup

1. **Access Jenkins UI**: Navigate to `http://jenkins.example.com`
2. **Unlock Jenkins**: Use the admin password obtained from the previous step
3. **Install Suggested Plugins**: Choose "Install suggested plugins"
4. **Create Admin User**: Set up your admin user account
5. **Instance Configuration**: Configure Jenkins URL as `http://jenkins.example.com`

## Configuration

### Jenkins Configuration as Code (JCASC)

Jenkins is configured with Configuration as Code enabled. The configuration is stored in ConfigMaps and can be customized by:

1. Creating a ConfigMap with your JCASC configuration:
```bash
kubectl create configmap jenkins-casc-config --from-file=jenkins.yaml=path/to/your/jenkins.yaml
```

2. Updating the Helm deployment to use your config:
```bash
helm upgrade jenkins jenkins/jenkins \
  --set controller.JCasC.configScripts.jenkins='jenkins.yaml' \
  --set controller.JCasC.configScripts.jenkinsConfig='jenkins-casc-config'
```

### Security Considerations

- **RBAC**: Jenkins runs with a service account that has minimal permissions
- **Network Policies**: Consider implementing network policies to restrict traffic
- **Secrets Management**: Use Kubernetes secrets or AWS Secrets Manager for sensitive data
- **Backup**: Regular backups of `/var/jenkins_home` are recommended

### Resource Limits

Default resource limits are set in the Helm chart:
- CPU: 2 cores (requests: 50m)
- Memory: 4Gi (requests: 256Mi)

Adjust as needed based on your workload:
```bash
helm upgrade jenkins jenkins/jenkins \
  --set controller.resources.requests.cpu=100m \
  --set controller.resources.requests.memory=512Mi \
  --set controller.resources.limits.cpu=4 \
  --set controller.resources.limits.memory=8Gi
```

## Troubleshooting

### Jenkins Pod Not Starting

```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=jenkins

# Check pod events
kubectl describe pod jenkins-0

# Check PVC status
kubectl get pvc jenkins
```

### PVC Pending

If the PVC remains in `Pending` status:
```bash
# Check storage class
kubectl get storageclass

# Patch PVC with correct storage class
kubectl patch pvc jenkins -p '{"spec":{"storageClassName":"ebs-csi-driver"}}'
```

### Cannot Access Jenkins

```bash
# Check service
kubectl get svc jenkins

# Check ingress
kubectl get ingress eks-addons-unified-ingress

# Test connectivity
kubectl port-forward svc/jenkins 8080:8080
# Then access http://localhost:8080
```

### ALB Health Checks Failing

```bash
# Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Verify health check endpoint
curl -H "Host: jenkins.example.com" http://$ALB_ENDPOINT/login
```

### Plugin Installation Issues

```bash
# Check Jenkins logs
kubectl logs -l app.kubernetes.io/name=jenkins

# Restart Jenkins pod if needed
kubectl delete pod jenkins-0
```

## Backup and Recovery

### Using Velero for Jenkins Backup

Velero is a Kubernetes backup/restore tool that can backup Jenkins data including PVCs, ConfigMaps, and Secrets.

#### Install Velero

```bash
# Install Velero CLI
wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.3/velero-v1.12.3-linux-amd64.tar.gz
tar -xzf velero-v1.12.3-linux-amd64.tar.gz
sudo mv velero-v1.12.3-linux-amd64/velero /usr/local/bin/

# Install Velero in cluster (requires S3 bucket for backup storage)
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.1 \
  --bucket velero-backups \
  --backup-location-config region=ap-south-1 \
  --snapshot-location-config region=ap-south-1
```

#### Create Jenkins Backup

```bash
# Create backup including Jenkins StatefulSet, PVC, ConfigMaps, and Secrets
velero backup create jenkins-backup-$(date +%Y%m%d) \
  --include-namespaces default \
  --selector app.kubernetes.io/name=jenkins \
  --include-cluster-resources=true
```

#### Restore Jenkins from Backup

```bash
# Scale down Jenkins before restore
kubectl scale statefulset jenkins --replicas=0

# Restore from backup
velero restore create jenkins-restore-$(date +%Y%m%d) \
  --from-backup jenkins-backup-20241015

# Wait for restore to complete
velero restore get

# Scale up Jenkins after restore
kubectl scale statefulset jenkins --replicas=1
```

### Alternative: PVC-based Restore

For simpler restores, you can backup the PVC data and restore by pointing the Helm deployment to the restored PVC:

#### Backup PVC Data

```bash
# Create backup job
kubectl create job jenkins-backup --image=busybox -- \
  tar -czf /backup/jenkins-home-$(date +%Y%m%d).tar.gz -C /var/jenkins_home .

# Copy backup to persistent location (S3, EFS, etc.)
```

#### Restore by Pointing PVC in Helm

```bash
# First, create a new PVC with restored data or restore existing PVC
# Then update Helm deployment to use existing PVC

helm upgrade jenkins jenkins/jenkins \
  --set persistence.existingClaim=jenkins-restored-pvc \
  --set controller.serviceType=ClusterIP \
  --set controller.servicePort=8080 \
  --set controller.ingress.enabled=false \
  --set persistence.storageClass=ebs-csi-driver
```

#### Manual PVC Restore

```bash
# Scale down Jenkins
kubectl scale statefulset jenkins --replicas=0

# Delete existing PVC (WARNING: This deletes current data)
kubectl delete pvc jenkins

# Create new PVC with restored data
kubectl apply -f jenkins-restored-pvc.yaml

# Scale up Jenkins
kubectl scale statefulset jenkins --replicas=1
```

## Scaling Jenkins

### Horizontal Scaling (Multiple Controllers)

For high availability, deploy multiple Jenkins controllers:

```bash
helm upgrade jenkins jenkins/jenkins \
  --set controller.replicaCount=2 \
  --set persistence.existingClaim=jenkins-pvc
```

### Agent Scaling

Jenkins agents can be scaled automatically using Kubernetes plugin or Helm values:

```bash
helm upgrade jenkins jenkins/jenkins \
  --set agent.enabled=true \
  --set agent.replicaCount=3
```

## Monitoring

### Health Checks

Jenkins provides built-in health check endpoints:
- `/login` - Basic authentication check
- `/api/json` - API availability check

### Metrics

Enable Prometheus metrics:
```bash
helm upgrade jenkins jenkins/jenkins \
  --set controller.metrics.enabled=true
```

## Cleanup

### Remove Jenkins

```bash
# Uninstall Helm release
helm uninstall jenkins

# Remove PVC (WARNING: This deletes all data)
kubectl delete pvc jenkins

# Remove from ingress (if needed)
# Edit unified-alb-ingress.yaml to remove Jenkins rule
kubectl apply -f unified-alb-ingress.yaml
```

### Remove Jenkins Namespace (if used)

```bash
kubectl delete namespace jenkins
```

## Cost Considerations

- **EBS Volume**: ~$0.08/GB-month (gp3 storage class)
- **ALB**: Shared with other services (~$0.0225/hour + data transfer)
- **Jenkins Controller**: Minimal compute resources when idle

## Security Best Practices

1. **Regular Updates**: Keep Jenkins and plugins updated
2. **Access Control**: Use Jenkins' built-in security features
3. **Network Security**: Restrict access using security groups and network policies
4. **Secrets Management**: Use external secret management systems
5. **Audit Logging**: Enable audit logging for compliance

## Additional Resources

- [Jenkins on Kubernetes Documentation](https://www.jenkins.io/doc/book/installing/kubernetes/)
- [Jenkins Helm Chart](https://artifacthub.io/packages/helm/jenkinsci/jenkins)
- [Jenkins Configuration as Code](https://jenkins.io/projects/jcasc/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)

## Support

For issues specific to this EKS Auto Mode deployment:
1. Check the troubleshooting section above
2. Review Jenkins and Kubernetes logs
3. Verify ALB controller and EBS CSI driver functionality
4. Consult the main [EKS Addons Testing Guide](../README.md)
