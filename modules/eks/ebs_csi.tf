# AWS EBS CSI driver, installed as a managed EKS add-on so pods can provision
# and mount EBS-backed PersistentVolumes. Runs with a dedicated IRSA role
# (least privilege) rather than the node role. Gated on enable_ebs_csi, and
# requires the cluster OIDC provider from irsa.tf (enable_irsa).

locals {
  ebs_csi_enabled = var.enable_ebs_csi && var.enable_irsa

  # OIDC issuer host (without the https:// scheme) used in IRSA trust conditions.
  oidc_provider_url = var.enable_irsa ? replace(aws_iam_openid_connect_provider.oidc[0].url, "https://", "") : ""
}

# Trust policy: only the EBS CSI controller service account in kube-system may
# assume this role, via the cluster OIDC provider (IRSA). The `aud` claim is
# also pinned to sts.amazonaws.com.
data "aws_iam_policy_document" "ebs_csi_assume_role" {
  count = local.ebs_csi_enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  count = local.ebs_csi_enabled ? 1 : 0

  name               = "${var.name_prefix}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role[0].json

  tags = merge(var.tags, { Name = "${var.name_prefix}-ebs-csi-role" })
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count = local.ebs_csi_enabled ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi[0].name
}

# The managed add-on. service_account_role_arn binds the driver's service
# account to the IRSA role above. Conflict resolution is set to OVERWRITE so
# the add-on's managed config takes precedence on create/update.
resource "aws_eks_addon" "ebs_csi" {
  count = local.ebs_csi_enabled ? 1 : 0

  cluster_name             = aws_eks_cluster.cluster.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_addon_version
  service_account_role_arn = aws_iam_role.ebs_csi[0].arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(var.tags, { Name = "${var.name_prefix}-ebs-csi" })

  # Nodes must exist before the driver's controller/daemonset can schedule.
  depends_on = [aws_eks_node_group.node_group]
}
