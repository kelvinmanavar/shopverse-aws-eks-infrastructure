# GitHub Actions OIDC identity provider for keyless authentication. For GitHub, AWS validates tokens against its own trusted root CA
# library, so thumbprint_list is not required and is intentionally omitted.

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  tags = { Name = "${var.name_prefix}-github-oidc" }
}

locals {
  oidc_host = "token.actions.githubusercontent.com"

  immutable_sub_prefix = "repo:${var.github_org}@${var.github_owner_id}/${var.github_repo}@${var.github_repository_id}"
}
