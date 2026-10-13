output "vpc_id" {
  description = "Prod VPC id."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Prod private subnet ids."
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Prod public subnet ids."
  value       = module.vpc.public_subnet_ids
}

output "eks_cluster_name" {
  description = "Prod EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Prod EKS private API endpoint."
  value       = module.eks.cluster_endpoint
}

output "eks_oidc_issuer_url" {
  description = "Prod EKS OIDC issuer URL (IRSA)."
  value       = module.eks.cluster_oidc_issuer_url
}

output "bastion_instance_id" {
  description = "Prod SSM bastion instance id."
  value       = module.eks.bastion_instance_id
}

output "ecr_repository_urls" {
  description = "Map of logical repo name to ECR repository URL."
  value       = module.ecr.repository_urls
}

output "db_endpoint" {
  description = "Prod RDS endpoint (host:port)."
  value       = module.database.db_endpoint
  sensitive   = true
}

output "db_secret_arn" {
  description = "Prod RDS master credential Secrets Manager ARN."
  value       = module.database.db_secret_arn
  sensitive   = true
}
