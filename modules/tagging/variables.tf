variable "environment" {
  description = "Environment key. Must be exactly 'dev' or 'prod'."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "owner" {
  description = "Owning team or operations contact; surfaced as the 'owner' tag."
  type        = string
}

variable "cost_center" {
  description = "Cost-allocation group; surfaced as the 'cost-center' tag."
  type        = string
}

variable "name_prefix" {
  description = "Base prefix for resource names. Combined with the environment to form the resolved prefix (e.g. 'app' -> 'app-dev')."
  type        = string
  default     = "app"
}

variable "extra_tags" {
  description = "Additional tags to merge in. These are additive only and cannot override the four standard keys (environment, managed-by, owner, cost-center)."
  type        = map(string)
  default     = {}
}
