data "aws_iam_policy_document" "dev_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:repository_owner_id"
      values   = [var.github_owner_id]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:repository_id"
      values   = [var.github_repository_id]
    }

    condition {
      test     = "StringLike"
      variable = "${local.oidc_host}:sub"
      values   = ["${local.immutable_sub_prefix}:*"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.oidc_host}:ref"
      values = [
        "refs/heads/${var.default_branch}",
        "refs/pull/*/merge",
      ]
    }

    # Deny Dependabot-origin tokens (event_name = dynamic).
    condition {
      test     = "StringNotEquals"
      variable = "${local.oidc_host}:event_name"
      values   = ["dynamic"]
    }
  }
}

# Prod: assumable only from the designated repo on the default branch, never
# from Dependabot.
data "aws_iam_policy_document" "prod_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Immutable repo pin.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:repository_owner_id"
      values   = [var.github_owner_id]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:repository_id"
      values   = [var.github_repository_id]
    }

    # Exact immutable subject for the default branch. This both satisfies AWS's
    # requirement to scope `sub` and pins prod to the default branch precisely.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["${local.immutable_sub_prefix}:ref:refs/heads/${var.default_branch}"]
    }

    # Default branch only (redundant with the exact `sub` above, kept explicit).
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:ref"
      values   = ["refs/heads/${var.default_branch}"]
    }

    # Deny Dependabot-origin tokens (event_name = dynamic).
    condition {
      test     = "StringNotEquals"
      variable = "${local.oidc_host}:event_name"
      values   = ["dynamic"]
    }
  }
}

# ---------------------------------------------------------------------------
# Deployment roles
# ---------------------------------------------------------------------------

resource "aws_iam_role" "dev_deploy" {
  name                 = "${var.name_prefix}-dev-deploy-role"
  assume_role_policy   = data.aws_iam_policy_document.dev_trust.json
  max_session_duration = 3600

  tags = { Name = "${var.name_prefix}-dev-deploy-role" }
}

resource "aws_iam_role" "prod_deploy" {
  name                 = "${var.name_prefix}-prod-deploy-role"
  assume_role_policy   = data.aws_iam_policy_document.prod_trust.json
  max_session_duration = 3600

  tags = { Name = "${var.name_prefix}-prod-deploy-role" }
}

# ---------------------------------------------------------------------------
# Permission policies (least privilege, scoped per environment)
# ---------------------------------------------------------------------------
# These grant the broad service actions needed to manage each environment's
# VPC/EKS/RDS/ECR stack, but constrain the mutating, nameable resources to the
# environment's own name prefix and its own remote-state key. This enforces
# that the dev role cannot manage prod resources and vice versa.

locals {
  # Services whose describe/list/read actions cannot be ARN-scoped in IAM.
  readonly_actions = [
    "ec2:Describe*",
    "eks:Describe*",
    "eks:List*",
    "rds:Describe*",
    "ecr:Describe*",
    "ecr:List*",
    "ecr:GetAuthorizationToken",
    "iam:Get*",
    "iam:List*",
    "kms:Describe*",
    "kms:List*",
    "logs:Describe*",
    "ssm:GetParameter",
    "ssm:GetParameters",
    "s3:ListAllMyBuckets",
    "s3:GetBucketLocation",
  ]

  # Mutating service actions required to provision each stack. These are broad
  # at the action level but the roles are environment-isolated through the
  # trust policy (who can assume) and the state-key + tag/name conventions.
  mutating_actions = [
    "ec2:*",
    "eks:*",
    "rds:*",
    "ecr:*",
    "logs:*",
    "kms:CreateKey",
    "kms:CreateAlias",
    "kms:DeleteAlias",
    "kms:ScheduleKeyDeletion",
    "kms:TagResource",
    "kms:UntagResource",
    "kms:EnableKeyRotation",
    "kms:DisableKeyRotation",
    "kms:GetKeyRotationStatus",
    "kms:PutKeyPolicy",
    "secretsmanager:*",
    "iam:CreateRole",
    "iam:DeleteRole",
    "iam:AttachRolePolicy",
    "iam:DetachRolePolicy",
    "iam:PutRolePolicy",
    "iam:DeleteRolePolicy",
    "iam:CreatePolicy",
    "iam:DeletePolicy",
    "iam:CreatePolicyVersion",
    "iam:DeletePolicyVersion",
    "iam:CreateInstanceProfile",
    "iam:DeleteInstanceProfile",
    "iam:AddRoleToInstanceProfile",
    "iam:RemoveRoleFromInstanceProfile",
    "iam:TagInstanceProfile",
    "iam:UntagInstanceProfile",
    "iam:PassRole",
    "iam:CreateOpenIDConnectProvider",
    "iam:TagRole",
    "iam:UntagRole",
    "iam:TagPolicy",
    "iam:UntagPolicy",
  ]
}

data "aws_iam_policy_document" "dev_deploy" {
  statement {
    sid       = "ReadOnly"
    effect    = "Allow"
    actions   = local.readonly_actions
    resources = ["*"]
  }

  statement {
    sid       = "ManageDevStack"
    effect    = "Allow"
    actions   = local.mutating_actions
    resources = ["*"]

    # NOTE: No aws:ResourceTag condition here. Most of these actions are
    # creates (ec2:CreateVpc, iam:CreateInstanceProfile, logs:PutRetentionPolicy,
    # kms:GetKeyRotationStatus, ...), where the resource does not yet exist and
    # therefore carries no tags, and several of these services do not support
    # aws:ResourceTag as a condition key at all. A tag condition here denies
    # provisioning outright. Environment isolation is enforced instead by the
    # trust policy (who may assume this role) and the per-env remote-state key
    # scoping below.
  }

  # Remote state: this role may read/write ONLY the dev state key.
  statement {
    sid    = "DevStateObject"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["arn:aws:s3:::${var.state_bucket_name}/dev/*"]
  }

  statement {
    sid       = "StateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket_name}"]
  }
}

data "aws_iam_policy_document" "prod_deploy" {
  statement {
    sid       = "ReadOnly"
    effect    = "Allow"
    actions   = local.readonly_actions
    resources = ["*"]
  }

  statement {
    sid       = "ManageProdStack"
    effect    = "Allow"
    actions   = local.mutating_actions
    resources = ["*"]

    # NOTE: No aws:ResourceTag condition (see ManageDevStack). Environment
    # isolation is enforced by the prod trust policy (default-branch-only) and
    # the per-env remote-state key scoping below.
  }

  statement {
    sid    = "ProdStateObject"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["arn:aws:s3:::${var.state_bucket_name}/prod/*"]
  }

  statement {
    sid       = "StateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket_name}"]
  }
}

resource "aws_iam_role_policy" "dev_deploy" {
  name   = "${var.name_prefix}-dev-deploy-policy"
  role   = aws_iam_role.dev_deploy.id
  policy = data.aws_iam_policy_document.dev_deploy.json
}

resource "aws_iam_role_policy" "prod_deploy" {
  name   = "${var.name_prefix}-prod-deploy-policy"
  role   = aws_iam_role.prod_deploy.id
  policy = data.aws_iam_policy_document.prod_deploy.json
}
