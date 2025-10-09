#!/bin/bash

# Setup Local DNS for EKS Addons Testing
# This script adds hostname entries to /etc/hosts for testing the unified ALB ingress

set -e

ALB_ENDPOINT="k8s-default-eksaddon-e290e07746-386402444.ap-south-1.elb.amazonaws.com"
ALB_IP="65.2.19.156"

echo "========================================="
echo "EKS Addons Testing - Local DNS Setup"
echo "========================================="
echo ""
echo "ALB Endpoint: $ALB_ENDPOINT"
echo "ALB IP: $ALB_IP"
echo ""

# Check if entries already exist
if grep -q "ebs-csi.example.com" /etc/hosts 2>/dev/null; then
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
    sudo sed -i.bak '/EKS Addons Testing/,+3d' /etc/hosts
fi

# Add new entries
echo "Adding entries to /etc/hosts..."
sudo bash -c "cat >> /etc/hosts <<EOF

# EKS Addons Testing - Unified ALB
$ALB_IP ebs-csi.example.com
$ALB_IP secrets-csi.example.com
$ALB_IP pod-identity.example.com
EOF"

echo ""
echo "✅ Successfully added entries to /etc/hosts"
echo ""
echo "You can now access:"
echo "  - http://ebs-csi.example.com"
echo "  - http://secrets-csi.example.com"
echo "  - http://pod-identity.example.com"
echo ""
echo "To remove these entries later, run:"
echo "  sudo sed -i.bak '/EKS Addons Testing/,+3d' /etc/hosts"
echo ""
