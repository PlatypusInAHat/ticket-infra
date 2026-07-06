# Secrets Manager Module
# Creates AWS Secrets Manager secrets for database and application configuration

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

resource "aws_kms_key" "secrets" {
  count = var.kms_key_arn == "" ? 1 : 0

  description             = "KMS key for ${var.environment} application secrets"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = var.iam_policy_version
    Statement = [
      {
        Sid    = "EnableAccountRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowSecretsManagerUse"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogsUse"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${var.log_group_prefix}/${var.environment}*"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.environment}-secrets-kms"
  })
}

resource "aws_kms_alias" "secrets" {
  count = var.kms_key_arn == "" ? 1 : 0

  name          = "alias/${var.environment}-application-secrets"
  target_key_id = aws_kms_key.secrets[0].key_id
}

locals {
  secrets_kms_key_id = var.kms_key_arn != "" ? var.kms_key_arn : aws_kms_key.secrets[0].arn
}

# MongoDB Connection String Secret
resource "aws_secretsmanager_secret" "mongodb_connection_string" {
  name_prefix             = "${var.environment}/mongodb/connection-string-"
  description             = "MongoDB connection string for ${var.environment}"
  recovery_window_in_days = var.recovery_window_days
  kms_key_id              = local.secrets_kms_key_id

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "mongodb_connection_string" {
  secret_id = aws_secretsmanager_secret.mongodb_connection_string.id
  secret_string = jsonencode({
    connection_string = var.mongodb_connection_string
    username          = var.mongodb_username
    database          = var.mongodb_database
  })
}

# JWT Secret
resource "aws_secretsmanager_secret" "jwt_secret" {
  name_prefix             = "${var.environment}/jwt/secret-"
  description             = "JWT secret key for ${var.environment}"
  recovery_window_in_days = var.recovery_window_days
  kms_key_id              = local.secrets_kms_key_id

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id = aws_secretsmanager_secret.jwt_secret.id
  secret_string = jsonencode({
    secret = var.jwt_secret
  })
}

# RabbitMQ Credentials
resource "aws_secretsmanager_secret" "rabbitmq_credentials" {
  name_prefix             = "${var.environment}/rabbitmq/credentials-"
  description             = "RabbitMQ credentials for ${var.environment}"
  recovery_window_in_days = var.recovery_window_days
  kms_key_id              = local.secrets_kms_key_id

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "rabbitmq_credentials" {
  secret_id = aws_secretsmanager_secret.rabbitmq_credentials.id
  secret_string = jsonencode({
    username = var.rabbitmq_username
    password = var.rabbitmq_password
    url      = var.rabbitmq_url
  })
}

# Payment Service Credentials
resource "aws_secretsmanager_secret" "payment_credentials" {
  count                   = var.payment_provider != "" ? 1 : 0
  name_prefix             = "${var.environment}/payment/${var.payment_provider}-"
  description             = "${var.payment_provider} payment credentials for ${var.environment}"
  recovery_window_in_days = var.recovery_window_days
  kms_key_id              = local.secrets_kms_key_id

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "payment_credentials" {
  count         = var.payment_provider != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.payment_credentials[0].id
  secret_string = jsonencode(var.payment_credentials)
}

# Email Service Credentials
resource "aws_secretsmanager_secret" "email_credentials" {
  count                   = var.email_provider != "" ? 1 : 0
  name_prefix             = "${var.environment}/email/${var.email_provider}-"
  description             = "${var.email_provider} email credentials for ${var.environment}"
  recovery_window_in_days = var.recovery_window_days
  kms_key_id              = local.secrets_kms_key_id

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "email_credentials" {
  count         = var.email_provider != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.email_credentials[0].id
  secret_string = jsonencode(var.email_credentials)
}

# CloudWatch Log Group for Secrets Manager audit
resource "aws_cloudwatch_log_group" "secrets_manager" {
  name              = "${var.log_group_prefix}/${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.secrets_kms_key_id

  tags = var.tags
}

# Resource Policy for Secrets Manager - Dynamic for_each
locals {
  secrets_needing_policy = {
    mongodb_connection_string = aws_secretsmanager_secret.mongodb_connection_string.id
    jwt_secret                = aws_secretsmanager_secret.jwt_secret.id
  }
}

resource "aws_secretsmanager_secret_policy" "policies" {
  for_each   = local.secrets_needing_policy
  secret_arn = each.value

  policy = jsonencode({
    Version = var.iam_policy_version
    Statement = [
      {
        Sid    = var.policy_statement_sid
        Effect = "Allow"
        Principal = {
          AWS = var.eks_service_account_role_arn
        }
        Action   = var.secrets_policy_actions
        Resource = var.secrets_policy_resource
      }
    ]
  })
}
