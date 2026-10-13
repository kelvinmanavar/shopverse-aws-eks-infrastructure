terraform {
  # Bounded on both ends (Req 1.4, 1.7). Pinned to the 1.16.x line.
  required_version = ">= 1.16.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28, < 7.0"
    }
  }

  # NOTE: no backend block. Bootstrap runs once with LOCAL state to create the
  # state bucket, then its state is migrated into that bucket via
  # `terraform init -migrate-state` (key: bootstrap/terraform.tfstate).
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      "managed-by"  = "terraform"
      "owner"       = var.owner
      "cost-center" = var.cost_center
      "component"   = "bootstrap"
    }
  }
}
