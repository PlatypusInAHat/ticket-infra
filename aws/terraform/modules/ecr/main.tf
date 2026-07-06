# ECR Module
# Creates AWS Elastic Container Registry for storing container images

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

resource "aws_kms_key" "ecr" {
  count = var.kms_key_arn == "" ? 1 : 0

  description             = "KMS key for ${var.environment} ECR repositories"
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
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.environment}-ecr-kms"
  })
}

resource "aws_kms_alias" "ecr" {
  count = var.kms_key_arn == "" ? 1 : 0

  name          = "alias/${var.environment}-ecr"
  target_key_id = aws_kms_key.ecr[0].key_id
}

locals {
  ecr_kms_key_arn = var.kms_key_arn != "" ? var.kms_key_arn : aws_kms_key.ecr[0].arn
}

# ECR Repositories - Dynamic creation using for_each
resource "aws_ecr_repository" "repositories" {
  for_each             = toset(var.repository_names)
  name                 = "${var.environment}/${each.value}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.enable_image_scanning
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = local.ecr_kms_key_arn
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-${each.value}-repo"
  })
}

# ECR Lifecycle Policies - Dynamic creation with dynamic rules
resource "aws_ecr_lifecycle_policy" "policies" {
  for_each   = toset(var.repository_names)
  repository = aws_ecr_repository.repositories[each.value].name

  policy = jsonencode({
    rules = [
      for idx, rule in var.lifecycle_rules : {
        rulePriority = idx + 1
        description  = rule.description
        selection = merge(
          {
            tagStatus = rule.tag_status
            countType = rule.count_type
          },
          rule.tag_prefixes != null ? { tagPrefixList = rule.tag_prefixes } : {},
          rule.count_unit != null ? { countUnit = rule.count_unit } : {},
          {
            countNumber = rule.count_number
          }
        )
        action = {
          type = rule.action_type
        }
      }
    ]
  })
}

# ECR Repository Policies - Allow EKS to pull images
resource "aws_ecr_repository_policy" "policies" {
  for_each   = toset(var.repository_names)
  repository = aws_ecr_repository.repositories[each.value].name

  policy = jsonencode({
    Version = var.iam_policy_version
    Statement = [
      {
        Sid    = var.policy_statement_sid
        Effect = "Allow"
        Principal = {
          AWS = var.eks_node_role_arn
        }
        Action = var.ecr_pull_actions
      }
    ]
  })
}
