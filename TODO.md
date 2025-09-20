# TODO: Modify EKS Auto-Mode Terraform Script

## Approved Plan
- Create new IAM roles and resources with "eks-auto-mode" prefix without touching existing resources.

## Steps to Complete
- [x] Update variables.tf to add new variables for new IAM role name and assume role policy if needed.
- [x] Modify main.tf to replace data lookup of existing IAM role with new aws_iam_role resource prefixed with "eks-auto-mode".
- [x] Add aws_iam_role_policy_attachment resources for the new role with required policies (AmazonEKSClusterPolicy, and Auto Mode policies).
- [x] Update aws_eks_cluster resource to use the new IAM role ARN.
- [x] Update tags in aws_eks_cluster to use "eks-auto-mode" prefix.
- [x] Modify aws_eks_access_entry to use a new principal ARN or role as needed.
- [x] Ensure nodepools.tf, outputs.tf, providers.tf remain unchanged or update references if necessary.
- [x] Test terraform validate and plan to ensure no interference with existing resources.
- [ ] Apply changes and verify new resources are created correctly.

## Progress Tracking
- Started: [Date/Time]
- Completed: [Date/Time]
