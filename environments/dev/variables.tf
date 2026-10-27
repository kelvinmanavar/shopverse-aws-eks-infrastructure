# ---------------------------------------------------------------------------
# Identity / tagging
# ---------------------------------------------------------------------------

variable "environment" {
  description = "Environment key. Fixed to 'dev' for this root module."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "owner" {
  description = "Owning team or operations contact (tag)."
  type        = string
}

variable "cost_center" {
  description = "Cost-allocation group (tag)."
  type        = string
}

variable "name_prefix" {
  description = "Base prefix for resource names."
  type        = string
  default     = "app"
}

variable "aws_region" {
  description = "AWS region for the provider."
  type        = string
  default     = "ap-south-1"
}

variable "extra_tags" {
  description = "Additive tags (cannot override the four standard tags)."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to span."
  type        = number
  default     = 2
}

variable "azs" {
  description = "Explicit AZ names (optional; derived from region when empty)."
  type        = list(string)
  default     = []
}

variable "single_nat_gateway" {
  description = "Dev shares a single NAT gateway for cost."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Emit VPC flow logs to CloudWatch."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# EKS
# ---------------------------------------------------------------------------

variable "eks_cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.34"
}

variable "node_instance_types" {
  description = "Managed node group instance types."
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_desired_size" {
  description = "Desired node count."
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum node count."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum node count."
  type        = number
  default     = 2
}

# ---------------------------------------------------------------------------
# Database
# ---------------------------------------------------------------------------

variable "db_engine_version" {
  description = "RDS MySQL engine version."
  type        = string
  default     = "8.4.11"
}

variable "db_instance_class" {
  description = "RDS instance class (dev: Free Tier eligible db.t3.micro)."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GiB (dev: 20, Free Tier ceiling)."
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "Multi-AZ (dev: false)."
  type        = bool
  default     = false
}

variable "db_backup_retention" {
  description = "Backup retention in days (dev: 7)."
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "RDS deletion protection (dev: false)."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip the RDS final snapshot on destroy (dev: true for fast teardown)."
  type        = bool
  default     = true
}

variable "db_password" {
  description = "RDS master password, injected via TF_VAR_db_password from a secrets store; NEVER set in tfvars. Only used when manage_master_user_password is false."
  type        = string
  default     = null
  sensitive   = true
}

# ---------------------------------------------------------------------------
# ECR
# ---------------------------------------------------------------------------

variable "ecr_repository_names" {
  description = "Logical ECR repository names."
  type        = list(string)
  default     = ["shopverse-frontend", "shopverse-backend"]
}

variable "ecr_image_tag_mutability" {
  description = "ECR tag mutability (dev: MUTABLE)."
  type        = string
  default     = "MUTABLE"
}

variable "ecr_scan_on_push" {
  description = "ECR image scanning on push."
  type        = bool
  default     = true
}

variable "ecr_untagged_image_expiry_days" {
  description = "Expire untagged ECR images after N days."
  type        = number
  default     = 14
}

variable "ecr_max_image_count" {
  description = "Max retained tagged ECR images per repo (dev: 10)."
  type        = number
  default     = 10
}
