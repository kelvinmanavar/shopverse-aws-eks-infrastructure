terraform {
  # Bounded on both ends (Req 1.4, 1.7). Pinned to the 1.16.x line.
  required_version = ">= 1.16.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28, < 7.0"
    }
  }
}
