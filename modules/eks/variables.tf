variable "name_prefix" {
  description = "Resolved environment-keyed name prefix (e.g. 'app-dev'), from the tagging module."
  type        = string
}

variable "tags" {
  description = "Standard tag map from the tagging module."
  type        = map(string)
}

variable "vpc_id" {
  description = "VPC id (from the vpc module) hosting the cluster and bastion."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet ids (from the vpc module) for node groups and control-plane ENIs."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet ids (from the vpc module); the SSM bastion is placed in the first one."
  type        = list(string)
}

variable "cluster_version" {
  description = "EKS Kubernetes control-plane version."
  type        = string
  default     = "1.34"
}

variable "endpoint_public_access" {
  description = "Whether the EKS public API endpoint is enabled. Design default is private-only (false)."
  type        = bool
  default     = false
}

variable "endpoint_private_access" {
  description = "Whether the EKS private API endpoint is enabled. Design default is private-only (true)."
  type        = bool
  default     = true
}

variable "node_instance_types" {
  description = "Managed node group instance types."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 2
}

variable "enabled_cluster_log_types" {
  description = "EKS control-plane log types to ship to CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "enable_irsa" {
  description = "When true, create the cluster OIDC provider so service accounts can assume IAM roles (IRSA)."
  type        = bool
  default     = true
}

variable "bastion_instance_type" {
  description = "Instance type for the SSM-managed bastion host."
  type        = string
  default     = "t3.micro"
}
