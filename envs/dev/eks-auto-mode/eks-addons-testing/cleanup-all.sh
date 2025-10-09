#!/bin/bash

# EKS Addons Testing - Cleanup Script
# This script removes all test resources in the correct order

set -e

echo "=========================================="
echo "EKS Addons Testing - Cleanup"
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

# Confirm deletion
read -p "Are you sure you want to delete all EKS addons test resources? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi
echo ""

# Step 1: Delete Unified ALB Ingress (to avoid orphaned ALBs)
echo "Step 1: Deleting Unified ALB Ingress..."
if kubectl get ingress eks-addons-unified-ingress &> /dev/null; then
    kubectl delete -f unified-alb-ingress.yaml
    print_status "Unified ALB Ingress deleted"
    echo "Waiting for ALB to be deprovisioned (30 seconds)..."
    sleep 30
else
    print_warning "Unified ALB Ingress not found"
fi
echo ""

# Step 2: Delete Pod Identity Test
echo "Step 2: Deleting Pod Identity Test..."
if kubectl get deployment pod-identity-test-app &> /dev/null; then
    kubectl delete -f pod-identity/deployment.yaml
    print_status "Pod Identity test deleted"
else
    print_warning "Pod Identity test not found"
fi
echo ""

# Step 3: Delete Secrets CSI Driver Test
echo "Step 3: Deleting Secrets CSI Driver Test..."
if kubectl get deployment secrets-csi-test-app &> /dev/null; then
    kubectl delete -f secrets-csi-driver/deployment.yaml
    print_status "Secrets CSI Driver test deleted"
else
    print_warning "Secrets CSI Driver test not found"
fi
echo ""

# Step 4: Delete EBS CSI Driver Test
echo "Step 4: Deleting EBS CSI Driver Test..."
if kubectl get deployment ebs-csi-test-app &> /dev/null; then
    kubectl delete -f ebs-csi-driver/deployment.yaml
    print_status "EBS CSI Driver test deleted"
else
    print_warning "EBS CSI Driver test not found"
fi
echo ""

# Step 5: Delete Service Account (optional - keep if used by other apps)
echo "Step 5: Deleting Service Account..."
read -p "Do you want to delete the service account 'secrets-sa'? (yes/no): " delete_sa
if [ "$delete_sa" = "yes" ]; then
    if kubectl get serviceaccount secrets-sa &> /dev/null; then
        kubectl delete -f service-account.yaml
        print_status "Service account deleted"
    else
        print_warning "Service account not found"
    fi
else
    print_warning "Service account kept (may be used by other applications)"
fi
echo ""

# Verify cleanup
echo "Verifying cleanup..."
REMAINING_PODS=$(kubectl get pods -l 'app in (ebs-csi-test,secrets-csi-test,pod-identity-test)' --no-headers 2>/dev/null | wc -l)
REMAINING_SERVICES=$(kubectl get svc -l 'app in (ebs-csi-test,secrets-csi-test,pod-identity-test)' --no-headers 2>/dev/null | wc -l)
REMAINING_INGRESS=$(kubectl get ingress eks-addons-unified-ingress --no-headers 2>/dev/null | wc -l)

if [ "$REMAINING_PODS" -eq 0 ] && [ "$REMAINING_SERVICES" -eq 0 ] && [ "$REMAINING_INGRESS" -eq 0 ]; then
    print_status "All resources cleaned up successfully!"
else
    print_warning "Some resources may still be terminating:"
    if [ "$REMAINING_PODS" -gt 0 ]; then
        echo "  - Pods: $REMAINING_PODS"
        kubectl get pods -l 'app in (ebs-csi-test,secrets-csi-test,pod-identity-test)'
    fi
    if [ "$REMAINING_SERVICES" -gt 0 ]; then
        echo "  - Services: $REMAINING_SERVICES"
        kubectl get svc -l 'app in (ebs-csi-test,secrets-csi-test,pod-identity-test)'
    fi
    if [ "$REMAINING_INGRESS" -gt 0 ]; then
        echo "  - Ingress: $REMAINING_INGRESS"
        kubectl get ingress eks-addons-unified-ingress
    fi
fi
echo ""

# Check for PVCs (EBS volumes)
echo "Checking for persistent volumes..."
PVC_COUNT=$(kubectl get pvc ebs-test-pvc --no-headers 2>/dev/null | wc -l)
if [ "$PVC_COUNT" -gt 0 ]; then
    print_warning "PVC 'ebs-test-pvc' still exists (EBS volume may incur costs)"
    echo "To delete: kubectl delete pvc ebs-test-pvc"
else
    print_status "No persistent volumes found"
fi
echo ""

echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""
echo "Note: If you created AWS Secrets Manager secrets, delete them manually:"
echo "  aws secretsmanager delete-secret --secret-id test-secret --force-delete-without-recovery --region <region>"
echo ""
