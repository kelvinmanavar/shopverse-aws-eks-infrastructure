variable "aws_region" {
  description = "AWS region for the state bucket and IAM resources."
  type        = string
  default     = "ap-south-1"
}

variable "owner" {
  description = "Owning team or operations contact (tag)."
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost-allocation group (tag)."
  type        = string
  default     = "shopverse-engineering"
}

variable "state_bucket_name" {
  description = "Globally-unique name for the S3 bucket that stores Terraform remote state for all environments."
  type        = string
}

variable "github_org" {
  description = "GitHub organization (or user) that owns the repository, e.g. 'my-org'."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without the org), e.g. 'aws-infra-shopverse'."
  type        = string
}

variable "default_branch" {
  description = "Protected default branch. The prod deployment role may only be assumed from runs on this branch."
  type        = string
  default     = "main"
}

variable "name_prefix" {
  description = "Base prefix for IAM resource names."
  type        = string
  default     = "app"
}
