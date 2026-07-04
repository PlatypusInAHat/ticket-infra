# Amazon MQ Module
# Creates Amazon MQ for RabbitMQ messaging service

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

# Security Group for MQ
locals {
  mq_egress_rules = length(var.mq_egress_rules) > 0 ? var.mq_egress_rules : [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [var.vpc_cidr]
      description = "Allow outbound traffic within the VPC only"
    }
  ]
}

resource "aws_kms_key" "mq" {
  count = var.kms_key_arn == "" ? 1 : 0

  description             = "KMS key for ${var.environment} Amazon MQ and logs"
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
        Sid    = "AllowAmazonMQUse"
        Effect = "Allow"
        Principal = {
          Service = "mq.amazonaws.com"
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
    Name = "${var.environment}-amazon-mq-kms"
  })
}

resource "aws_kms_alias" "mq" {
  count = var.kms_key_arn == "" ? 1 : 0

  name          = "alias/${var.environment}-amazon-mq"
  target_key_id = aws_kms_key.mq[0].key_id
}

locals {
  mq_kms_key_id = var.kms_key_arn != "" ? var.kms_key_arn : aws_kms_key.mq[0].arn
}

resource "aws_security_group" "mq" {
  name_prefix = var.sg_name_prefix
  description = var.sg_description
  vpc_id      = var.vpc_id

  # Dynamic ingress rules
  dynamic "ingress" {
    for_each = var.mq_ingress_rules
    content {
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      security_groups = lookup(ingress.value, "security_groups", null)
      cidr_blocks     = lookup(ingress.value, "cidr_blocks", null)
      description     = ingress.value.description
    }
  }

  # Dynamic egress rules
  dynamic "egress" {
    for_each = local.mq_egress_rules
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
      description = lookup(egress.value, "description", null)
    }
  }

  tags = var.tags
}

# RabbitMQ Broker
resource "aws_mq_broker" "rabbitmq" {
  broker_name                = "${var.environment}-${var.engine_type_lower}"
  engine_type                = var.engine_type
  engine_version             = var.rabbitmq_version
  host_instance_type         = var.instance_type
  publicly_accessible        = var.publicly_accessible
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # User configuration
  user {
    username = var.admin_username
    password = var.admin_password
  }

  # Network configuration
  subnet_ids      = var.subnet_ids
  security_groups = [aws_security_group.mq.id]
  deployment_mode = var.deployment_mode

  encryption_options {
    kms_key_id        = local.mq_kms_key_id
    use_aws_owned_key = false
  }

  # High availability (if multi-AZ deployment)
  dynamic "logs" {
    for_each = var.enable_cloudwatch_logs ? [1] : []
    content {
      general = true
      audit   = false
    }
  }

  tags = var.tags

  depends_on = [aws_security_group.mq]
}

# CloudWatch Log Group for MQ (optional)
resource "aws_cloudwatch_log_group" "mq" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "${var.log_group_prefix}/${var.environment}"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.mq_kms_key_id

  tags = var.tags
}

# CloudWatch Alarm for queue depth
resource "aws_cloudwatch_metric_alarm" "queue_depth" {
  alarm_name          = "${var.environment}-${var.alarm_name_suffix}"
  comparison_operator = var.alarm_comparison_operator
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = var.alarm_metric_name
  namespace           = var.alarm_namespace
  period              = var.alarm_period
  statistic           = var.alarm_statistic
  threshold           = var.queue_depth_threshold
  alarm_description   = var.alarm_description
  treat_missing_data  = var.alarm_treat_missing_data

  dimensions = {
    Broker = aws_mq_broker.rabbitmq.id
  }

  tags = var.tags
}

# Broker Configuration (for custom RabbitMQ settings)
resource "aws_mq_configuration" "rabbitmq" {
  name           = "${var.environment}-${var.engine_type_lower}-config"
  description    = var.broker_config_description
  engine_type    = var.engine_type
  engine_version = var.rabbitmq_version

  data = base64encode(templatefile("${path.module}/rabbitmq.conf", {
    max_connections = var.max_connections
    channel_max     = var.channel_max
  }))

  tags = var.tags
}
