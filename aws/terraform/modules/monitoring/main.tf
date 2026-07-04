# Monitoring Module
# Creates CloudWatch Log Groups, alarms, and SNS topics for monitoring

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

# SNS Topic for Alarms
resource "aws_kms_key" "sns" {
  count = var.sns_kms_key_id == null ? 1 : 0

  description             = "KMS key for ${var.environment} monitoring SNS alarms"
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
        Sid    = "AllowSNSUse"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:ReEncrypt*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "sns" {
  count = var.sns_kms_key_id == null ? 1 : 0

  name          = "alias/${var.environment}-monitoring-sns"
  target_key_id = aws_kms_key.sns[0].key_id
}

locals {
  sns_kms_key_id = var.sns_kms_key_id != null ? var.sns_kms_key_id : aws_kms_key.sns[0].arn
}

resource "aws_kms_key" "logs" {
  description             = "KMS key for ${var.environment} CloudWatch log groups"
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
        Sid    = "AllowCloudWatchLogsUse"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
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
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.environment}-cloudwatch-logs-kms"
  })
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.environment}-cloudwatch-logs"
  target_key_id = aws_kms_key.logs.key_id
}

resource "aws_sns_topic" "alarms" {
  name_prefix       = "${var.environment}-alarms-"
  kms_master_key_id = local.sns_kms_key_id

  tags = var.tags
}

resource "aws_sns_topic_subscription" "alarms_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = var.sns_protocol
  endpoint  = var.alert_email
}

# CloudWatch Log Groups - Dynamic creation
resource "aws_cloudwatch_log_group" "log_groups" {
  for_each          = toset(var.log_group_names)
  name              = each.value
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = var.tags
}

# CloudWatch Dashboards
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.environment}-overview"

  dashboard_body = jsonencode({
    widgets = [
      for widget in var.dashboard_widgets : {
        type       = widget.type
        properties = widget.properties
      }
    ]
  })
}

# CloudWatch Alarms - Dynamic creation
resource "aws_cloudwatch_metric_alarm" "metric_alarms" {
  for_each            = { for alarm in var.metric_alarms : alarm.name => alarm }
  alarm_name          = "${var.environment}-${each.value.name}"
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = each.value.period
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  alarm_description   = each.value.description
  alarm_actions       = [aws_sns_topic.alarms.arn]
  treat_missing_data  = var.treat_missing_data

  tags = var.tags
}

# CloudWatch Log Metric Filters - Dynamic creation
resource "aws_cloudwatch_log_metric_filter" "log_filters" {
  for_each       = { for filter in var.log_metric_filters : filter.name => filter }
  name           = "${var.environment}-${each.value.name}"
  log_group_name = aws_cloudwatch_log_group.log_groups[each.value.log_group].name
  pattern        = each.value.filter_pattern

  metric_transformation {
    name      = each.value.metric_name
    namespace = each.value.namespace
    value     = each.value.value
  }
}
