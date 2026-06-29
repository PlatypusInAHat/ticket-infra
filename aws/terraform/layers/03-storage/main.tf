# Layer 3: Storage and Secrets
# This layer sets up storage and secrets services:
# - ECR for container image storage
# - S3 and CloudFront for frontend hosting
# - Secrets Manager for sensitive configuration

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source for kubernetes layer outputs
data "terraform_remote_state" "kubernetes" {
  backend = "local"

  config = {
    path = "${path.module}/../01-kubernetes/terraform.tfstate"
  }
}

module "ecr" {
  source = "../../modules/ecr"

  environment           = var.environment
  enable_image_scanning = var.enable_image_scanning
  eks_node_role_arn     = data.terraform_remote_state.kubernetes.outputs.node_role_arn

  tags = local.common_tags
}

module "s3_cloudfront" {
  source = "../../modules/s3-cloudfront"

  environment               = var.environment
  allowed_origins           = var.cloudfront_allowed_origins
  cache_min_ttl             = var.cloudfront_cache_min_ttl
  cache_default_ttl         = var.cloudfront_cache_default_ttl
  cache_max_ttl             = var.cloudfront_cache_max_ttl
  enable_api_cache_behavior = var.enable_api_cache_behavior
  custom_domain             = var.custom_domain
  acm_certificate_arn       = var.acm_certificate_arn
  invalidate_on_apply       = var.invalidate_on_apply

  tags = local.common_tags
}

module "secrets_manager" {
  source = "../../modules/secrets-manager"

  environment          = var.environment
  recovery_window_days = var.recovery_window_days
  secret_rotation_days = var.secret_rotation_days
  log_retention_days   = var.log_retention_days

  mongodb_connection_string = var.mongodb_connection_string
  mongodb_username          = var.mongodb_username
  mongodb_database          = var.mongodb_database
  jwt_secret                = var.jwt_secret
  rabbitmq_username         = var.rabbitmq_username
  rabbitmq_password         = var.rabbitmq_password
  rabbitmq_url              = var.rabbitmq_url
  payment_provider          = var.payment_provider
  payment_credentials       = var.payment_credentials
  email_provider            = var.email_provider
  email_credentials         = var.email_credentials

  eks_service_account_role_arn = var.eks_service_account_role_arn

  tags = local.common_tags
}

locals {
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Layer       = "Storage"
    }
  )
}
