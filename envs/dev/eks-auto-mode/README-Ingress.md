# EKS Ingress Controller Troubleshooting Guide

## Overview

This document details the comprehensive debugging process and resolution for ingress controller issues in the EKS Auto Mode cluster. It serves as a reference for future troubleshooting and best practices.

## Initial Problem

**Issue**: Ingress controller returning HTTP 404 errors when accessing applications through the Application Load Balancer (ALB).

**Symptoms**:
- ALB DNS accessible but returning 404
- Backend pods and services working correctly
- No obvious errors in Kubernetes events

## Root Cause Analysis

### 1. Host Header Mismatch

**Problem**: The ingress resource was configured with a host-based rule (`test.example.com`) but requests to the ALB were not including the matching Host header.

**Evidence**:
- Direct ALB access: `curl http://alb-dns/` → 404
- With correct Host header: `curl -H "Host: test.example.com" http://alb-dns/` → 200 OK

**Why this happens**:
- ALB rules are host-specific by default
- When accessing ALB directly via IP/DNS without proper Host header, the rule doesn't match
- ALB falls back to default action (fixed-response 404)

### 2. Ingress Configuration Issues

**Deprecated Annotation Format**:
```yaml
# ❌ Old format (deprecated)
annotations:
  kubernetes.io/ingress.class: alb
```

**Modern Format**:
```yaml
# ✅ Correct format
spec:
  ingressClassName: alb
```

### 3. IPv6 Subnet Configuration

**Warning**: "must specify subnets with IPv6 CIDR block" when using dualstack configuration.

## Debugging Steps Performed

### Step 1: Verify Backend Health
```bash
# Check pod status
kubectl get pods -o wide

# Test direct pod access
kubectl run test-curl --image=curlimages/curl --rm -it --restart=Never -- curl -I http://10.0.25.212

# Verify service configuration
kubectl get svc nginx-alb-test
kubectl get endpoints nginx-alb-test
```

**Results**: ✅ Pods healthy, service routing correctly

### Step 2: Check ALB Status
```bash
# Get ALB DNS
kubectl get ing nginx-alb-test-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Check ALB state
aws elbv2 describe-load-balancers --region ap-south-1 --query 'LoadBalancers[?contains(DNSName, `nginxalb`)].{Name:LoadBalancerName,DNS:DNSName,State:State}'
```

**Results**: ✅ ALB in "active" state

### Step 3: Verify Target Group Health
```bash
# Check target group configuration
aws elbv2 describe-target-groups --region ap-south-1 --query 'TargetGroups[?contains(TargetGroupName, `nginxalb`)]'

# Verify target health
aws elbv2 describe-target-health --region ap-south-1 --target-group-arn <target-group-arn>
```

**Results**: ✅ Both targets healthy (State: healthy)

### Step 4: Examine ALB Listener Configuration
```bash
# Get load balancer ARN
aws elbv2 describe-load-balancers --region ap-south-1 --query 'LoadBalancers[?contains(DNSName, `nginxalb`)].LoadBalancerArn'

# Check listener configuration
aws elbv2 describe-listeners --region ap-south-1 --load-balancer-arn <lb-arn>

# Check rules
aws elbv2 describe-rules --region ap-south-1 --listener-arn <listener-arn>
```

**Results**: ✅ Listener on port 80, but default action was "fixed-response" 404

### Step 5: Security Group Verification
```bash
# Get ALB security groups
aws elbv2 describe-load-balancers --region ap-south-1 --query 'LoadBalancers[?contains(DNSName, `nginxalb`)].SecurityGroups'

# Check security group rules
aws ec2 describe-security-groups --region ap-south-1 --group-ids <sg-ids>
```

**Results**: ✅ Port 80 allowed from 0.0.0.0/0

## Resolution

### Immediate Fix (Testing)
```bash
# Test with correct Host header
ALB=$(kubectl get ing nginx-alb-test-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -I -H "Host: test.example.com" http://$ALB/
```

**Result**: ✅ HTTP/1.1 200 OK, Server: nginx/1.21.6

### Production Setup Options

#### Option A: DNS Configuration (Recommended)
1. Create Route53 CNAME record:
   ```
   test.example.com → k8s-default-nginxalb-251fbc5858-548156657.ap-south-1.elb.amazonaws.com
   ```
2. Access via: `http://test.example.com`

#### Option B: Remove Host Requirement (Testing Only)
```bash
kubectl patch ingress nginx-alb-test-ingress \
  --type=json \
  -p='[{"op":"remove","path":"/spec/rules/0/host"}]'
```

## Best Practices

### 1. Ingress Configuration
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
  ingressClassName: alb  # ✅ Use modern format
  rules:
  - host: test.example.com  # ✅ Specify host for production
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

### 2. Testing Strategy
1. **Always test with correct Host header** when using host-based routing
2. **Verify backend health** before troubleshooting ALB
3. **Check ALB state and target health** using AWS CLI
4. **Examine listener rules** to understand routing logic

### 3. Common Pitfalls to Avoid
- ❌ Using deprecated `kubernetes.io/ingress.class` annotation
- ❌ Accessing ALB without proper Host header
- ❌ Not verifying target group health
- ❌ Ignoring security group configurations

## Troubleshooting Commands Reference

### Kubernetes Resources
```bash
# Check ingress status
kubectl describe ingress <ingress-name>

# Get ALB DNS
kubectl get ing <ingress-name> -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp
```

### AWS Load Balancer
```bash
# List ALBs
aws elbv2 describe-load-balancers --region ap-south-1

# Check target health
aws elbv2 describe-target-health --region ap-south-1 --target-group-arn <arn>

# Describe listeners
aws elbv2 describe-listeners --region ap-south-1 --load-balancer-arn <arn>

# Describe rules
aws elbv2 describe-rules --region ap-south-1 --listener-arn <arn>
```

### Security Groups
```bash
# Describe security groups
aws ec2 describe-security-groups --region ap-south-1 --group-ids <sg-ids>

# Check subnet tags
aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/role/elb,Values=1"
```

## IPv6 Configuration Fix

If you encounter "must specify subnets with IPv6 CIDR block" errors:

### Option 1: Force IPv4 Only
Add to your ingress annotations:
```yaml
alb.ingress.kubernetes.io/ip-address-type: ipv4
```

### Option 2: Enable IPv6 on Subnets
```bash
# Associate IPv6 CIDR with subnets
aws ec2 associate-subnet-cidr-block --subnet-id <subnet-id> --ipv6-cidr-block <ipv6-cidr>
```

## Conclusion

The ingress controller was working correctly throughout the debugging process. The 404 errors were due to host header mismatch, which is expected behavior for host-based routing. The resolution involved proper testing with correct Host headers and understanding ALB rule matching logic.

**Key Takeaway**: Always test ingress resources with the appropriate Host header that matches the configured rules, and verify both Kubernetes and AWS ALB configurations when troubleshooting connectivity issues.

## Related Files
- `alb-test.yaml` - Main ingress configuration
- `main.tf` - ALB controller installation
- `README.md` - General EKS Auto Mode documentation
