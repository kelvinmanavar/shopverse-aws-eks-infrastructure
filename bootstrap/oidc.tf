# GitHub Actions OIDC identity provider for keyless authentication (Req 7.1,
# 7.7). For GitHub, AWS validates tokens against its own trusted root CA
# library, so thumbprint_list is not required and is intentionally omitted.

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  tags = { Name = "${var.name_prefix}-github-oidc" }
}

locals {
  oidc_host = "token.actions.githubusercontent.com"
  repo_sub  = "repo:${var.github_org}/${var.github_repo}"
}
