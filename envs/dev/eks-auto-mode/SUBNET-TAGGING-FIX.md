# EKS Auto-Mode Subnet Tagging Fix

## Issue Summary
Public subnets were missing the cluster ownership tag (`kubernetes.io/cluster/<cluster-name>`), which prevented the AWS Load Balancer Controller from automatically discovering them for creating internet-facing Application Load Balancers.

## Root Cause
The EKS auto-mode module was only receiving private subnet IDs and therefore only tagging private subnets with the cluster ownership tag. Public subnets were not being passed to the module.

## Changes Made

### 1. Updated `venkata-terraform/envs/dev/eks-auto-mode/main.tf`
- Added `public_subnet_ids` parameter to pass public subnets from network remote state
- Added `private_subnet_ids` parameter explicitly (was implicit before)
- EKS cluster continues to run on private subnets only via `subnet_ids` parameter
- Added clear comments explaining the purpose of each subnet parameter

### 2. Updated `venkata-terraform/modules/eks-auto-mode/main.tf`
- Split the single `aws_ec2_tag.cluster_ownership` resource into two separate resources:
  - `aws_ec2_tag.public_subnet_cluster_ownership` - Tags public subnets
  - `aws_ec2_tag.private_subnet_cluster_ownership` - Tags private subnets
- This provides better clarity and separation of concerns

## Verification Results

### All Subnets Now Have Cluster Ownership Tag
```
+---------------------------+--------+-----------+
|  Subnet ID                | Owned  | Type      |
+---------------------------+--------+-----------+
|  subnet-05da43b6d58a4a7ad |  owned |  Private  |
|  subnet-089c505b3bb3ef03e |  owned |  Public   |
|  subnet-0e0a90910ddbdcb4f |  owned |  Public   |
|  subnet-0d8b169af8721a3b3 |  owned |  Private  |
+---------------------------+--------+-----------+
```

### ELB Role Tags (from VPC Module)
```
+---------------------------+-------+------------------+
|  Subnet ID                | elb   | internal-elb     |
+---------------------------+-------+------------------+
|  subnet-05da43b6d58a4a7ad |  None |  1               |
|  subnet-089c505b3bb3ef03e |  1    |  None            |
|  subnet-0e0a90910ddbdcb4f |  1    |  None            |
|  subnet-0d8b169af8721a3b3 |  None |  1               |
+---------------------------+-------+------------------+
```

### Terraform State Alignment
All subnet tags are now properly tracked in Terraform state:
- `module.eks_auto_mode.aws_ec2_tag.private_subnet_cluster_ownership["subnet-05da43b6d58a4a7ad"]`
- `module.eks_auto_mode.aws_ec2_tag.private_subnet_cluster_ownership["subnet-0d8b169af8721a3b3"]`
- `module.eks_auto_mode.aws_ec2_tag.public_subnet_cluster_ownership["subnet-089c505b3bb3ef03e"]`
- `module.eks_auto_mode.aws_ec2_tag.public_subnet_cluster_ownership["subnet-0e0a90910ddbdcb4f"]`

## Impact

### Before Fix
- ❌ Public subnets: Missing cluster ownership tag
- ✅ Private subnets: Had cluster ownership tag
- ❌ ALB Controller: Could not auto-discover public subnets for internet-facing ALBs

### After Fix
- ✅ Public subnets: Have cluster ownership tag
- ✅ Private subnets: Have cluster ownership tag
- ✅ ALB Controller: Can auto-discover both public and private subnets
- ✅ Internet-facing ALBs: Can be created in public subnets
- ✅ Internal ALBs: Can be created in private subnets

## Subnet Tagging Strategy

### Required Tags for ALB Controller Auto-Discovery

#### Public Subnets (for Internet-facing ALBs)
- `kubernetes.io/cluster/<cluster-name>` = `owned` ✅ (Added by EKS module)
- `kubernetes.io/role/elb` = `1` ✅ (Added by VPC module)

#### Private Subnets (for Internal ALBs)
- `kubernetes.io/cluster/<cluster-name>` = `owned` ✅ (Added by EKS module)
- `kubernetes.io/role/internal-elb` = `1` ✅ (Added by VPC module)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC                                  │
│                                                              │
│  ┌──────────────────────┐      ┌──────────────────────┐    │
│  │   Public Subnets     │      │   Private Subnets    │    │
│  │                      │      │                      │    │
│  │  - Internet-facing   │      │  - EKS Cluster       │    │
│  │    ALBs              │      │  - EKS Nodes         │    │
│  │  - NAT Gateways      │      │  - Internal ALBs     │    │
│  │                      │      │                      │    │
│  │  Tags:               │      │  Tags:               │    │
│  │  ✅ cluster/name     │      │  ✅ cluster/name     │    │
│  │  ✅ role/elb         │      │  ✅ role/internal-elb│    │
│  └──────────────────────┘      └──────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Terraform Apply Summary
```
Plan: 4 to add, 0 to change, 2 to destroy.

Resources Added:
- 2 public subnet cluster ownership tags
- 2 private subnet cluster ownership tags (recreated with new resource names)

Resources Destroyed:
- 2 old private subnet tags (replaced with new resource structure)
```

## Date
Applied: 2025-01-XX

## Status
✅ **COMPLETED** - All subnet tags are now properly configured and aligned with Terraform state.
