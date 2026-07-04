output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.vpc.eks_cluster_security_group_id
}

output "eks_nodes_security_group_id" {
  description = "EKS nodes security group ID"
  value       = module.vpc.eks_nodes_security_group_id
}

output "nat_gateway_ips" {
  description = "NAT gateway public IPs"
  value       = module.vpc.nat_gateway_ips
}
