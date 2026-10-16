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

  # Immutable subject prefix for this repository. Repos with immutable subject
  # claims emit a `sub` of the form:
  #   repo:<owner_name>@<owner_id>/<repo_name>@<repo_id>:<context>
  # AWS requires every GitHub-OIDC trust policy to scope `sub` (or
  # job_workflow_ref), so we match this prefix with a trailing wildcard; the
  # precise branch/PR gating is done by the `ref` conditions in each role.
  immutable_sub_prefix = "repo:${var.github_org}@${var.github_owner_id}/${var.github_repo}@${var.github_repository_id}"
}
