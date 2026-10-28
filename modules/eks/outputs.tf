output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.cluster.name
}

output "cluster_endpoint" {
  description = "Private API endpoint for the EKS cluster."
  value       = aws_eks_cluster.cluster.endpoint
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA (IAM Roles for Service Accounts)."
  value       = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group id (control-plane to data-plane comms)."
  value       = aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
}

output "node_security_group_id" {
  description = "Worker node security group id — consumed by modules/database for its 3306 ingress rule."
  value       = aws_security_group.node.id
}

output "node_role_name" {
  description = "Node IAM role name — consumed by modules/ecr to grant image-pull access."
  value       = aws_iam_role.node.name
}

output "bastion_instance_id" {
  description = "Bastion EC2 instance id — use with SSM Session Manager to reach the private cluster API."
  value       = aws_instance.bastion.id
}

output "kms_key_arn" {
  description = "KMS key ARN encrypting Kubernetes secrets."
  value       = aws_kms_key.eks.arn
}

output "ebs_csi_role_arn" {
  description = "IRSA role ARN bound to the EBS CSI driver service account. Null when enable_ebs_csi is false."
  value       = local.ebs_csi_enabled ? aws_iam_role.ebs_csi[0].arn : null
}

output "lb_controller_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller service account. Annotate the controller's Helm service account with this ARN. Null when enable_lb_controller is false."
  value       = local.lb_controller_enabled ? aws_iam_role.lb_controller[0].arn : null
}
