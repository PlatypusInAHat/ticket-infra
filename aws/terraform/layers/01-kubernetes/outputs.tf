output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "cluster_autoscaler_iam_role_arn" {
  description = "Cluster autoscaler IAM role ARN"
  value       = module.eks.cluster_autoscaler_iam_role_arn
}

output "cluster_autoscaler_iam_role_name" {
  description = "Cluster autoscaler IAM role name"
  value       = module.eks.cluster_autoscaler_iam_role_name
}

output "node_role_arn" {
  description = "Node IAM role ARN"
  value       = module.eks.node_role_arn
}

output "cluster_oidc_issuer_url" {
  description = "Cluster OIDC issuer URL"
  value       = module.eks.cluster_oidc_issuer_url
}
