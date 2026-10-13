variable "name_prefix" {
  description = "Resolved environment-keyed name prefix (e.g. 'app-dev'), from the tagging module."
  type        = string
}

variable "tags" {
  description = "Standard tag map from the tagging module."
  type        = map(string)
}

variable "repository_names" {
  description = "Logical repository names. One ECR repository is created per entry, named '<name_prefix>-<name>'."
  type        = list(string)
  default     = ["shopverse-frontend", "shopverse-backend"]

  validation {
    condition     = length(var.repository_names) > 0
    error_message = "repository_names must contain at least one repository name."
  }
}

variable "image_tag_mutability" {
  description = "Tag mutability for the repositories. 'IMMUTABLE' in prod, 'MUTABLE' in dev."
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be one of: MUTABLE, IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Enable image vulnerability scanning on push."
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "Encryption at rest for the repositories. 'AES256' = S3-managed (no KMS key). 'KMS' = KMS encryption; with no kms_key_arn and create_kms_key=false it uses the AWS-managed 'aws/ecr' key (free, auditable), otherwise a customer-managed key."
  type        = string
  default     = "KMS"

  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "encryption_type must be one of: AES256, KMS."
  }
}

variable "create_kms_key" {
  description = "When true (and encryption_type = 'KMS' and no kms_key_arn is supplied), the module creates a dedicated customer-managed KMS key. When false, KMS encryption falls back to the AWS-managed 'aws/ecr' key."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "Existing customer-managed KMS key ARN for repository encryption. Only used when encryption_type = 'KMS'. When null, see create_kms_key for whether a key is created or the AWS-managed 'aws/ecr' key is used."
  type        = string
  default     = null
}

variable "untagged_image_expiry_days" {
  description = "Lifecycle: expire untagged images older than this many days."
  type        = number
  default     = 14
}

variable "max_image_count" {
  description = "Lifecycle: maximum number of tagged images to retain per repository."
  type        = number
  default     = 10
}

variable "node_role_name" {
  description = "EKS node IAM role name to grant image-pull access. When null, no pull policy is attached."
  type        = string
  default     = null
}
