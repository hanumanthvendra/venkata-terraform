# EKS Addons Testing Guide - Unified ALB with Hostname-Based Routing

## Overview

This guide explains how to test the unified ALB ingress with hostname-based routing for three EKS addons:
- **EBS CSI Driver** - `ebs-csi.example.com`
- **Secrets CSI Driver** - `secrets-csi.example.com`
- **Pod Identity** - `pod-identity.example.com`

## Prerequisites

- EKS cluster with Auto Mode enabled
- ALB Controller installed
- kubectl configured
- All three test applications deployed

## Step 1: Get ALB Endpoint

```bash
ALB_ENDPOINT=$(kubectl get ingress eks-addons-unified-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ALB Endpoint: $ALB_ENDPOINT"
```

**Current ALB Endpoint:**
```
k8s-default-eksaddon-e290e07746-386402444.ap-south-1.elb.amazonaws.com
```

## Step 2: Configure Local DNS (/etc/hosts)

### For macOS/Linux:

```bash
# Get ALB IP address
ALB_IP=$(dig +short $ALB_ENDPOINT | head -1)
echo "ALB IP: $ALB_IP"

# Add entries to /etc/hosts (requires sudo)
sudo bash -c "cat >> /etc/hosts <<EOF

# EKS Addons Testing - Unified ALB
$ALB_IP ebs-csi.example.com
$ALB_IP secrets-csi.example.com
$ALB_IP pod-identity.example.com
EOF"
```

### For Windows:

1. Open Notepad as Administrator
2. Open file: `C:\Windows\System32\drivers\etc\hosts`
3. Add these lines (replace `<ALB_IP>` with actual IP):

```
# EKS Addons Testing - Unified ALB
<ALB_IP> ebs-csi.example.com
<ALB_IP> secrets-csi.example.com
<ALB_IP> pod-identity.example.com
```

### Alternative: Use curl with Host header (no /etc/hosts needed)

```bash
# Test EBS CSI
curl -H "Host: ebs-csi.example.com" http://$ALB_ENDPOINT

# Test Secrets CSI
curl -H "Host: secrets-csi.example.com" http://$ALB_ENDPOINT

# Test Pod Identity
curl -H "Host: pod-identity.example.com" http://$ALB_ENDPOINT
```

## Step 3: Test in Browser

After configuring /etc/hosts, open your browser and visit:

### 1. EBS CSI Driver Test
**URL:** http://ebs-csi.example.com

**Expected Output:**
- ✅ Shows "EBS CSI Driver Test" heading
- ✅ Displays pod name
- ✅ Shows timestamp
- ✅ Lists files in mounted EBS volume
- ✅ Shows persistent storage is working

### 2. Pod Identity Test
**URL:** http://pod-identity.example.com

**Expected Output:**
- ✅ Shows "EKS Pod Identity Test" heading
- ✅ Displays AWS STS caller identity
- ✅ Shows assumed IAM role ARN
- ✅ Confirms Pod Identity is working
- ✅ AWS CLI version displayed

### 3. Secrets CSI Driver Test
**URL:** http://secrets-csi.example.com

**Expected Output (after fixing IAM permissions):**
- ✅ Shows "Secrets CSI Driver Test" heading
- ✅ Displays secret content from AWS Secrets Manager
- ✅ Lists files in secrets mount
- ✅ Confirms Secrets CSI Driver is working

**Note:** If Secrets CSI test fails, see `SECRETS-CSI-FIX.md` for IAM permissions fix.

## Step 4: Verify All Pods are Running

```bash
# Check all test pods
kubectl get pods -n default | grep -E "(ebs-csi|secrets-csi|pod-identity)"

# Expected output:
# ebs-csi-test-app-xxxxx         1/1     Running   0          Xh
# pod-identity-test-app-xxxxx    1/1     Running   0          Xh
# secrets-csi-test-app-xxxxx     1/1     Running   0          Xh  (after IAM fix)
```

## Step 5: Verify Ingress Configuration

```bash
# Check ingress details
kubectl describe ingress eks-addons-unified-ingress -n default

# Verify hostname rules
kubectl get ingress eks-addons-unified-ingress -n default -o yaml | grep -A 5 "host:"
```

## Troubleshooting

### Issue: "Connection refused" or "Cannot connect"

**Solution:**
1. Verify ALB is provisioned:
   ```bash
   kubectl get ingress eks-addons-unified-ingress -n default
   ```
2. Check ALB health in AWS Console
3. Verify security groups allow HTTP (port 80)

### Issue: "404 Not Found"

**Solution:**
1. Verify /etc/hosts configuration
2. Check that you're using the correct hostname
3. Verify services are running:
   ```bash
   kubectl get svc -n default | grep -E "(ebs-csi|secrets-csi|pod-identity)"
   ```

### Issue: Secrets CSI pod not starting

**Solution:**
See `SECRETS-CSI-FIX.md` for IAM permissions configuration.

### Issue: Browser shows wrong content

**Solution:**
1. Clear browser cache
2. Try incognito/private mode
3. Verify /etc/hosts has correct IP
4. Check ALB target health in AWS Console

## Cleanup /etc/hosts (Optional)

When done testing, remove the entries from /etc/hosts:

### macOS/Linux:
```bash
sudo sed -i.bak '/EKS Addons Testing/,+3d' /etc/hosts
```

### Windows:
Manually remove the lines from `C:\Windows\System32\drivers\etc\hosts`

## Architecture Benefits

✅ **Cost Savings:** Single ALB instead of 3 separate ALBs (~$33/month savings)
✅ **Better Organization:** Professional hostname-based routing
✅ **Simplified Management:** One ingress resource to maintain
✅ **Production-Ready:** Follows AWS best practices
✅ **Scalable:** Easy to add more test applications

## Next Steps

1. Fix Secrets CSI IAM permissions (see SECRETS-CSI-FIX.md)
2. Test all three endpoints in browser
3. Verify persistent storage with EBS CSI
4. Verify Pod Identity with AWS CLI
5. Verify Secrets CSI with AWS Secrets Manager

## Support

For issues or questions, refer to:
- `README.md` - Quick start guide
- `CHANGES-SUMMARY.md` - What changed
- `SECRETS-CSI-FIX.md` - IAM permissions fix
- `EKS-Addons-Testing-Guide.md` - Detailed testing guide
