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
  description = "GitHub repository name (without the org), e.g. 'shopverse-aws-eks-infrastructure'. Used only for documentation/tagging; trust pinning uses the immutable numeric IDs below."
  type        = string
}

# Repositories created after 2026-07-15 (or opted into immutable subject claims)
# emit an ID-based OIDC `sub` instead of the name-based form. Rather than depend
# on the mutable, format-varying `sub`, the trust policies pin on these immutable
# numeric claims (repository_owner_id + repository_id), which never change on
# rename and cannot be re-registered by another account.
#
# Obtain them with the GitHub CLI:
#   gh api users/kelvinmanavar --jq .id
#   gh api repos/kelvinmanavar/shopverse-aws-eks-infrastructure --jq .id
variable "github_owner_id" {
  description = "Immutable numeric account ID of the GitHub org/user that owns the repo (OIDC claim repository_owner_id)."
  type        = string
}

variable "github_repository_id" {
  description = "Immutable numeric ID of the GitHub repository (OIDC claim repository_id)."
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
