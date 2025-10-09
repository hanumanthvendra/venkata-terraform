# EKS Auto Mode Module

This module creates an Amazon EKS cluster with Auto Mode enabled, along with all necessary addons and IAM configurations.

## Features

- **EKS Cluster with Auto Mode**: Fully managed compute with automatic scaling
- **AWS Load Balancer Controller**: Automatic ALB/NLB provisioning for Kubernetes services
- **EBS CSI Driver**: Persistent volume support with EBS
- **Secrets Store CSI Driver**: AWS Secrets Manager integration with Pod Identity
- **Configurable Addon Versions**: Pin specific versions or use latest

## Usage

```hcl
module "eks_auto_mode" {
  source = "../../../modules/eks-auto-mode"

  cluster_name       = "my-eks-cluster"
  kubernetes_version = "1.33"
  environment        = "dev"
  region             = "us-east-1"

  vpc_id     = "vpc-xxxxx"
  subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]

  enable_public_access = true
  node_pools           = ["general-purpose"]

  # Optional: Pin specific addon versions
  addon_versions = {
    coredns                = "v1.11.3-eksbuild.2"
    kube_proxy             = "v1.33.3-eksbuild.10"
    vpc_cni                = "v1.20.3-eksbuild.1"
    aws_ebs_csi_driver     = "v1.49.0-eksbuild.1"
    eks_pod_identity_agent = "v1.3.4-eksbuild.1"
  }

  tags = {
    Project = "my-project"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 5.0 |
| kubernetes | >= 2.20 |
| null | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |
| kubernetes | >= 2.20 |
| null | >= 3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| eks | terraform-aws-modules/eks/aws | ~> 20.0 |
| alb_controller | ../eks-addons/alb-controller | n/a |
| ebs_csi_driver | ../eks-addons/ebs-csi-driver | n/a |
| secrets_csi_driver | ../eks-addons/secrets-csi-driver | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the EKS cluster | `string` | n/a | yes |
| environment | Environment name | `string` | n/a | yes |
| region | AWS region | `string` | n/a | yes |
| vpc_id | VPC ID where the cluster will be deployed | `string` | n/a | yes |
| subnet_ids | List of subnet IDs for the EKS cluster | `list(string)` | n/a | yes |
| kubernetes_version | Kubernetes version for the EKS cluster | `string` | `"1.33"` | no |
| enable_public_access | Enable public access to EKS cluster endpoint | `bool` | `true` | no |
| node_pools | List of node pools for EKS Auto Mode | `list(string)` | `["general-purpose"]` | no |
| addon_versions | Versions for EKS addons | `object` | `null` (uses most_recent) | no |
| install_alb_controller | Whether to install AWS Load Balancer Controller | `bool` | `true` | no |
| annotate_ebs_csi_sa | Whether to annotate EBS CSI Driver service account | `bool` | `true` | no |
| secrets_namespace | Kubernetes namespace for secrets service account | `string` | `"default"` | no |
| secrets_service_account_name | Name of the Kubernetes service account for secrets | `string` | `"secrets-sa"` | no |
| secrets_manager_arns | List of AWS Secrets Manager ARNs that can be accessed | `list(string)` | `["*"]` | no |
| tags | Additional tags for resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_arn | The Amazon Resource Name (ARN) of the cluster |
| cluster_endpoint | Endpoint for your Kubernetes API server |
| cluster_name | The name of the EKS cluster |
| cluster_oidc_issuer_url | The URL on the EKS cluster for the OpenID Connect identity provider |
| oidc_provider_arn | The ARN of the OIDC Provider |
| alb_controller_role_arn | ARN of the IAM role for AWS Load Balancer Controller |
| ebs_csi_driver_role_arn | ARN of the IAM role for EBS CSI Driver |
| secrets_csi_driver_role_arn | ARN of the IAM role for Secrets Store CSI Driver |

## Addon Version Management

### Using Latest Versions (Recommended for Dev)
Set addon versions to `null` to automatically use the most recent version:

```hcl
addon_versions = {
  coredns                = null
  kube_proxy             = null
  vpc_cni                = null
  aws_ebs_csi_driver     = null
  eks_pod_identity_agent = null
}
```

### Pinning Specific Versions (Recommended for Prod)
Specify exact versions for production stability:

```hcl
addon_versions = {
  coredns                = "v1.11.3-eksbuild.2"
  kube_proxy             = "v1.33.3-eksbuild.10"
  vpc_cni                = "v1.20.3-eksbuild.1"
  aws_ebs_csi_driver     = "v1.49.0-eksbuild.1"
  eks_pod_identity_agent = "v1.3.4-eksbuild.1"
}
```

## Sub-Modules

This module uses the following sub-modules:

- **alb-controller**: AWS Load Balancer Controller setup
- **ebs-csi-driver**: EBS CSI Driver IAM configuration
- **secrets-csi-driver**: Secrets Store CSI Driver with Pod Identity

See individual module READMEs for more details.

## Examples

### Basic Usage
```hcl
module "eks_auto_mode" {
  source = "../../../modules/eks-auto-mode"

  cluster_name = "my-cluster"
  environment  = "dev"
  region       = "us-east-1"
  vpc_id       = "vpc-xxxxx"
  subnet_ids   = ["subnet-xxxxx", "subnet-yyyyy"]
}
```

### Production Configuration
```hcl
module "eks_auto_mode" {
  source = "../../../modules/eks-auto-mode"

  cluster_name       = "prod-cluster"
  kubernetes_version = "1.33"
  environment        = "prod"
  region             = "us-east-1"

  vpc_id     = "vpc-xxxxx"
  subnet_ids = ["subnet-xxxxx", "subnet-yyyyy", "subnet-zzzzz"]

  enable_public_access = false
  node_pools           = ["general-purpose", "system"]

  # Pin versions for production
  addon_versions = {
    coredns                = "v1.11.3-eksbuild.2"
    kube_proxy             = "v1.33.3-eksbuild.10"
    vpc_cni                = "v1.20.3-eksbuild.1"
    aws_ebs_csi_driver     = "v1.49.0-eksbuild.1"
    eks_pod_identity_agent = "v1.3.4-eksbuild.1"
  }

  tags = {
    Environment = "production"
    CostCenter  = "engineering"
  }
}
```

## License

Apache 2.0 Licensed. See LICENSE for full details.
