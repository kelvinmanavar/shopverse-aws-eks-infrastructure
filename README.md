# ShopVerse AWS EKS Infrastructure

Terraform infrastructure-as-code for the ShopVerse platform on AWS, delivered
through a GitHub Actions CI/CD pipeline across two isolated environments
(`dev` and `prod`).

Repository: <https://github.com/kelvinmanavar/shopverse-aws-eks-infrastructure>

## Project values

| Setting | Value |
| ------- | ----- |
| GitHub org | `kelvinmanavar` |
| GitHub repo | `shopverse-aws-eks-infrastructure` |
| Default branch | `main` |
| AWS region | `ap-south-1` |
| Terraform | `1.16.x` (pinned, see `.terraform-version`) |
| AWS provider | `hashicorp/aws >= 6.28, < 7.0` |
| State backend | S3 with native locking (`use_lockfile`), no DynamoDB |

## What gets provisioned (per environment)

- **VPC** across 2 AZs — 2 public + 2 private subnets, NAT (single in dev, one
  per AZ in prod), and VPC flow logs to CloudWatch.
- **EKS** — Kubernetes `1.34`, private-only API endpoint, managed node group
  (dev `t3.small`, prod `t3.medium`), IRSA, KMS secret encryption, and an
  SSM-managed bastion (no public SSH) for reaching the private API.
- **RDS for MySQL** `8.4.11` — private subnets, KMS-encrypted, 3306 ingress only
  from the EKS node security group; dev `db.t3.micro` single-AZ (Free Tier),
  prod `db.t3.medium` Multi-AZ with deletion protection.
- **ECR** — one repository per service (`shopverse-frontend`,
  `shopverse-backend`), scan-on-push, lifecycle policy, KMS at rest (default:
  AWS-managed `aws/ecr` key).

## Repository layout

```
.
├── bootstrap/            # one-time: state bucket + GitHub OIDC + deploy roles
├── modules/              # reusable modules (hand-written, raw aws_* resources)
│   ├── tagging/          # standard tag map + name-prefix helper
│   ├── vpc/              # network foundation + flow logs
│   ├── eks/              # cluster, node group, IRSA, SSM bastion
│   ├── database/         # RDS for MySQL
│   └── ecr/              # container registries
├── environments/
│   ├── dev/              # dev root module (key: dev/terraform.tfstate)
│   └── prod/             # prod root module (key: prod/terraform.tfstate)
├── .github/workflows/
│   ├── ci-pull-request.yml   # fmt + validate + dev plan + PR summary (no apply)
│   └── cd-deploy.yml         # dev auto-apply (serialized) + gated prod apply
└── .terraform.lock.hcl   # single shared lock (dev & prod resolve identically)
```

## Deploy flow

1. **Bootstrap (once, by an admin).** Create the state bucket, the GitHub OIDC
   provider, and the two deployment roles. See
   [`bootstrap/README.md`](bootstrap/README.md) for the exact commands and the
   GitHub repository configuration (variables, secret, environments).
2. **Point the backends at the state bucket.** In `environments/dev/backend.tf`
   and `environments/prod/backend.tf`, replace
   `REPLACE_WITH_BOOTSTRAP_STATE_BUCKET` with the bucket name (or pass it via
   `-backend-config="bucket=..."`).
3. **Open a pull request.** CI runs `fmt -check`, `validate`, and a dev `plan`,
   then posts a single add/change/destroy summary comment. No apply runs on PRs.
4. **Merge to `main`.** CD auto-applies to `dev` (serialized), then plans `prod`
   and pauses on the `prod` GitHub Environment approval gate; on approval it
   applies the exact saved prod plan.

## GitHub repository configuration

The workflows read these (set them from the bootstrap outputs — details in
[`bootstrap/README.md`](bootstrap/README.md)):

- **Variables:** `AWS_REGION`, `TF_STATE_BUCKET`, `DEV_DEPLOY_ROLE_ARN`, `PROD_DEPLOY_ROLE_ARN`
- **Secret:** `DB_PASSWORD`
- **Environments:** `dev` (auto), `prod` (required reviewers, branch-restricted to
  `main`, 72-hour timeout)

## Local checks

```bash
terraform fmt -check -recursive

# validate a root module (no AWS credentials needed)
terraform -chdir=environments/dev  init -backend=false -lockfile=readonly && \
terraform -chdir=environments/dev  validate
```

Authentication to AWS is keyless via GitHub OIDC — there are no long-lived AWS
access keys anywhere in this repository.
