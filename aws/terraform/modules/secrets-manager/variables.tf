variable "environment" {
  description = "Environment name"
  type        = string
}

variable "recovery_window_days" {
  description = "Number of days for recovery window"
  type        = number
  default     = 7
}

variable "secret_rotation_days" {
  description = "Number of days for automatic secret rotation"
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "CloudWatch log retention days"
  type        = number
  default     = 365
}

variable "kms_key_arn" {
  description = "Optional existing KMS key ARN for Secrets Manager and audit log encryption. A customer managed key is created when empty."
  type        = string
  default     = ""
}

variable "kms_deletion_window_in_days" {
  description = "Deletion window for the generated Secrets Manager KMS key"
  type        = number
  default     = 7
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
  description = "MongoDB database name"
  type        = string
}

variable "jwt_secret" {
  description = "JWT secret key"
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
  description = "RabbitMQ connection URL"
  type        = string
  sensitive   = true
}

variable "payment_provider" {
  description = "Payment provider name (e.g., vnpay, momo)"
  type        = string
  default     = ""
}

variable "payment_credentials" {
  description = "Payment provider credentials"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "email_provider" {
  description = "Email provider name (e.g., sendgrid, mailgun)"
  type        = string
  default     = ""
}

variable "email_credentials" {
  description = "Email provider credentials"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "eks_service_account_role_arn" {
  description = "ARN of EKS service account role for IRSA"
  type        = string
}

variable "tags" {
  description = "Common tags for resources"
  type        = map(string)
  default     = {}
}

# IAM Policy Configuration
variable "iam_policy_version" {
  description = "IAM policy version"
  type        = string
  default     = "2012-10-17"
}

variable "policy_statement_sid" {
  description = "SID for secret policy statement"
  type        = string
  default     = "AllowEKSServiceAccountAccess"
}

variable "secrets_policy_actions" {
  description = "Actions allowed in secrets policy"
  type        = list(string)
  default = [
    "secretsmanager:GetSecretValue",
    "secretsmanager:DescribeSecret"
  ]
}

variable "secrets_policy_resource" {
  description = "Resource for secrets policy"
  type        = string
  default     = "*"
}

# Log Group
variable "log_group_prefix" {
  description = "CloudWatch log group name prefix"
  type        = string
  default     = "/aws/secretsmanager"
}
