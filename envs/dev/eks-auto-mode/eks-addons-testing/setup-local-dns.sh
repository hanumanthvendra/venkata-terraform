#!/bin/bash

# Setup Local DNS for EKS Addons Testing
# This script adds hostname entries to /etc/hosts for testing the unified ALB ingress

set -e

echo "========================================="
echo "EKS Addons Testing - Local DNS Setup"
echo "========================================="
echo ""

# Get ALB DNS name dynamically
echo "Getting ALB DNS name..."
ALB_DNS=$(kubectl get ingress eks-addons-unified-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ -z "$ALB_DNS" ]; then
    echo "❌ Could not find ALB DNS name. Make sure the ingress is deployed:"
    echo "   kubectl apply -f unified-alb-ingress.yaml"
    exit 1
fi

echo "ALB DNS: $ALB_DNS"
echo ""

# Get ALB IP (optional, for direct IP access)
ALB_IP=$(dig +short $ALB_DNS | head -1)
if [ -n "$ALB_IP" ]; then
    echo "ALB IP: $ALB_IP"
    echo ""
fi

# Check if entries already exist
if grep -q "example.com" /etc/hosts 2>/dev/null; then
    echo "⚠️  Entries already exist in /etc/hosts"
    echo ""
    echo "Current entries:"
    grep "example.com" /etc/hosts
    echo ""
    read -p "Do you want to update them? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping update."
        exit 0
    fi

    # Remove old entries
    echo "Removing old entries..."
    sudo sed -i.bak '/EKS Addons Testing/,+5d' /etc/hosts
fi

# Add new entries
echo "Adding entries to /etc/hosts..."
sudo bash -c "cat >> /etc/hosts <<EOF

# EKS Addons Testing - Unified ALB
$ALB_DNS nginx-irsa-secrets.example.com
$ALB_DNS secrets-csi-test.example.com
$ALB_DNS ebs-csi.example.com
$ALB_DNS pod-identity.example.com
EOF"

echo ""
echo "✅ Successfully added entries to /etc/hosts"
echo ""
echo "You can now access:"
echo "  - http://nginx-irsa-secrets.example.com"
echo "  - http://secrets-csi-test.example.com"
echo "  - http://ebs-csi.example.com"
echo "  - http://pod-identity.example.com"
echo ""
echo "To remove these entries later, run:"
echo "  sudo sed -i.bak '/EKS Addons Testing/,+5d' /etc/hosts"
echo ""
echo "Note: If you get SSL certificate errors, use HTTP instead of HTTPS"
echo "      since we're using self-signed certificates for testing."
