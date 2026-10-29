# Dev environment values (non-secret only). Secrets such as the DB password are
# injected via TF_VAR_* from a secrets store, never stored here (Req 8.1, 8.4).

environment = "dev"
owner       = "platform-team"
cost_center = "shopverse-engineering"
name_prefix = "app"
aws_region  = "ap-south-1"

# Network — dev uses a single shared NAT gateway for cost.
vpc_cidr           = "10.0.0.0/16"
az_count           = 2
single_nat_gateway = true
enable_flow_logs   = true

# EKS — smaller nodes, minimal scale for dev.
eks_cluster_version = "1.34"
node_instance_types = ["t3.small"]
node_desired_size   = 1
node_min_size       = 1
node_max_size       = 2

# Database — Free Tier eligible: db.t3.micro, single-AZ, 20 GB.
db_engine_version      = "8.4.11"
db_instance_class      = "db.t3.micro"
db_allocated_storage   = 20
db_multi_az            = false
db_backup_retention    = 1
db_deletion_protection = false
db_skip_final_snapshot = true

# ECR — mutable tags for iteration in dev.
ecr_repository_names           = ["shopverse-frontend", "shopverse-backend"]
ecr_image_tag_mutability       = "MUTABLE"
ecr_scan_on_push               = true
ecr_untagged_image_expiry_days = 14
ecr_max_image_count            = 10
