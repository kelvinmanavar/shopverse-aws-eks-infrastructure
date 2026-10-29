# Amazon RDS for MySQL in the private subnets: DB subnet group, a security
# group that permits 3306 ONLY from the EKS node SG, KMS storage encryption,
# automated backups, optional Multi-AZ and deletion protection, and a master
# password managed in Secrets Manager (or injected via TF_VAR_db_password).

# ---------------------------------------------------------------------------
# DB subnet group (private subnets only)
# ---------------------------------------------------------------------------

resource "aws_db_subnet_group" "db" {
  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, { Name = "${var.name_prefix}-db-subnet-group" })
}

# ---------------------------------------------------------------------------
# Security group: MySQL 3306 ingress ONLY from the EKS node security group
# ---------------------------------------------------------------------------

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db-sg"
  description = "RDS MySQL SG: 3306 ingress only from EKS node SG"
  vpc_id      = data.aws_subnet.first.vpc_id

  tags = merge(var.tags, { Name = "${var.name_prefix}-db-sg" })
}

# Derive the VPC id from the first private subnet so the module needs no extra
# vpc_id input.
data "aws_subnet" "first" {
  id = var.private_subnet_ids[0]
}

resource "aws_vpc_security_group_ingress_rule" "mysql_from_nodes" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL from EKS nodes only"
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.node_security_group_id
}

# Optional: allow 3306 from the SSM bastion so operators can reach the private
# DB via Session Manager port-forwarding (ad-hoc access, mysqldump backups).
# Created only when bastion_security_group_id is provided. The DB stays private
# — this references the bastion SG, it does not open any CIDR or public access.
resource "aws_vpc_security_group_ingress_rule" "mysql_from_bastion" {
  count = var.bastion_security_group_id != null ? 1 : 0

  security_group_id            = aws_security_group.db.id
  description                  = "MySQL from SSM bastion (operator access / backups)"
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.bastion_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.db.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# KMS key for storage encryption
# ---------------------------------------------------------------------------

resource "aws_kms_key" "db" {
  description             = "KMS key for RDS storage encryption (${var.name_prefix})"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-db-kms" })
}

resource "aws_kms_alias" "db" {
  name          = "alias/${var.name_prefix}-db"
  target_key_id = aws_kms_key.db.key_id
}

# ---------------------------------------------------------------------------
# RDS instance
# ---------------------------------------------------------------------------

# Unique suffix for the final-snapshot name so destroy/re-create never collides
# with a previously-retained snapshot of the same name.
resource "random_id" "snapshot_suffix" {
  byte_length = 4
}

resource "aws_db_instance" "mysql" {
  identifier     = "${var.name_prefix}-mysql"
  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = aws_kms_key.db.arn

  db_name  = var.db_name
  username = var.master_username

  # Password handling (Req 8.1/8.3): prefer RDS-managed Secrets Manager secret
  # so no plaintext password lives in state or tfvars. When disabled, the
  # password is injected via TF_VAR_db_password instead.
  manage_master_user_password = var.manage_master_user_password ? true : null
  password                    = var.manage_master_user_password ? null : var.db_password

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection

  # Final-snapshot handling. When skip_final_snapshot is false, give the
  # snapshot a unique name (random suffix) so a later destroy/re-create never
  # collides with a snapshot left behind by a previous instance. When true
  # (typical for dev), no final snapshot is taken and no name is set.
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-mysql-final-${random_id.snapshot_suffix.hex}"

  tags = merge(var.tags, { Name = "${var.name_prefix}-mysql" })
}
