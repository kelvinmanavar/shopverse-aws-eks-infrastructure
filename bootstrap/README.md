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

## One-time apply

```bash
cd bootstrap

terraform init    # local state (no backend block)

terraform apply \
  -var 'state_bucket_name=<org>-tfstate-<account-id>' \
  -var 'github_org=<your-org>' \
  -var 'github_repo=aws-infra-shopverse'
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
2. Set the CI/CD role ARNs (`dev_deploy_role_arn`, `prod_deploy_role_arn`) as the
   `role-to-assume` values in the GitHub Actions workflows / repo secrets.

## Isolation guarantees

- **dev** role trust: `repo:<org>/<repo>:*` (any branch, so PR plans run), scoped by
  permission policy to `environment = dev` resources and the `dev/*` state key only.
- **prod** role trust: `repo:<org>/<repo>:ref:refs/heads/<default_branch>` (default
  branch only), scoped to `environment = prod` resources and the `prod/*` state key.
- Both roles cap session duration at 3600s and use OIDC only — no long-lived keys.
