#!/bin/bash

# EKS Addons Testing - Unified Deployment Script
# This script deploys all three test applications with a single unified ALB ingress

set -e

echo "=========================================="
echo "EKS Addons Testing - Unified Deployment"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check cluster connectivity
echo "Checking cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi
print_status "Connected to cluster"
echo ""

# Step 1: Deploy Service Account
echo "Step 1: Deploying Service Account for Pod Identity..."
kubectl apply -f service-account.yaml
print_status "Service account deployed"
echo ""

# Step 2: Deploy EBS CSI Driver Test
echo "Step 2: Deploying EBS CSI Driver Test..."
kubectl apply -f ebs-csi-driver/deployment.yaml
print_status "EBS CSI Driver test deployed"
echo ""

# Step 3: Deploy Secrets CSI Driver Test
echo "Step 3: Deploying Secrets CSI Driver Test..."
kubectl apply -f secrets-csi-driver/deployment.yaml
print_status "Secrets CSI Driver test deployed"
echo ""

# Step 4: Deploy Pod Identity Test
echo "Step 4: Deploying Pod Identity Test..."
kubectl apply -f pod-identity/deployment.yaml
print_status "Pod Identity test deployed"
echo ""

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
echo "  - Waiting for EBS CSI test pod..."
kubectl wait --for=condition=ready pod -l app=ebs-csi-test --timeout=120s || print_warning "EBS CSI test pod not ready yet"

echo "  - Waiting for Secrets CSI test pod..."
kubectl wait --for=condition=ready pod -l app=secrets-csi-test --timeout=120s || print_warning "Secrets CSI test pod not ready yet"

echo "  - Waiting for Pod Identity test pod..."
kubectl wait --for=condition=ready pod -l app=pod-identity-test --timeout=120s || print_warning "Pod Identity test pod not ready yet"

print_status "All pods are ready"
echo ""

# Step 5: Deploy Unified ALB Ingress
echo "Step 5: Deploying Unified ALB Ingress..."
kubectl apply -f unified-alb-ingress.yaml
print_status "Unified ALB Ingress deployed"
echo ""

# Wait for ingress to get an address
echo "Waiting for ALB to be provisioned (this may take 2-3 minutes)..."
for i in {1..60}; do
    ALB_ADDRESS=$(kubectl get ingress eks-addons-unified-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$ALB_ADDRESS" ]; then
        break
    fi
    echo -n "."
    sleep 5
done
echo ""

if [ -z "$ALB_ADDRESS" ]; then
    print_warning "ALB address not available yet. Run 'kubectl get ingress eks-addons-unified-ingress' to check status."
else
    print_status "ALB provisioned successfully!"
    echo ""
    echo "=========================================="
    echo "Deployment Complete!"
    echo "=========================================="
    echo ""
    echo "ALB Endpoint: $ALB_ADDRESS"
    echo ""
    echo "Test URLs (use with Host header or /etc/hosts):"
    echo "  1. EBS CSI Driver Test:"
    echo "     curl -H 'Host: ebs-csi.example.com' http://$ALB_ADDRESS"
    echo ""
    echo "  2. Secrets CSI Driver Test:"
    echo "     curl -H 'Host: secrets-csi.example.com' http://$ALB_ADDRESS"
    echo ""
    echo "  3. Pod Identity Test:"
    echo "     curl -H 'Host: pod-identity.example.com' http://$ALB_ADDRESS"
    echo ""
    echo "Or add to /etc/hosts (requires sudo):"
    echo "  sudo sh -c \"echo '$ALB_ADDRESS ebs-csi.example.com secrets-csi.example.com pod-identity.example.com' >> /etc/hosts\""
    echo ""
    echo "Then access via browser:"
    echo "  - http://ebs-csi.example.com"
    echo "  - http://secrets-csi.example.com"
    echo "  - http://pod-identity.example.com"
    echo ""
fi

# Show deployment status
echo "Deployment Status:"
echo "===================="
kubectl get pods -l 'app in (ebs-csi-test,secrets-csi-test,pod-identity-test)'
echo ""
kubectl get svc -l 'app in (ebs-csi-test,secrets-csi-test,pod-identity-test)'
echo ""
kubectl get ingress eks-addons-unified-ingress
echo ""

print_status "All resources deployed successfully!"
