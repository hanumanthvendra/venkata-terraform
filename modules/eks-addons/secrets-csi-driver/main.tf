################################################################################
# Secrets Store CSI Driver Module
################################################################################

# IAM Role for Secrets Store CSI Driver (Pod Identity)
resource "aws_iam_role" "this" {
  name = "${var.cluster_name}-secrets-store-csi-driver"

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

# IAM Policy for Secrets Store CSI Driver
resource "aws_iam_policy" "this" {
  name        = "${var.cluster_name}-secrets-store-csi-driver-policy"
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

# Attach policy to role
resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
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
  role_arn        = aws_iam_role.this.arn

  depends_on = [kubernetes_service_account.this]
}
