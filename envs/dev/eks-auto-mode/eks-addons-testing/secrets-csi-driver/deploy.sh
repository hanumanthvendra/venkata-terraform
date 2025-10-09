#!/bin/bash

# Secrets CSI Driver Deployment Script
# Usage: ./deploy.sh [irsa|pod-identity]

set -e

METHOD=${1:-irsa}

echo "=========================================="
echo "AWS Secrets Manager CSI Driver Deployment"
echo "=========================================="
echo ""

case $METHOD in
  irsa)
    echo "Deploying with IRSA (IAM Roles for Service Accounts)..."
    echo ""
    
    # Create service account
    echo "Creating service account..."
    kubectl apply -f service-account-irsa.yaml
    
    # Wait a moment for service account to be ready
    sleep 2
    
    # Deploy application
    echo "Deploying application..."
    kubectl apply -f deployment.yaml
    
    echo ""
    echo "✅ IRSA deployment completed!"
    echo ""
    echo "To verify:"
    echo "  kubectl get pods -l app=nginx-irsa"
    echo "  kubectl get svc nginx-irsa-deployment"
    echo ""
    echo "To test:"
    echo "  POD_NAME=\$(kubectl get pods -l app=nginx-irsa -o jsonpath='{.items[0].metadata.name}')"
    echo "  kubectl exec \$POD_NAME -- cat /mnt/secrets-store/test-secret"
    echo ""
    echo "To access via port-forward:"
    echo "  kubectl port-forward svc/nginx-irsa-deployment 8080:80"
    ;;
    
  pod-identity)
    echo "Deploying with Pod Identity..."
    echo ""
    
    # Create service account
    echo "Creating service account..."
    kubectl apply -f service-account-pod-identity.yaml
    
    # Wait a moment for service account to be ready
    sleep 2
    
    # Deploy application
    echo "Deploying application..."
    kubectl apply -f deployment-pod-identity.yaml
    
    echo ""
    echo "✅ Pod Identity deployment completed!"
    echo ""
    echo "To verify:"
    echo "  kubectl get pods -l app=nginx-pod-identity"
    echo "  kubectl get svc nginx-pod-identity-deployment"
    echo ""
    echo "To test:"
    echo "  POD_NAME=\$(kubectl get pods -l app=nginx-pod-identity -o jsonpath='{.items[0].metadata.name}')"
    echo "  kubectl exec \$POD_NAME -- cat /mnt/secrets-store/test-secret"
    echo ""
    echo "To access via port-forward:"
    echo "  kubectl port-forward svc/nginx-pod-identity-deployment 8081:80"
    ;;
    
  *)
    echo "❌ Invalid method: $METHOD"
    echo ""
    echo "Usage: ./deploy.sh [irsa|pod-identity]"
    echo ""
    echo "Methods:"
    echo "  irsa         - Deploy with IAM Roles for Service Accounts (recommended)"
    echo "  pod-identity - Deploy with Pod Identity"
    exit 1
    ;;
esac

echo ""
echo "Note: If pods fail to start, check IAM permissions:"
echo "  kubectl describe pod <pod-name>"
echo "  kubectl logs -n kube-system -l app=csi-secrets-store-provider-aws"
