################################################################################
# Secrets Store CSI Driver Module
################################################################################

# IAM Role for Secrets Store CSI Driver (Pod Identity) - Imported
resource "aws_iam_role" "pod_identity" {
  name = "dev-eks-auto-mode-3-secrets-store-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "pods.eks.amazonaws.com" },
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = var.tags
}

# IAM Policy for Secrets Store CSI Driver (Pod Identity) - Imported
resource "aws_iam_policy" "pod_identity" {
  name        = "dev-eks-auto-mode-3-secrets-store-csi-driver-policy"
  description = "Policy for Secrets Store CSI Driver"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      Resource = var.secrets_manager_arns
    }]
  })

  tags = var.tags
}

# Attach policy to Pod Identity role
resource "aws_iam_role_policy_attachment" "pod_identity" {
  role       = aws_iam_role.pod_identity.name
  policy_arn = aws_iam_policy.pod_identity.arn
}

# IAM Role for IRSA - Imported
resource "aws_iam_role" "irsa" {
  name = "dev-eks-auto-mode-3-nginx-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = "arn:aws:iam::817928572948:oidc-provider/oidc.eks.ap-south-1.amazonaws.com/id/134734E739B470D70C84567215B8A252"
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "oidc.eks.ap-south-1.amazonaws.com/id/134734E739B470D70C84567215B8A252:sub" = "system:serviceaccount:default:nginx-irsa-deployment-sa",
          "oidc.eks.ap-south-1.amazonaws.com/id/134734E739B470D70C84567215B8A252:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

# Inline policy for IRSA role - Imported
resource "aws_iam_role_policy" "irsa_secrets_access" {
  name = "SecretsManagerAccess"
  role = aws_iam_role.irsa.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid    = "ReadSpecificSecret",
      Effect = "Allow",
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      Resource = "arn:aws:secretsmanager:ap-south-1:817928572948:secret:test-secret-*"
    }]
  })
}

# Kubernetes Service Account
resource "kubernetes_service_account" "this" {
  count = var.create_service_account ? 1 : 0

  metadata {
    name      = var.service_account_name
    namespace = var.namespace
    labels = {
      app = "secrets-consumer"
    }
  }
}

# EKS Pod Identity Association
resource "aws_eks_pod_identity_association" "this" {
  count = var.create_pod_identity_association ? 1 : 0

  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account_name
  role_arn        = aws_iam_role.pod_identity.arn

  depends_on = [kubernetes_service_account.this]
}
