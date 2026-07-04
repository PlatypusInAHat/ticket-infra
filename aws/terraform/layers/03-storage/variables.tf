variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "TicketBooking"
}

variable "terraform_state_bucket" {
  description = "S3 bucket that stores Terraform remote state."
  type        = string
}

variable "terraform_state_region" {
  description = "AWS region of the Terraform remote state S3 bucket."
  type        = string
  default     = "us-east-1"
}

# ECR
variable "enable_image_scanning" {
  description = "Enable image scanning"
  type        = bool
  default     = true
}

# CloudFront
variable "cloudfront_allowed_origins" {
  description = "Allowed CORS origins"
  type        = list(string)
  default     = ["*"]
}

variable "cloudfront_cache_min_ttl" {
  description = "CloudFront min TTL"
  type        = number
  default     = 0
}

variable "cloudfront_cache_default_ttl" {
  description = "CloudFront default TTL"
  type        = number
  default     = 86400
}

variable "cloudfront_cache_max_ttl" {
  description = "CloudFront max TTL"
  type        = number
  default     = 31536000
}

variable "enable_api_cache_behavior" {
  description = "Enable API cache behavior"
  type        = bool
  default     = false
}

variable "custom_domain" {
  description = "Custom domain"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN"
  type        = string
  default     = ""
}

variable "invalidate_on_apply" {
  description = "Invalidate cache on apply"
  type        = bool
  default     = false
}

# Secrets Manager
variable "recovery_window_days" {
  description = "Recovery window days"
  type        = number
  default     = 7
}

variable "secret_rotation_days" {
  description = "Secret rotation days"
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "Log retention days"
  type        = number
  default     = 365
}

variable "mongodb_connection_string" {
  description = "MongoDB connection string"
  type        = string
  sensitive   = true
}

variable "mongodb_username" {
  description = "MongoDB username"
  type        = string
  sensitive   = true
}

variable "mongodb_database" {
  description = "MongoDB database"
  type        = string
}

variable "jwt_secret" {
  description = "JWT secret"
  type        = string
  sensitive   = true
}

variable "rabbitmq_username" {
  description = "RabbitMQ username"
  type        = string
  sensitive   = true
}

variable "rabbitmq_password" {
  description = "RabbitMQ password"
  type        = string
  sensitive   = true
}

variable "rabbitmq_url" {
  description = "RabbitMQ URL"
  type        = string
  sensitive   = true
}

variable "payment_provider" {
  description = "Payment provider"
  type        = string
  default     = ""
}

variable "payment_credentials" {
  description = "Payment credentials"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "email_provider" {
  description = "Email provider"
  type        = string
  default     = ""
}

variable "email_credentials" {
  description = "Email credentials"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "eks_service_account_role_arn" {
  description = "EKS service account role ARN"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
