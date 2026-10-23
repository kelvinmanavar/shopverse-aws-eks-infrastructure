terraform {
  # Bounded on both ends (Req 1.4, 1.7). Pinned to the 1.16.x line.
  required_version = ">= 1.16.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28, < 7.0"
    }
  }

  # Bootstrap first ran with LOCAL state to create this bucket, then its state
  # was migrated here via `terraform init -migrate-state`. The deploy roles are
  # scoped to dev/* and prod/* keys, so only admins can reach this key.
  backend "s3" {
    bucket       = "shopverse-tfstate-16102026"
    key          = "bootstrap/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
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
