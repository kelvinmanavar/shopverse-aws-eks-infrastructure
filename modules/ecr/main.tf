# Amazon ECR container registries, one repository per entry in
# repository_names, each named "<name_prefix>-<logical name>" so repositories
# are environment-keyed and distinct across dev/prod (Req 3.5, 9.5).
# KMS-encrypted, scan-on-push, per-env tag mutability, with a lifecycle policy
# that expires old/untagged images. Optionally grants the EKS node role pull
# access.

locals {
  # Map of logical name -> full repository name, used to drive for_each so each
  # repository has a stable address keyed by its logical name.
  repositories = { for n in var.repository_names : n => "${var.name_prefix}-${n}" }

  # Whether the module should create its own customer-managed KMS key: only when
  # using KMS encryption, no external key ARN was supplied, and create_kms_key is on.
  create_cmk = var.encryption_type == "KMS" && var.kms_key_arn == null && var.create_kms_key

  # The KMS key ARN to attach to repositories, resolved only for the KMS path:
  #   - explicit kms_key_arn (caller's CMK), else
  #   - the module-created CMK (when create_cmk), else
  #   - null  -> omit kms_key so AWS uses the managed 'aws/ecr' key.
  # For AES256, this stays null (no KMS key involved).
  resolved_kms_key_arn = (
    var.encryption_type != "KMS" ? null :
    var.kms_key_arn != null ? var.kms_key_arn :
    local.create_cmk ? aws_kms_key.ecr[0].arn :
    null
  )
}

# ---------------------------------------------------------------------------
# KMS key for repository encryption
# ---------------------------------------------------------------------------
# Only created when the caller explicitly wants a dedicated customer-managed
# key (encryption_type = "KMS", no kms_key_arn supplied, create_kms_key = true).
# Otherwise KMS encryption falls back to the AWS-managed "aws/ecr" key, and
# AES256 uses S3-managed encryption with no KMS key at all.

resource "aws_kms_key" "ecr" {
  count = local.create_cmk ? 1 : 0

  description             = "KMS key for ECR repository encryption (${var.name_prefix})"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-ecr-kms" })
}

resource "aws_kms_alias" "ecr" {
  count = local.create_cmk ? 1 : 0

  name          = "alias/${var.name_prefix}-ecr"
  target_key_id = aws_kms_key.ecr[0].key_id
}

# ---------------------------------------------------------------------------
# Repositories
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "repository" {
  for_each = local.repositories

  name                 = each.value
  image_tag_mutability = var.image_tag_mutability
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type

    # kms_key is set ONLY when a specific CMK ARN is resolved. For AES256 and
    # for the AWS-managed "aws/ecr" fallback it is omitted, which is what tells
    # ECR to use S3-managed or the aws/ecr key respectively.
    kms_key = local.resolved_kms_key_arn
  }

  tags = merge(var.tags, { Name = each.value })
}

# ---------------------------------------------------------------------------
# Lifecycle policy: expire untagged images, cap retained tagged images
# ---------------------------------------------------------------------------

resource "aws_ecr_lifecycle_policy" "lifecycle" {
  for_each = aws_ecr_repository.repository

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than ${var.untagged_image_expiry_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_expiry_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the most recent ${var.max_image_count} tagged images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }
        action = { type = "expire" }
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# EKS node pull access (optional)
# ---------------------------------------------------------------------------
# ECR auth is account/region-wide, so GetAuthorizationToken is granted on "*",
# while the layer/image pull actions are scoped to just these repositories.

data "aws_iam_policy_document" "node_pull" {
  count = var.node_role_name != null ? 1 : 0

  statement {
    sid       = "EcrAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "EcrPull"
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = [for r in aws_ecr_repository.repository : r.arn]
  }
}

resource "aws_iam_role_policy" "node_pull" {
  count = var.node_role_name != null ? 1 : 0

  name   = "${var.name_prefix}-ecr-pull"
  role   = var.node_role_name
  policy = data.aws_iam_policy_document.node_pull[0].json
}
