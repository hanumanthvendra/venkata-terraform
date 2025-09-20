#########################################
# Gate NodePools until cluster exists
#########################################
locals {
  do_nodepools = var.enable_nodepools ? 1 : 0
}

data "aws_eks_cluster" "this" {
  count = local.do_nodepools
  name  = aws_eks_cluster.this.name
}
data "aws_eks_cluster_auth" "this" {
  count = local.do_nodepools
  name  = aws_eks_cluster.this.name
}

provider "kubernetes" {
  host                   = local.do_nodepools == 1 ? data.aws_eks_cluster.this[0].endpoint : null
  cluster_ca_certificate = local.do_nodepools == 1 ? base64decode(data.aws_eks_cluster.this[0].certificate_authority[0].data) : null
  token                  = local.do_nodepools == 1 ? data.aws_eks_cluster_auth.this[0].token : null
}

#########################################
# Example Spot NodePool (optional)
#########################################
resource "kubernetes_manifest" "nodeclass_gp_spot" {
  count = local.do_nodepools
  manifest = {
    "apiVersion" = "eks.amazonaws.com/v1"
    "kind"       = "NodeClass"
    "metadata"   = { "name" = "gp-spot" }
    "spec" = {
      "role" = aws_iam_role.node.name
      "securityGroupSelectorTerms" = [{
        "tags" = { "kubernetes.io/cluster/${var.cluster_name}" = "owned" }
      }]
      "subnetSelectorTerms" = [for id in local.subnet_ids : { "id" = id }]
    }
  }
}

resource "kubernetes_manifest" "nodepool_gp_spot" {
  count      = local.do_nodepools
  depends_on = [kubernetes_manifest.nodeclass_gp_spot]
  manifest = {
    "apiVersion" = "karpenter.sh/v1"
    "kind"       = "NodePool"
    "metadata"   = { "name" = "gp-spot" }
    "spec" = {
      "template" = {
        "spec" = {
          "nodeClassRef" = { "group" = "eks.amazonaws.com", "kind" = "NodeClass", "name" = "gp-spot" }
          "requirements" = [
            { "key" = "eks.amazonaws.com/instance-category", "operator" = "In", "values" = ["c", "m"] },
            { "key" = "karpenter.sh/capacity-type", "operator" = "In", "values" = ["spot"] }
          ]
        }
      }
      "limits"     = { "cpu" = "200" } # optional cluster-wide cap
      "disruption" = { "consolidateAfter" = "5m" }
    }
  }
}
