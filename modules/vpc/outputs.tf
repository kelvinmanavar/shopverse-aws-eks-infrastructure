output "vpc_id" {
  description = "The VPC id."
  value       = aws_vpc.vpc.id
}

output "public_subnet_ids" {
  description = "List of public subnet ids (load balancers, bastion, NAT gateways)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet ids (EKS nodes, RDS)."
  value       = aws_subnet.private[*].id
}

output "vpc_cidr" {
  description = "The VPC CIDR block, echoed for downstream security-group rules."
  value       = aws_vpc.vpc.cidr_block
}
