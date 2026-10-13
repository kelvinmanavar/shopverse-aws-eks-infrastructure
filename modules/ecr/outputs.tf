output "repository_urls" {
  description = "Map of logical repository name to repository URL (for docker push / image references)."
  value       = { for name, repo in aws_ecr_repository.repository : name => repo.repository_url }
}

output "repository_arns" {
  description = "Map of logical repository name to repository ARN."
  value       = { for name, repo in aws_ecr_repository.repository : name => repo.arn }
}

output "kms_key_arn" {
  description = "Customer-managed KMS key ARN encrypting the repositories (module-created or caller-supplied). Null when encryption_type = 'AES256' or when KMS uses the AWS-managed 'aws/ecr' key."
  value       = local.resolved_kms_key_arn
}
