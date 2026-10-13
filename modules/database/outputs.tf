output "db_endpoint" {
  description = "RDS connection endpoint (host:port)."
  value       = aws_db_instance.mysql.endpoint
  sensitive   = true
}

output "db_security_group_id" {
  description = "The RDS security group id."
  value       = aws_security_group.db.id
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding the RDS-managed master credential. Null when manage_master_user_password is false (password supplied via TF_VAR_db_password)."
  value       = var.manage_master_user_password ? aws_db_instance.mysql.master_user_secret[0].secret_arn : null
  sensitive   = true
}
