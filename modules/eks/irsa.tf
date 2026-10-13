# IRSA: an IAM OIDC identity provider bound to the cluster's OIDC issuer, so
# Kubernetes service accounts can assume IAM roles. Created when enable_irsa.

# Fetch the TLS certificate of the cluster OIDC issuer to compute the
# thumbprint the IAM OIDC provider requires.
data "tls_certificate" "oidc" {
  count = var.enable_irsa ? 1 : 0

  url = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc" {
  count = var.enable_irsa ? 1 : 0

  url             = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc[0].certificates[0].sha1_fingerprint]

  tags = merge(var.tags, { Name = "${var.name_prefix}-eks-oidc" })
}
