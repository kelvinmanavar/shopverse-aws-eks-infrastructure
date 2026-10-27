# EKS control plane: cluster IAM role, KMS key for envelope encryption of
# Kubernetes secrets, control-plane log group, and the private-only cluster.

data "aws_region" "current" {}

# ---------------------------------------------------------------------------
# Cluster IAM role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.name_prefix}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json

  tags = merge(var.tags, { Name = "${var.name_prefix}-eks-cluster-role" })
}

resource "aws_iam_role_policy_attachment" "cluster_eks_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# Lets the control plane manage VPC resources it owns — security groups for
# pods (SecurityGroupPolicy) and branch ENIs for Windows networking. AWS
# recommends attaching this to the cluster role alongside AmazonEKSClusterPolicy.
resource "aws_iam_role_policy_attachment" "cluster_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# ---------------------------------------------------------------------------
# KMS key for envelope encryption of Kubernetes secrets
# ---------------------------------------------------------------------------

resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS secret envelope encryption (${var.name_prefix})"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-eks-kms" })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.name_prefix}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# ---------------------------------------------------------------------------
# Control-plane logging
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "cluster" {
  # EKS writes control-plane logs to this conventional group name.
  name              = "/aws/eks/${var.name_prefix}-eks/cluster"
  retention_in_days = 30

  tags = merge(var.tags, { Name = "${var.name_prefix}-eks-logs" })
}

# ---------------------------------------------------------------------------
# EKS cluster (private-only API endpoint)
# ---------------------------------------------------------------------------

resource "aws_eks_cluster" "cluster" {
  name     = "${var.name_prefix}-eks"
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  enabled_cluster_log_types = var.enabled_cluster_log_types

  access_config {
    authentication_mode = "API"
  }

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-eks" })

  # Ensure the role policy and log group exist before the cluster, and that the
  # cluster is torn down before its role (so EKS can clean up managed ENIs/SGs).
  depends_on = [
    aws_iam_role_policy_attachment.cluster_eks_policy,
    aws_iam_role_policy_attachment.cluster_vpc_resource_controller,
    aws_cloudwatch_log_group.cluster,
  ]
}
