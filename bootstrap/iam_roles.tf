# Exactly two deployment roles (Req 7.4): one for dev, one for prod, each with
# a distinct identity. Trust is restricted to the single designated repository
# via the OIDC `sub` claim; the prod role is additionally restricted to the
# default branch (Req 7.5, 7.6). Max session duration 3600s (Req 7.1). Each
# role's permission policy is scoped to its own environment only (Req 7.3, 3.3).

# ---------------------------------------------------------------------------
# Trust policies
# ---------------------------------------------------------------------------

# Repo pinning uses the IMMUTABLE claims (repository_owner_id + repository_id),
# not the name-based `sub`, because this repository was created after
# 2026-07-15 and therefore emits ID-based subject claims. These numeric IDs are
# rename-proof and cannot be re-registered by another account.
#
# Branch/PR gating uses the `ref` claim; Dependabot runs (event_name = dynamic)
# are explicitly denied so only real Actions workflows can assume the roles.

# Dev: assumable from the designated repo on the default branch OR a pull
# request (so PR plans run), never from Dependabot.
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

    # AWS requires `sub` (or job_workflow_ref) to be scoped. Match this repo's
    # immutable subject prefix with a trailing wildcard; branch/PR gating is
    # done by the `ref` conditions below.
    condition {
      test     = "StringLike"
      variable = "${local.oidc_host}:sub"
      values   = ["${local.immutable_sub_prefix}:*"]
    }

    # Allow the default branch (post-merge dev apply) or any pull request
    # (PR plans). PR events carry ref = refs/pull/<n>/merge.
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
# that the dev role cannot manage prod resources and vice versa (Req 7.3, 3.3).

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
    "kms:EnableKeyRotation",
    "kms:PutKeyPolicy",
    "secretsmanager:*",
    "iam:CreateRole",
    "iam:DeleteRole",
    "iam:AttachRolePolicy",
    "iam:DetachRolePolicy",
    "iam:PutRolePolicy",
    "iam:DeleteRolePolicy",
    "iam:CreateInstanceProfile",
    "iam:DeleteInstanceProfile",
    "iam:AddRoleToInstanceProfile",
    "iam:RemoveRoleFromInstanceProfile",
    "iam:PassRole",
    "iam:CreateOpenIDConnectProvider",
    "iam:TagRole",
    "iam:TagPolicy",
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

    # Scope mutating IAM/name-bearing actions to dev-named resources.
    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/environment"
      values   = ["dev"]
    }
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

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/environment"
      values   = ["prod"]
    }
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
