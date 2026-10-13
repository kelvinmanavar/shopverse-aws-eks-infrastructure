variable "name_prefix" {
  description = "Resolved environment-keyed name prefix (e.g. 'app-dev'), from the tagging module."
  type        = string
}

variable "tags" {
  description = "Standard tag map from the tagging module, applied to resources that take explicit tags."
  type        = map(string)
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC address space."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to span. The design targets 2 AZs."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "az_count must be at least 2 for high availability."
  }
}

variable "azs" {
  description = "Explicit Availability Zone names (e.g. [\"ap-south-1a\",\"ap-south-1b\"]). When empty, AZs are derived from the region via a data source."
  type        = list(string)
  default     = []
}

variable "single_nat_gateway" {
  description = "When true, provision one shared NAT gateway (cost saving, dev). When false, provision one NAT gateway per AZ (HA, prod)."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "When true, emit VPC flow logs to a CloudWatch Logs group."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "CloudWatch Logs retention (days) for VPC flow logs."
  type        = number
  default     = 30
}
