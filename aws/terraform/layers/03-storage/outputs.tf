output "ecr_backend_repository_urls" {
  description = "ECR repository URLs for backend microservices"
  value = {
    api_gateway          = module.ecr.repository_urls["api-gateway"]
    auth_service         = module.ecr.repository_urls["auth-service"]
    catalog_service      = module.ecr.repository_urls["catalog-service"]
    booking_service      = module.ecr.repository_urls["booking-service"]
    checkin_service      = module.ecr.repository_urls["checkin-service"]
    notification_service = module.ecr.repository_urls["notification-service"]
  }
}

output "ecr_frontend_repository_url" {
  description = "ECR frontend repository URL"
  value       = module.ecr.repository_urls["frontend"]
}

output "s3_bucket_id" {
  description = "S3 bucket ID"
  value       = module.s3_cloudfront.s3_bucket_id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.s3_cloudfront.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name"
  value       = module.s3_cloudfront.cloudfront_domain_name
}

output "secrets_arns" {
  description = "Secrets Manager ARNs"
  value       = module.secrets_manager.secrets_arns
}
