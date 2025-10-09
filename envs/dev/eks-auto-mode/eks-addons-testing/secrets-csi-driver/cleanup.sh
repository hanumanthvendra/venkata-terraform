#!/bin/bash

# Secrets CSI Driver Cleanup Script
# Usage: ./cleanup.sh [irsa|pod-identity|all]

set -e

METHOD=${1:-all}

echo "=========================================="
echo "AWS Secrets Manager CSI Driver Cleanup"
echo "=========================================="
echo ""

cleanup_irsa() {
  echo "Cleaning up IRSA deployment..."
  kubectl delete -f deployment.yaml --ignore-not-found=true
  kubectl delete -f service-account-irsa.yaml --ignore-not-found=true
  echo "✅ IRSA deployment cleaned up"
}

cleanup_pod_identity() {
  echo "Cleaning up Pod Identity deployment..."
  kubectl delete -f deployment-pod-identity.yaml --ignore-not-found=true
  kubectl delete -f service-account-pod-identity.yaml --ignore-not-found=true
  echo "✅ Pod Identity deployment cleaned up"
}

case $METHOD in
  irsa)
    cleanup_irsa
    ;;
    
  pod-identity)
    cleanup_pod_identity
    ;;
    
  all)
    echo "Cleaning up all deployments..."
    echo ""
    cleanup_irsa
    echo ""
    cleanup_pod_identity
    ;;
    
  *)
    echo "❌ Invalid method: $METHOD"
    echo ""
    echo "Usage: ./cleanup.sh [irsa|pod-identity|all]"
    echo ""
    echo "Methods:"
    echo "  irsa         - Cleanup IRSA deployment"
    echo "  pod-identity - Cleanup Pod Identity deployment"
    echo "  all          - Cleanup all deployments (default)"
    exit 1
    ;;
esac

echo ""
echo "Cleanup completed!"
