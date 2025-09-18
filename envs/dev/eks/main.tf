# Reference VPC resources from network environment
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket         = "terraform-backend-venkata"
    key            = "dev/network/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    use_lockfile   = true
  }
}

module "eks" {
  source = "../../../modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id          = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids      = data.terraform_remote_state.network.outputs.private_subnet_ids

  node_groups     = var.node_groups

  tags = var.tags
}


