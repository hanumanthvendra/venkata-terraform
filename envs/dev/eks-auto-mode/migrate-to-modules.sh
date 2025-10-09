#!/bin/bash

################################################################################
# EKS Auto Mode State Migration Script
# This script migrates resources from monolithic to modular structure
################################################################################

set -e  # Exit on error

echo "=========================================="
echo "EKS Auto Mode State Migration Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "main.tf" ] || [ ! -f "backend.hcl" ]; then
    print_error "Please run this script from the eks-auto-mode directory"
    exit 1
fi

# Step 1: Backup current state
print_info "Step 1: Backing up current state..."
terraform state pull > terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)
print_info "State backup created"

# Step 2: Initialize with new configuration
print_info "Step 2: Initializing Terraform with new module structure..."
terraform init -upgrade

# Step 3: List current resources
print_info "Step 3: Listing current resources..."
terraform state list > current_resources.txt
print_info "Current resources saved to current_resources.txt"

# Step 4: Move resources to modules
print_info "Step 4: Moving resources to module structure..."

# Move EKS module
print_info "Moving EKS cluster resources..."
if terraform state list | grep -q "^module.eks."; then
    terraform state mv 'module.eks' 'module.eks_auto_mode.module.eks' || print_warning "EKS module move failed or already moved"
else
    print_warning "EKS module not found in state"
fi

# Move ALB Controller resources
print_info "Moving ALB Controller resources..."
if terraform state list | grep -q "aws_iam_role.aws_load_balancer_controller"; then
    terraform state mv 'aws_iam_role.aws_load_balancer_controller' 'module.eks_auto_mode.module.alb_controller.aws_iam_role.this' || print_warning "ALB role move failed"
    terraform state mv 'aws_iam_policy.aws_load_balancer_controller' 'module.eks_auto_mode.module.alb_controller.aws_iam_policy.this' || print_warning "ALB policy move failed"
    terraform state mv 'aws_iam_role_policy_attachment.aws_load_balancer_controller' 'module.eks_auto_mode.module.alb_controller.aws_iam_role_policy_attachment.this' || print_warning "ALB attachment move failed"
    terraform state mv 'null_resource.install_alb_controller' 'module.eks_auto_mode.module.alb_controller.null_resource.install[0]' || print_warning "ALB null resource move failed"
else
    print_warning "ALB Controller resources not found in state"
fi

# Move EBS CSI Driver resources
print_info "Moving EBS CSI Driver resources..."
if terraform state list | grep -q "aws_iam_role.ebs_csi_driver"; then
    terraform state mv 'aws_iam_role.ebs_csi_driver' 'module.eks_auto_mode.module.ebs_csi_driver.aws_iam_role.this' || print_warning "EBS role move failed"
    terraform state mv 'aws_iam_policy.ebs_csi_driver' 'module.eks_auto_mode.module.ebs_csi_driver.aws_iam_policy.this' || print_warning "EBS policy move failed"
    terraform state mv 'aws_iam_role_policy_attachment.ebs_csi_driver' 'module.eks_auto_mode.module.ebs_csi_driver.aws_iam_role_policy_attachment.this' || print_warning "EBS attachment move failed"
    terraform state mv 'null_resource.annotate_ebs_csi_driver_sa' 'module.eks_auto_mode.module.ebs_csi_driver.null_resource.annotate_service_account[0]' || print_warning "EBS null resource move failed"
else
    print_warning "EBS CSI Driver resources not found in state"
fi

# Move Secrets CSI Driver resources
print_info "Moving Secrets CSI Driver resources..."
if terraform state list | grep -q "aws_iam_role.secrets_store_csi_driver"; then
    terraform state mv 'aws_iam_role.secrets_store_csi_driver' 'module.eks_auto_mode.module.secrets_csi_driver.aws_iam_role.this' || print_warning "Secrets role move failed"
    terraform state mv 'aws_iam_policy.secrets_store_csi_driver' 'module.eks_auto_mode.module.secrets_csi_driver.aws_iam_policy.this' || print_warning "Secrets policy move failed"
    terraform state mv 'aws_iam_role_policy_attachment.secrets_store_csi_driver' 'module.eks_auto_mode.module.secrets_csi_driver.aws_iam_role_policy_attachment.this' || print_warning "Secrets attachment move failed"
    terraform state mv 'kubernetes_service_account.secrets_sa' 'module.eks_auto_mode.module.secrets_csi_driver.kubernetes_service_account.this[0]' || print_warning "Secrets SA move failed"
    terraform state mv 'aws_eks_pod_identity_association.secrets' 'module.eks_auto_mode.module.secrets_csi_driver.aws_eks_pod_identity_association.this[0]' || print_warning "Secrets pod identity move failed"
else
    print_warning "Secrets CSI Driver resources not found in state"
fi

# Step 5: Verify migration
print_info "Step 5: Verifying migration..."
terraform state list > migrated_resources.txt
print_info "Migrated resources saved to migrated_resources.txt"

# Step 6: Run terraform plan
print_info "Step 6: Running terraform plan to verify..."
echo ""
echo "=========================================="
echo "Running terraform plan..."
echo "=========================================="
echo ""

if terraform plan -detailed-exitcode; then
    print_info "✓ Migration successful! No changes detected."
    echo ""
    print_info "Your infrastructure has been successfully migrated to the modular structure."
    print_info "All resources are preserved and no changes will be applied."
else
    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 2 ]; then
        print_warning "⚠ Migration completed but terraform plan shows changes."
        print_warning "Please review the plan output above."
        print_warning "You may need to manually adjust some state moves."
        echo ""
        print_info "Common issues:"
        print_info "1. Check if addon versions need to be specified"
        print_info "2. Verify all resources were moved correctly"
        print_info "3. Review the MIGRATION-GUIDE.md for troubleshooting"
    else
        print_error "✗ Terraform plan failed with exit code $EXIT_CODE"
        print_error "Please review the errors above and consult MIGRATION-GUIDE.md"
        exit $EXIT_CODE
    fi
fi

echo ""
echo "=========================================="
echo "Migration Complete!"
echo "=========================================="
echo ""
print_info "Next steps:"
echo "  1. Review the terraform plan output above"
echo "  2. If satisfied, you can apply any addon version updates"
echo "  3. Refer to MIGRATION-GUIDE.md for more information"
echo ""
print_info "Backup files created:"
echo "  - terraform.tfstate.backup.*"
echo "  - current_resources.txt"
echo "  - migrated_resources.txt"
echo ""
