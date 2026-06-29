output "repository_urls" {
  description = "Map of ECR repository URLs"
  value       = { for k, v in aws_ecr_repository.repositories : k => v.repository_url }
}

output "repository_names" {
  description = "Map of ECR repository names"
  value       = { for k, v in aws_ecr_repository.repositories : k => v.name }
}

output "registry_id" {
  description = "ECR registry ID (AWS account ID)"
  value       = one(aws_ecr_repository.repositories[*].registry_id)
}
