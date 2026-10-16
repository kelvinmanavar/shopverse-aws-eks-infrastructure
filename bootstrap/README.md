# Bootstrap

One-time, administrator-run setup that creates the shared Terraform remote-state
S3 bucket, the GitHub Actions OIDC identity provider, and the two per-environment
deployment IAM roles (dev, prod).

This root module is **not** part of the recurring CI/CD pipeline. It resolves the
chicken-and-egg problem: the environments' S3 backend needs a bucket that does not
exist yet, so bootstrap starts with **local state**, creates the bucket, and then
migrates its own state into that bucket.

## Prerequisites

- Admin AWS credentials in your shell (bootstrap creates IAM + S3 resources).
- A globally-unique name for the state bucket.
- Your GitHub org and repository names.

## This project's values

| Variable | Value |
| -------- | ----- |
| `github_org` | `kelvinmanavar` |
| `github_repo` | `shopverse-aws-eks-infrastructure` |
| `github_owner_id` | **look up** (immutable numeric account ID) |
| `github_repository_id` | **look up** (immutable numeric repo ID) |
| `default_branch` | `main` (default) |
| `aws_region` | `ap-south-1` (default) |
| `state_bucket_name` | choose a globally-unique name, e.g. `shopverse-tfstate-<account-id>` |

Repository: <https://github.com/kelvinmanavar/shopverse-aws-eks-infrastructure>

### Immutable subject claims (important)

This repository was created after **2026-07-15**, so its GitHub OIDC tokens use
**immutable, ID-based subject claims**. The role trust policies therefore pin on
the immutable `repository_owner_id` and `repository_id` claims instead of the
mutable, name-based `sub` — this is rename-proof and cannot be satisfied by
another account that later reuses the name. Look up the two numeric IDs with the
GitHub CLI:

```bash
gh api users/kelvinmanavar --jq .id                                    # github_owner_id
gh api repos/kelvinmanavar/shopverse-aws-eks-infrastructure --jq .id   # github_repository_id
```

The trust policies also deny Dependabot-origin tokens (`event_name = dynamic`)
and gate by branch: dev allows the default branch and pull requests; prod allows
only the default branch.

## One-time apply

```bash
cd bootstrap

terraform init    # local state (no backend block)

# Replace <account-id> with your AWS account id (S3 bucket names are global, so
# a unique suffix avoids collisions).
terraform apply \
  -var 'state_bucket_name=shopverse-tfstate-16102026' \
  -var 'github_org=kelvinmanavar' \
  -var 'github_repo=shopverse-aws-eks-infrastructure' \
  -var 'github_owner_id=<owner-id>' \
  -var 'github_repository_id=<repo-id>'
```

Note the outputs: `state_bucket_name`, `dev_deploy_role_arn`, `prod_deploy_role_arn`,
`github_oidc_provider_arn`.

## Migrate bootstrap state into the bucket (optional but recommended)

Add a backend block (or pass `-backend-config`) using the new bucket and the key
`bootstrap/terraform.tfstate`, then:

```bash
terraform init -migrate-state
```

## Wire up the environments

1. In `environments/dev/backend.tf` and `environments/prod/backend.tf`, replace
   `REPLACE_WITH_BOOTSTRAP_STATE_BUCKET` with the `state_bucket_name` output
   (or pass it via `-backend-config="bucket=..."`).
2. Configure the GitHub repository (<https://github.com/kelvinmanavar/shopverse-aws-eks-infrastructure>)
   with the variables, secret, and environments the workflows read (below).

### GitHub repository Variables

Set under **Settings → Secrets and variables → Actions → Variables**. The CI
(`ci-pull-request.yml`) and CD (`cd-deploy.yml`) workflows read these:

| Variable | Value (from bootstrap outputs) |
| -------- | ------------------------------ |
| `AWS_REGION` | `ap-south-1` |
| `TF_STATE_BUCKET` | the `state_bucket_name` output (e.g. `shopverse-tfstate-<account-id>`) |
| `DEV_DEPLOY_ROLE_ARN` | the `dev_deploy_role_arn` output |
| `PROD_DEPLOY_ROLE_ARN` | the `prod_deploy_role_arn` output |

### GitHub repository Secret

Set under **Settings → Secrets and variables → Actions → Secrets**:

| Secret | Notes |
| ------ | ----- |
| `DB_PASSWORD` | Only needed if the database module runs with `manage_master_user_password = false`. With the default (`true`), RDS manages the master credential in Secrets Manager and this secret is unused — but the workflows still reference it, so set it to any non-empty value (or flip the toggle). |

### GitHub Environments (protection rules)

Create two environments under **Settings → Environments**:

- **`dev`** — no required reviewers (auto-apply on merge).
- **`prod`** — add **required reviewers** (the authorized approver set), restrict the
  deployment branch to `main`, and set the wait-timer/expiration so an unapproved
  deployment is cancelled after 72 hours. These settings enforce the manual approval,
  the 72-hour timeout, and unauthorized-approver rejection described in the design;
  they are configured here in GitHub, not in the workflow YAML.

## Isolation guarantees

Both roles pin the repository on the **immutable** `repository_owner_id` +
`repository_id` claims (rename-proof) and deny Dependabot tokens
(`event_name = dynamic`). Branch gating is via the `ref` claim:

- **dev** role trust: owner-id + repo-id match, AND `ref` is either
  `refs/heads/main` or a pull request (`refs/pull/*/merge`, so PR plans run).
  Scoped by permission policy to `environment = dev` resources and the `dev/*`
  state key only.
- **prod** role trust: owner-id + repo-id match, AND `ref = refs/heads/main`
  (default branch only). Scoped to `environment = prod` resources and the
  `prod/*` state key.
- Both roles cap session duration at 3600s and use OIDC only — no long-lived keys.
