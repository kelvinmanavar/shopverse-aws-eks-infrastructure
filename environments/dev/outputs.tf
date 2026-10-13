output "vpc_id" {
  description = "Dev VPC id."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Dev private subnet ids."
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Dev public subnet ids."
  value       = module.vpc.public_subnet_ids
}

output "eks_cluster_name" {
  description = "Dev EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Dev EKS private API endpoint."
  value       = module.eks.cluster_endpoint
}

output "eks_oidc_issuer_url" {
  description = "Dev EKS OIDC issuer URL (IRSA)."
  value       = module.eks.cluster_oidc_issuer_url
}

output "bastion_instance_id" {
  description = "Dev SSM bastion instance id."
  value       = module.eks.bastion_instance_id
}

output "ecr_repository_urls" {
  description = "Map of logical repo name to ECR repository URL."
  value       = module.ecr.repository_urls
}

output "db_endpoint" {
  description = "Dev RDS endpoint (host:port)."
  value       = module.database.db_endpoint
  sensitive   = true
}

output "db_secret_arn" {
  description = "Dev RDS master credential Secrets Manager ARN."
  value       = module.database.db_secret_arn
  sensitive   = true
}
