variable "name_prefix" {
  description = "Resolved environment-keyed name prefix (e.g. 'app-dev'), from the tagging module."
  type        = string
}

variable "tags" {
  description = "Standard tag map from the tagging module."
  type        = map(string)
}

variable "private_subnet_ids" {
  description = "Private subnet ids (from the vpc module) for the DB subnet group."
  type        = list(string)
}

variable "node_security_group_id" {
  description = "EKS node security group id (from the eks module). The ONLY source permitted 3306 ingress to the database."
  type        = string
}

variable "engine_version" {
  description = "MySQL engine version."
  type        = string
  default     = "8.4.11"
}

variable "instance_class" {
  description = "RDS instance class (e.g. db.t3.micro for dev, db.m5.large for prod)."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GiB."
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Whether the instance is Multi-AZ (prod true, dev false)."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Days to retain automated backups."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Guard the instance against accidental deletion."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "When true, no final snapshot is taken on destroy (fast teardown, typical for dev). When false, a uniquely-named final snapshot is taken (recommended for prod)."
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Initial database name created on the instance."
  type        = string
  default     = "appdb"
}

variable "master_username" {
  description = "Master DB username."
  type        = string
  default     = "admin"
}

variable "manage_master_user_password" {
  description = "When true, RDS generates and manages the master password in AWS Secrets Manager (nothing stored in Terraform state). When false, db_password must be supplied via TF_VAR_db_password."
  type        = bool
  default     = true
}

variable "db_password" {
  description = "Master DB password. Injected via TF_VAR_db_password from a secrets store; NEVER set in tfvars. Only used when manage_master_user_password = false."
  type        = string
  default     = null
  sensitive   = true
}
