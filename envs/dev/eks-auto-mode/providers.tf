terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Works with Auto Mode (you currently have v6.14.0 which is fine)
      version = ">= 5.79.0, < 7.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.31.0"
    }
  }
}

provider "aws" {
  region = var.region
}

/* kubernetes provider is defined in nodepools.tf and only enabled
   after the cluster exists to avoid first-apply failures */
