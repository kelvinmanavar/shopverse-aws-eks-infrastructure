# Prod environment values (non-secret only). Secrets such as the DB password
# are injected via TF_VAR_* from a secrets store, never stored here
# This file is independent of dev.tfvars — no shared variable
# file feeds both environments.

environment = "prod"
owner       = "platform-team"
cost_center = "shopverse-engineering"
name_prefix = "app"
aws_region  = "ap-south-1"

# Network — prod runs one NAT gateway per AZ for high availability.
vpc_cidr           = "10.0.0.0/16"
az_count           = 2
single_nat_gateway = false
enable_flow_logs   = true

# EKS — production-grade nodes and scale.
eks_cluster_version = "1.35"
node_instance_types = ["t3.medium"]
node_desired_size   = 1
node_min_size       = 1
node_max_size       = 3

# Database — db.t3.micro, Multi-AZ, 20 GB, 1-day backups,

db_engine_version      = "8.4.11"
db_instance_class      = "db.t3.micro"
db_allocated_storage   = 20
db_multi_az            = true
db_backup_retention    = 1
db_deletion_protection = false
db_skip_final_snapshot = true

# ECR — immutable tags in prod for traceable, reproducible deploys.
ecr_repository_names           = ["shopverse-frontend", "shopverse-backend"]
ecr_image_tag_mutability       = "IMMUTABLE"
ecr_scan_on_push               = true
ecr_untagged_image_expiry_days = 14
ecr_max_image_count            = 20
