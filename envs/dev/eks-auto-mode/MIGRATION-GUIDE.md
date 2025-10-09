# EKS Auto Mode Modularization Migration Guide

## Overview
This guide helps you migrate your existing EKS Auto Mode infrastructure from a monolithic configuration to a modular structure without recreating resources.

## What Changed?

### Before (Monolithic)
- All resources defined in a single `main.tf` (~600 lines)
- Direct resource definitions
- Hard to reuse and maintain

### After (Modular)
- Resources organized into reusable modules:
  - `modules/eks-auto-mode` - Main wrapper module
  - `modules/eks-addons/alb-controller` - ALB Controller
  - `modules/eks-addons/ebs-csi-driver` - EBS CSI Driver
  - `modules/eks-addons/secrets-csi-driver` - Secrets CSI Driver
- Clean separation of concerns
- Easier to maintain and reuse

## Migration Steps

### Step 1: Backup Current State
```bash
cd venkata-terraform/envs/dev/eks-auto-mode

# Backup the state file
terraform state pull > terraform.tfstate.backup

# Backup current configuration (already done)
# main.tf.backup exists
```

### Step 2: Initialize with New Configuration
```bash
# Initialize terraform with new module structure
terraform init -upgrade
```

### Step 3: Move Resources to Module State

The resources need to be moved from the root module to the new module structure. Here's the mapping:

#### EKS Cluster Resources (to module.eks_auto_mode.module.eks)
```bash
# Move EKS module resources
terraform state mv 'module.eks' 'module.eks_auto_mode.module.eks'
```

#### ALB Controller Resources (to module.eks_auto_mode.module.alb_controller)
```bash
terraform state mv 'aws_iam_role.aws_load_balancer_controller' 'module.eks_auto_mode.module.alb_controller.aws_iam_role.this'
terraform state mv 'aws_iam_policy.aws_load_balancer_controller' 'module.eks_auto_mode.module.alb_controller.aws_iam_policy.this'
terraform state mv 'aws_iam_role_policy_attachment.aws_load_balancer_controller' 'module.eks_auto_mode.module.alb_controller.aws_iam_role_policy_attachment.this'
terraform state mv 'null_resource.install_alb_controller' 'module.eks_auto_mode.module.alb_controller.null_resource.install[0]'
```

#### EBS CSI Driver Resources (to module.eks_auto_mode.module.ebs_csi_driver)
```bash
terraform state mv 'aws_iam_role.ebs_csi_driver' 'module.eks_auto_mode.module.ebs_csi_driver.aws_iam_role.this'
terraform state mv 'aws_iam_policy.ebs_csi_driver' 'module.eks_auto_mode.module.ebs_csi_driver.aws_iam_policy.this'
terraform state mv 'aws_iam_role_policy_attachment.ebs_csi_driver' 'module.eks_auto_mode.module.ebs_csi_driver.aws_iam_role_policy_attachment.this'
terraform state mv 'null_resource.annotate_ebs_csi_driver_sa' 'module.eks_auto_mode.module.ebs_csi_driver.null_resource.annotate_service_account[0]'
```

#### Secrets CSI Driver Resources (to module.eks_auto_mode.module.secrets_csi_driver)
```bash
terraform state mv 'aws_iam_role.secrets_store_csi_driver' 'module.eks_auto_mode.module.secrets_csi_driver.aws_iam_role.this'
terraform state mv 'aws_iam_policy.secrets_store_csi_driver' 'module.eks_auto_mode.module.secrets_csi_driver.aws_iam_policy.this'
terraform state mv 'aws_iam_role_policy_attachment.secrets_store_csi_driver' 'module.eks_auto_mode.module.secrets_csi_driver.aws_iam_role_policy_attachment.this'
terraform state mv 'kubernetes_service_account.secrets_sa' 'module.eks_auto_mode.module.secrets_csi_driver.kubernetes_service_account.this[0]'
terraform state mv 'aws_eks_pod_identity_association.secrets' 'module.eks_auto_mode.module.secrets_csi_driver.aws_eks_pod_identity_association.this[0]'
```

### Step 4: Verify Migration
```bash
# Run terraform plan to verify no changes
terraform plan

# Expected output: "No changes. Your infrastructure matches the configuration."
```

### Step 5: Apply Addon Version Updates (Optional)
If you want to update the addon versions that were detected in the initial plan:

```bash
# Update variables.tf or create a terraform.tfvars file
cat > terraform.tfvars <<EOF
addon_versions = {
  coredns                = "v1.11.3-eksbuild.2"
  kube_proxy             = "v1.33.3-eksbuild.10"
  vpc_cni                = "v1.20.3-eksbuild.1"
  aws_ebs_csi_driver     = "v1.49.0-eksbuild.1"
  eks_pod_identity_agent = "v1.3.4-eksbuild.1"
}
EOF

# Apply the updates
terraform apply
```

## Automated Migration Script

A migration script has been created to automate the state moves:

```bash
./migrate-to-modules.sh
```

## Rollback Plan

If you need to rollback:

1. Restore the backup state:
```bash
terraform state push terraform.tfstate.backup
```

2. Restore the original main.tf:
```bash
# The original configuration is preserved in main.tf.backup
# You would need to manually restore it if needed
```

## Benefits of Modular Structure

1. **Reusability**: Modules can be reused across different environments
2. **Maintainability**: Easier to update and maintain individual components
3. **Clarity**: Clear separation of concerns
4. **Version Control**: Can version modules independently
5. **Testing**: Easier to test individual components

## Addon Version Management

### Using most_recent (Recommended for Dev)
```hcl
addon_versions = {
  coredns                = null  # Uses most_recent
  kube_proxy             = null
  vpc_cni                = null
  aws_ebs_csi_driver     = null
  eks_pod_identity_agent = null
}
```

### Pinning Specific Versions (Recommended for Prod)
```hcl
addon_versions = {
  coredns                = "v1.11.3-eksbuild.2"
  kube_proxy             = "v1.33.3-eksbuild.10"
  vpc_cni                = "v1.20.3-eksbuild.1"
  aws_ebs_csi_driver     = "v1.49.0-eksbuild.1"
  eks_pod_identity_agent = "v1.3.4-eksbuild.1"
}
```

## Troubleshooting

### Issue: State move fails
**Solution**: Check the exact resource names in your state:
```bash
terraform state list
```

### Issue: Plan shows changes after migration
**Solution**: Review the differences and adjust the state moves accordingly

### Issue: Module not found
**Solution**: Ensure you've run `terraform init -upgrade`

## Support

For issues or questions, refer to:
- Module README files in `modules/eks-auto-mode/`
- Terraform AWS EKS Module documentation
- AWS EKS documentation
