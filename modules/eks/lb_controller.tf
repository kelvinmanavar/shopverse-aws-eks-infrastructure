# AWS Load Balancer Controller — IRSA role + IAM policy.
#
# This provisions ONLY the infra prerequisite: an IAM role the controller's
# service account assumes (via IRSA) with the official AWS Load Balancer
# Controller permissions. The controller itself, the Gateway API CRDs, and the
# GatewayClass/Gateway/HTTPRoute resources are installed/applied at the
# Kubernetes layer (Helm/kubectl), not by Terraform.
#
# When installing the controller's Helm chart, annotate its service account:
#   eks.amazonaws.com/role-arn = <lb_controller_role_arn output>
# and set serviceAccount.name = var.lb_controller_service_account.
#
# The IAM policy JSON is the canonical policy published by
# kubernetes-sigs/aws-load-balancer-controller (docs/install/iam_policy.json),
# vendored here as lb_controller_iam_policy.json so it is byte-accurate and
# easy to refresh when upgrading the controller version.

locals {
  lb_controller_enabled = var.enable_lb_controller && var.enable_irsa
}

# Trust policy: only the controller's service account in kube-system may assume
# this role, via the cluster OIDC provider (IRSA), with aud pinned to STS.
data "aws_iam_policy_document" "lb_controller_assume_role" {
  count = local.lb_controller_enabled ? 1 : 0

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
      values   = ["system:serviceaccount:kube-system:${var.lb_controller_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  count = local.lb_controller_enabled ? 1 : 0

  name               = "${var.name_prefix}-lb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume_role[0].json

  tags = merge(var.tags, { Name = "${var.name_prefix}-lb-controller-role" })
}

# Customer-managed policy built from the official controller policy document.
resource "aws_iam_policy" "lb_controller" {
  count = local.lb_controller_enabled ? 1 : 0

  name        = "${var.name_prefix}-lb-controller-policy"
  description = "Permissions for the AWS Load Balancer Controller (ALB/NLB, Gateway API)."
  policy      = file("${path.module}/lb_controller_iam_policy.json")

  tags = merge(var.tags, { Name = "${var.name_prefix}-lb-controller-policy" })
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  count = local.lb_controller_enabled ? 1 : 0

  role       = aws_iam_role.lb_controller[0].name
  policy_arn = aws_iam_policy.lb_controller[0].arn
}
