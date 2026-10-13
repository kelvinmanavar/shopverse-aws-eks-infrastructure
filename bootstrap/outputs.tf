output "state_bucket_name" {
  description = "Name of the S3 remote-state bucket. Set this as the `bucket` in each environment's backend.tf."
  value       = aws_s3_bucket.state.bucket
}

output "state_bucket_arn" {
  description = "ARN of the S3 remote-state bucket."
  value       = aws_s3_bucket.state.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC identity provider."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "dev_deploy_role_arn" {
  description = "ARN of the dev deployment role. Use as role-to-assume in the dev CI/CD jobs."
  value       = aws_iam_role.dev_deploy.arn
}

output "prod_deploy_role_arn" {
  description = "ARN of the prod deployment role. Use as role-to-assume in the prod CD job (default branch only)."
  value       = aws_iam_role.prod_deploy.arn
}
