# Prod environment composition. This root module contains ONLY module calls —
# no bare resource blocks (Req 1.3). Dependency order:
#
#   tagging ─▶ vpc ─┬─▶ eks ──┬─▶ ecr   (eks.node_role_name)
#                   │         │
#                   └─▶ database ◀─ (eks.node_security_group_id)

module "tagging" {
  source = "../../modules/tagging"

  environment = var.environment
  owner       = var.owner
  cost_center = var.cost_center
  name_prefix = var.name_prefix
  extra_tags  = var.extra_tags
}

module "vpc" {
  source = "../../modules/vpc"

  name_prefix        = module.tagging.name_prefix_resolved
  tags               = module.tagging.tags
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  azs                = var.azs
  single_nat_gateway = var.single_nat_gateway
  enable_flow_logs   = var.enable_flow_logs
}

module "eks" {
  source = "../../modules/eks"

  name_prefix        = module.tagging.name_prefix_resolved
  tags               = module.tagging.tags
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  cluster_version     = var.eks_cluster_version
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
}

module "database" {
  source = "../../modules/database"

  name_prefix            = module.tagging.name_prefix_resolved
  tags                   = module.tagging.tags
  private_subnet_ids     = module.vpc.private_subnet_ids
  node_security_group_id = module.eks.node_security_group_id

  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  multi_az                = var.db_multi_az
  backup_retention_period = var.db_backup_retention
  deletion_protection     = var.db_deletion_protection
  db_password             = var.db_password
}

module "ecr" {
  source = "../../modules/ecr"

  name_prefix                = module.tagging.name_prefix_resolved
  tags                       = module.tagging.tags
  repository_names           = var.ecr_repository_names
  image_tag_mutability       = var.ecr_image_tag_mutability
  scan_on_push               = var.ecr_scan_on_push
  untagged_image_expiry_days = var.ecr_untagged_image_expiry_days
  max_image_count            = var.ecr_max_image_count
  node_role_name             = module.eks.node_role_name
}
