# AWS Load Balancer Controller - Ingress Configuration Guide

## Overview

This guide covers the AWS Load Balancer Controller (ALB) configuration for EKS Auto Mode, including ingress setup, host-based routing, and troubleshooting.

## Architecture

EKS Auto Mode provides built-in ALB support without requiring the AWS Load Balancer Controller (LBC) to be installed. The ALB is managed directly by EKS.

### Key Components

- **IngressClass**: `alb` (EKS Auto Mode built-in)
- **Load Balancer Type**: Application Load Balancer (ALB)
- **Routing**: Host-based routing with multiple domains
- **Target Type**: IP (pods receive traffic directly)

## Ingress Configuration

### Unified Ingress Setup

The `unified-alb-ingress.yaml` provides host-based routing for multiple services:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: eks-addons-unified-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-path: /
spec:
  ingressClassName: alb
  rules:
  - host: nginx-irsa-secrets.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-irsa-deployment
            port:
              number: 80
  - host: secrets-csi-test.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secrets-csi-test-service
            port:
              number: 80
```

### ALB Annotations

| Annotation | Value | Description |
|------------|-------|-------------|
| `alb.ingress.kubernetes.io/scheme` | `internet-facing` | Public ALB |
| `alb.ingress.kubernetes.io/target-type` | `ip` | Direct pod targeting |
| `alb.ingress.kubernetes.io/healthcheck-protocol` | `HTTP` | Health check protocol |
| `alb.ingress.kubernetes.io/healthcheck-path` | `/` | Health check endpoint |
| `alb.ingress.kubernetes.io/listen-ports` | `[{"HTTP": 80}]` | Listening ports |

## Service Configuration

### nginx-irsa-deployment Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-irsa-deployment
spec:
  selector:
    app: nginx-irsa
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  type: ClusterIP
```

### secrets-csi-test Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: secrets-csi-test-service
spec:
  selector:
    app: secrets-csi-test
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  type: ClusterIP
```

## DNS Configuration

### Local Development (/etc/hosts)

For local testing, add entries to your `/etc/hosts` file:

```bash
# Get ALB DNS name
ALB_DNS=$(kubectl get ingress eks-addons-unified-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Add to /etc/hosts
echo "$ALB_DNS nginx-irsa-secrets.example.com" | sudo tee -a /etc/hosts
echo "$ALB_DNS secrets-csi-test.example.com" | sudo tee -a /etc/hosts
```

### Production DNS

Create Route53 CNAME records:

```bash
# Get ALB DNS
ALB_DNS=$(kubectl get ingress eks-addons-unified-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Create Route53 records
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "nginx-irsa-secrets.example.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'$ALB_DNS'"}]
      }
    }, {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "secrets-csi-test.example.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'$ALB_DNS'"}]
      }
    }]
  }'
```

## Deployment Steps

### 1. Deploy Applications

```bash
# Deploy IRSA secrets CSI driver
cd eks-addons-testing/secrets-csi-driver
./deploy.sh irsa

# Deploy Pod Identity secrets CSI driver
./deploy.sh pod-identity
```

### 2. Deploy Ingress

```bash
kubectl apply -f ../unified-alb-ingress.yaml
```

### 3. Verify Deployment

```bash
# Check ingress status
kubectl get ingress eks-addons-unified-ingress

# Get ALB DNS
kubectl get ingress eks-addons-unified-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Check ALB rules
aws elbv2 describe-rules --region ap-south-1 --listener-arn $(aws elbv2 describe-listeners --region ap-south-1 --load-balancer-arn $(aws elbv2 describe-load-balancers --region ap-south-1 --query 'LoadBalancers[?contains(DNSName, `k8s-default-eksaddonsunified`)] | [0].LoadBalancerArn' --output text) --query 'Listeners[0].ListenerArn' --output text)
```

## Testing

### Test IRSA Deployment

```bash
# Test with curl
curl -H "Host: nginx-irsa-secrets.example.com" http://$ALB_DNS

# Or with proper DNS
curl http://nginx-irsa-secrets.example.com
```

### Test Pod Identity Deployment

```bash
# Test with curl
curl -H "Host: secrets-csi-test.example.com" http://$ALB_DNS

# Or with proper DNS
curl http://secrets-csi-test.example.com
```

## Troubleshooting

### Common Issues

#### 1. 404 Errors

**Problem**: Getting 404 when accessing via domain name.

**Solution**: ALB uses host-based routing. Test with:
```bash
curl -H "Host: nginx-irsa-secrets.example.com" http://$ALB_DNS
```

#### 2. Service Not Found

**Problem**: `Error from server (NotFound): services "nginx-irsa-deployment" not found`

**Solution**: Ensure services are created and match the ingress backend configuration.

#### 3. Target Group Unhealthy

**Problem**: ALB target group shows unhealthy targets.

**Solution**: Check pod health and service selectors:
```bash
kubectl get pods -l app=nginx-irsa
kubectl describe service nginx-irsa-deployment
```

### Debugging Commands

```bash
# Check ingress events
kubectl describe ingress eks-addons-unified-ingress

# Check ALB status
aws elbv2 describe-load-balancers --region ap-south-1 --query 'LoadBalancers[?contains(DNSName, `k8s-default-eksaddonsunified`)]'

# Check target health
aws elbv2 describe-target-health --region ap-south-1 --target-group-arn $(aws elbv2 describe-target-groups --region ap-south-1 --query 'TargetGroups[?contains(TargetGroupName, `k8s-default-eksaddonsunified`)] | [0].TargetGroupArn' --output text)

# Check listener rules
aws elbv2 describe-rules --region ap-south-1 --listener-arn $(aws elbv2 describe-listeners --region ap-south-1 --load-balancer-arn $(aws elbv2 describe-load-balancers --region ap-south-1 --query 'LoadBalancers[?contains(DNSName, `k8s-default-eksaddonsunified`)] | [0].LoadBalancerArn' --output text) --query 'Listeners[0].ListenerArn' --output text)
```

## Security Considerations

### HTTPS Configuration

For production, enable HTTPS:

```yaml
annotations:
  alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
  alb.ingress.kubernetes.io/ssl-redirect: '443'
  alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/certificate-id
```

### Network Security

- ALB security group allows port 80/443 from 0.0.0.0/0
- Pod security groups restrict traffic to ALB only
- Use internal ALBs for private services

## Performance Tuning

### Health Checks

```yaml
annotations:
  alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
  alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
  alb.ingress.kubernetes.io/healthy-threshold-count: '2'
  alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
```

### Connection Draining

```yaml
annotations:
  alb.ingress.kubernetes.io/target-group-attributes: deregistration_delay.timeout_seconds=30
```

## Cleanup

```bash
# Delete ingress
kubectl delete ingress eks-addons-unified-ingress

# Delete applications
cd eks-addons-testing/secrets-csi-driver
./cleanup.sh

# Remove DNS records (if created)
aws route53 change-resource-record-sets --hosted-zone-id YOUR_ZONE --change-batch '{"Changes":[{"Action":"DELETE","ResourceRecordSet":{"Name":"nginx-irsa-secrets.example.com","Type":"CNAME","TTL":300,"ResourceRecords":[{"Value":"'$ALB_DNS'"}]}}]}'
```

## Related Files

- `unified-alb-ingress.yaml` - Main ingress configuration
- `secrets-csi-driver/README.md` - Application deployment guide
- `alb-test.yaml` - Alternative single-service ingress
- `README-Ingress.md` - Troubleshooting guide
